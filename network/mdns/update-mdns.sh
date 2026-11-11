#!/usr/bin/env bash
# =============================================================================
# Update /etc/hosts and mDNS Publishing for Local Domain Resolution
# =============================================================================
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

detect_ipv4() {
  ip -4 route get 1.1.1.1 2>/dev/null \
    | awk '{for (i=1; i<=NF; i++) if ($i=="src") {print $(i+1); exit}}'
}

detect_ipv6() {
  ip -6 addr show dev "${LAN_IFACE:-wlp3s0}" scope link 2>/dev/null \
    | awk '/inet6/ {print $2; exit}' | cut -d/ -f1
}

IPV4="${LAN_IP:-$(detect_ipv4)}"
IPV4="${IPV4:-127.0.0.1}"
IPV6="$(detect_ipv6 || true)"

HOSTNAMES=(
  "devbox.local"
  "jellyfin.local"
  "qbittorrent.local"
  "langfuse.local"
  "9router.local"
  "clickhouse.local"
  "minio.local"
  "minio-console.local"
  "dgraph.local"
  "cube.local"
  "postgres.local"
  "redis.local"
)

echo "==> Configuring local hostnames and mDNS resolution..."
echo "    Primary IPv4: $IPV4"
[[ -n "$IPV6" ]] && echo "    Primary IPv6: $IPV6"

# 1. Update /etc/hosts for local on-box resolution
TMP_HOSTS="$(mktemp)"
# Remove old devbox block if present
sed '/# BEGIN DEVBOX LOCAL HOSTS/,/# END DEVBOX LOCAL HOSTS/d' /etc/hosts > "$TMP_HOSTS"
cat >> "$TMP_HOSTS" <<EOF
# BEGIN DEVBOX LOCAL HOSTS
$IPV4 ${HOSTNAMES[*]}
# END DEVBOX LOCAL HOSTS
EOF
sudo cp "$TMP_HOSTS" /etc/hosts
rm -f "$TMP_HOSTS"
echo "    ✓ /etc/hosts updated for instant local resolution"

# 2. Update /etc/avahi/hosts for Avahi daemon
TMP_AVAHI="$(mktemp)"
cat > "$TMP_AVAHI" <<EOF
# Generated automatically by update-mdns.sh
# Maps local service hostnames to this host's LAN IP addresses.

# IPv4 mappings
EOF
for h in "${HOSTNAMES[@]}"; do
  echo "$IPV4 $h" >> "$TMP_AVAHI"
done
if [[ -n "$IPV6" ]]; then
  echo "" >> "$TMP_AVAHI"
  echo "# IPv6 mappings" >> "$TMP_AVAHI"
  for h in "${HOSTNAMES[@]}"; do
    echo "$IPV6 $h" >> "$TMP_AVAHI"
  done
fi
sudo cp "$TMP_AVAHI" /etc/avahi/hosts
rm -f "$TMP_AVAHI"

if systemctl is-active --quiet avahi-daemon; then
  sudo systemctl reload avahi-daemon || sudo systemctl restart avahi-daemon
  echo "    ✓ avahi-daemon reloaded"
else
  sudo systemctl enable --now avahi-daemon || true
fi

# 3. Install and start/restart unified devbox-mdns.service
sudo cp "$DIR/devbox-mdns.service" /etc/systemd/system/devbox-mdns.service
sudo systemctl daemon-reload
sudo systemctl enable devbox-mdns.service
sudo systemctl restart devbox-mdns.service
echo "    ✓ devbox-mdns.service active (broadcasting to LAN)"
