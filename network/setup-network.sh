#!/usr/bin/env bash
# =============================================================================
# Setup Network Ingress: Caddy Reverse Proxy, Portal, and Avahi mDNS
# =============================================================================
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

detect_ipv4() {
  ip -4 route get 1.1.1.1 2>/dev/null \
    | awk '{for (i=1; i<=NF; i++) if ($i=="src") {print $(i+1); exit}}'
}

LAN_IP="${LAN_IP:-$(detect_ipv4)}"
LAN_IP="${LAN_IP:-127.0.0.1}"

echo "==> Setting up network ingress (LAN IP: $LAN_IP)..."

# 1. Portal dashboard
echo "==> Deploying devbox dashboard to /srv/devbox-index"
sudo mkdir -p /srv/devbox-index
sudo cp -r "$DIR/portal/." /srv/devbox-index/

# 2. Caddyfile
echo "==> Deploying /etc/caddy/Caddyfile"
TMP_CADDY="$(mktemp)"
sed "s/__LAN_IP__/$LAN_IP/g" "$DIR/caddy/Caddyfile.template" > "$TMP_CADDY"
sudo cp "$TMP_CADDY" /etc/caddy/Caddyfile
rm -f "$TMP_CADDY"

if command -v caddy >/dev/null 2>&1; then
  sudo caddy validate --config /etc/caddy/Caddyfile
  sudo systemctl reload caddy || sudo systemctl restart caddy
  echo "    ✓ Caddy reverse proxy reloaded"
fi

# 3. Avahi mDNS hosts
"$DIR/mdns/update-mdns.sh"

# 4. Cleanup legacy mdns-*.service units if they exist
LEGACY_SERVICES=$(ls /etc/systemd/system/mdns-*.service 2>/dev/null || true)
if [[ -n "$LEGACY_SERVICES" ]]; then
  echo "==> Disabling legacy individual mdns-*.service units (replaced by /etc/avahi/hosts)..."
  for s in $LEGACY_SERVICES; do
    name="$(basename "$s")"
    sudo systemctl disable --now "$name" 2>/dev/null || true
    sudo rm -f "$s"
  done
  sudo systemctl daemon-reload
  echo "    ✓ Legacy mdns services cleaned up"
fi

# 5. Devbox system metrics daemon
echo "==> Deploying devbox-metrics.service"
sudo cp "$DIR/metrics/devbox-metrics.service" /etc/systemd/system/devbox-metrics.service
sudo systemctl daemon-reload
sudo systemctl enable devbox-metrics.service
sudo systemctl restart devbox-metrics.service
echo "    ✓ devbox-metrics.service active (listening on 127.0.0.1:9108)"

echo "==> Network setup complete."
