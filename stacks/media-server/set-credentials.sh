#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Set / reset the Web UI credentials for Jellyfin and qBittorrent.
# Safe to re-run. Values come from .env (MEDIA_USER / MEDIA_PASSWORD).
#
#   ./set-credentials.sh
#
# Two paths:
#   * Existing install: rewrites the [WebUI] block of qBittorrent.conf and
#     updates the admin row in Jellyfin's jellyfin.db (Jellyfin is stopped
#     while the DB is edited). Libraries and watch history are untouched.
#   * Fresh install: drives Jellyfin's startup wizard via its API and seeds
#     qBittorrent's config, so there's no wizard or temporary password.
#
# Both logins are verified at the end. Hash formats were confirmed against
# Jellyfin 12.4 and qBittorrent 5.3 (PBKDF2-SHA512 in both cases).
# ---------------------------------------------------------------------------
set -euo pipefail
cd "$(dirname "$0")"

if [[ ! -f .env ]]; then
  echo "ERROR: .env missing -- run ./setup.sh first." >&2
  exit 1
fi
set -a; . ./.env; set +a
USER_NAME="${MEDIA_USER:-}"
PASSWORD="${MEDIA_PASSWORD:-}"
if [[ -z "$USER_NAME" || -z "$PASSWORD" ]]; then
  echo "ERROR: MEDIA_USER / MEDIA_PASSWORD are empty in .env." >&2
  exit 1
fi
if (( ${#USER_NAME} < 3 )); then
  echo "ERROR: qBittorrent requires a username of at least 3 characters." >&2
  exit 1
fi

HOST="${LAN_IP:-127.0.0.1}"
JPORT="${JELLYFIN_PORT:-8096}"
QPORT="${QBT_WEBUI_PORT:-8081}"
JAPI="http://${HOST}:${JPORT}"
QAPI="http://${HOST}:${QPORT}"

wait_for() {
  local url="$1" tries="${2:-90}" i
  for ((i=0; i<tries; i++)); do
    curl -fsS --max-time 2 "$url" >/dev/null 2>&1 && return 0
    sleep 1
  done
  echo "ERROR: timed out waiting for $url" >&2
  return 1
}

# Build a JSON object from key/value pairs, escaping values properly.
json_kv() {
  python3 -c 'import json,sys; a=sys.argv[1:]; print(json.dumps(dict(zip(a[0::2],a[1::2]))))' "$@"
}

# POST "$url" with the given curl args; return the HTTP status, retrying while
# a just-restarted container is still refusing connections (curl exit 7 / 000).
post_code() {
  local url="$1"; shift
  local i code
  for ((i=0; i<30; i++)); do
    code=$(curl -s -o /dev/null -w '%{http_code}' "$@" "$url" || true)
    [[ "$code" =~ ^[0-9]{3}$ && "$code" != "000" ]] && { echo "$code"; return 0; }
    sleep 1
  done
  echo "000"
}

echo "==> Applying Web UI credentials for user '${USER_NAME}'"

# --------------------------------------------------------------- qBittorrent
# IMPORTANT: stop qBittorrent BEFORE editing its config. It writes its in-memory
# settings to qBittorrent.conf on shutdown, so `restart` would clobber the edit.
QBT_CONF="config/qbittorrent/qBittorrent/qBittorrent.conf"
mkdir -p "$(dirname "$QBT_CONF")"
docker compose stop qbittorrent >/dev/null
python3 - "$QBT_CONF" "$USER_NAME" "$PASSWORD" "$QPORT" <<'PY'
import base64, hashlib, os, secrets, sys
path, user, pw, port = sys.argv[1:5]
# qBittorrent 5.x: PBKDF2-HMAC-SHA512, 100000 iterations, 64-byte key,
# base64(salt):base64(hash) wrapped in @ByteArray(...).
salt = secrets.token_bytes(16)
digest = hashlib.pbkdf2_hmac("sha512", pw.encode(), salt, 100000, 64)
value = '@ByteArray(%s:%s)' % (base64.b64encode(salt).decode(),
                               base64.b64encode(digest).decode())
lines = open(path).read().splitlines() if os.path.exists(path) else []
out, in_section, inserted, found = [], False, False, False
for line in lines:
    s = line.strip()
    if s.startswith('[') and s.endswith(']'):
        if in_section and not inserted:
            out += ['Username=' + user, 'Password_PBKDF2="%s"' % value]
            inserted = True
        in_section = (s == '[WebUI]')
        found = found or in_section
        out.append(line)
        continue
    if in_section and (line.startswith('Username=') or
                       line.startswith('Password_PBKDF2=') or
                       line.startswith('Password_ha1=')):
        continue
    out.append(line)
if not found:  # brand-new config: give qBittorrent sane WebUI defaults too
    out += ['[WebUI]', 'Address=*', 'Port=' + port, 'ServerDomains=*']
if not inserted:
    out += ['Username=' + user, 'Password_PBKDF2="%s"' % value]
open(path, 'w').write('\n'.join(out) + '\n')
print('    wrote [WebUI] credentials to ' + path)
PY

docker compose start qbittorrent >/dev/null
wait_for "${QAPI}/"
QCODE=$(post_code "${QAPI}/api/v2/auth/login" -X POST \
  -H "Origin: ${QAPI}" \
  --data-urlencode "username=${USER_NAME}" \
  --data-urlencode "password=${PASSWORD}")
if [[ "$QCODE" != "204" ]]; then
  echo "ERROR: qBittorrent login failed (HTTP ${QCODE})." >&2
  exit 1
fi
echo "    qBittorrent login OK"

# ------------------------------------------------------------------ Jellyfin
wait_for "${JAPI}/System/Info/Public"
WIZARD=$(curl -fsS "${JAPI}/System/Info/Public" | python3 -c \
  'import json,sys; print(json.load(sys.stdin)["StartupWizardCompleted"])')

if [[ "$WIZARD" == "False" ]]; then
  echo "    Jellyfin: completing startup wizard via API"
  curl -fsS "${JAPI}/Startup/FirstUser" >/dev/null   # creates the first user
  STARTUP_BODY=$(json_kv Name "$USER_NAME" Password "$PASSWORD")
  curl -fsS -X POST -H 'Content-Type: application/json' -d "$STARTUP_BODY" \
    "${JAPI}/Startup/User" >/dev/null
  curl -fsS -X POST -H 'Content-Type: application/json' \
    -d '{"EnableRemoteAccess":false}' "${JAPI}/Startup/RemoteAccess" >/dev/null
  curl -fsS -X POST "${JAPI}/Startup/Complete" >/dev/null
  echo "    Jellyfin wizard done"
else
  echo "    Jellyfin: updating the existing admin user"
  docker compose stop jellyfin >/dev/null
  python3 - "config/jellyfin/data/jellyfin.db" "$USER_NAME" "$PASSWORD" <<'PY'
import hashlib, secrets, sqlite3, sys
path, user, pw = sys.argv[1:4]
# Jellyfin 12.x: $PBKDF2-SHA512$iterations=210000$<hex salt>$<hex hash>
salt = secrets.token_bytes(16)
digest = hashlib.pbkdf2_hmac("sha512", pw.encode(), salt, 210000, 64)
hashed = '$PBKDF2-SHA512$iterations=210000$%s$%s' % (
    salt.hex().upper(), digest.hex().upper())
con = sqlite3.connect(path)
cur = con.cursor()
rows = list(cur.execute("SELECT Id FROM Users"))
if not rows:
    print("ERROR: no users in jellyfin.db", file=sys.stderr)
    sys.exit(1)
target = rows[0][0]
if len(rows) > 1:  # prefer an administrator if there are several users
    admins = [r[0] for r in cur.execute(
        "SELECT UserId FROM Permissions WHERE Kind=0 AND Value=1")]
    if admins:
        target = admins[0]
cur.execute("UPDATE Users SET Username=?, NormalizedUsername=?, Password=?, "
            "MustUpdatePassword=0 WHERE Id=?",
            (user, user.upper(), hashed, target))
con.commit()
con.close()
print("    admin renamed to " + user + " and password reset")
PY
  docker compose start jellyfin >/dev/null
  wait_for "${JAPI}/System/Info/Public"
  sleep 2   # let Jellyfin finish loading the user table before authenticating
fi

# Jellyfin 12.x wants the device info in the standard Authorization header.
AUTH_HDR='Authorization: MediaBrowser Client="set-credentials", Device="setup", DeviceId="setup", Version="1.0"'
JF_BODY=$(json_kv Username "$USER_NAME" Pw "$PASSWORD")
JCODE=$(post_code "${JAPI}/Users/AuthenticateByName" -X POST \
  -H 'Content-Type: application/json' -H "$AUTH_HDR" -d "$JF_BODY")
if [[ "$JCODE" != "200" ]]; then
  echo "ERROR: Jellyfin login failed (HTTP ${JCODE})." >&2
  exit 1
fi
echo "    Jellyfin login OK"
echo "==> Done. Both Web UIs now use '${USER_NAME}' with the password from .env"
