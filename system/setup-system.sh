#!/usr/bin/env bash
# =============================================================================
# Idempotent System Hardening & Configuration Setup for Linux Host
# =============================================================================
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "==> Skipping system setup: Not a Linux host."
  exit 0
fi

echo "==> Applying system configurations (may prompt for sudo)..."

# 1. Logind headless config (ignore lid close and idle sleep)
if [[ -d /etc/systemd/logind.conf.d ]]; then
  sudo cp "$DIR/logind/headless.conf" /etc/systemd/logind.conf.d/headless.conf
  sudo systemctl try-reload-or-restart systemd-logind.service || true
  echo "    ✓ logind headless config applied"
fi

# 2. SSH key-only authentication hardening
if [[ -d /etc/ssh/sshd_config.d ]]; then
  sudo cp "$DIR/ssh/01-key-only.conf" /etc/ssh/sshd_config.d/01-key-only.conf
  if sudo sshd -t; then
    sudo systemctl reload ssh || true
    echo "    ✓ sshd key-only config applied"
  else
    echo "    ✗ sshd config validation failed! Please check manually."
  fi
fi

# 3. Wi-Fi powersave disabling service
if [[ -f /usr/sbin/iw ]] || [[ -f /usr/bin/iw ]]; then
  sudo cp "$DIR/wifi/wifi-powersave-off.service" /etc/systemd/system/
  sudo systemctl daemon-reload
  sudo systemctl enable --now wifi-powersave-off.service || true
  echo "    ✓ wifi-powersave-off service enabled"
fi

# 4. Unattended upgrades configuration
if [[ -d /etc/apt/apt.conf.d ]]; then
  sudo cp "$DIR/apt/20auto-upgrades" /etc/apt/apt.conf.d/20auto-upgrades
  echo "    ✓ unattended upgrades config applied"
fi

# 5. LAN filter firewall service
if command -v iptables >/dev/null 2>&1; then
  sudo cp "$DIR/firewall/aruba-devdeps-lan-filter.sh" /usr/local/sbin/aruba-devdeps-lan-filter
  sudo chmod +x /usr/local/sbin/aruba-devdeps-lan-filter
  sudo cp "$DIR/firewall/aruba-devdeps-lan-filter.service" /etc/systemd/system/
  sudo systemctl daemon-reload
  sudo systemctl enable --now aruba-devdeps-lan-filter.service || true
  echo "    ✓ aruba-devdeps LAN firewall filter enabled"
fi

# 6. Sysctl performance tuning (swappiness & cache pressure for low-power host)
if [[ -d /etc/sysctl.d ]]; then
  sudo cp "$DIR/sysctl/99-devbox.conf" /etc/sysctl.d/99-devbox.conf
  sudo sysctl -p /etc/sysctl.d/99-devbox.conf || true
  echo "    ✓ sysctl low-swappiness & cache tuning applied"
fi

# 7. Restrict network-online waiting to the active Wi-Fi interface.
if [[ -f "$DIR/systemd/systemd-networkd-wait-online.service.d/override.conf" ]]; then
  sudo mkdir -p /etc/systemd/system/systemd-networkd-wait-online.service.d
  sudo cp "$DIR/systemd/systemd-networkd-wait-online.service.d/override.conf" /etc/systemd/system/systemd-networkd-wait-online.service.d/
  sudo systemctl daemon-reload
  echo "    ✓ network-online wait restricted to wlp3s0"
fi

# 8. Enable zswap compressed swap cache service
sudo cp "$DIR/zswap/zswap-enable.service" /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now zswap-enable.service || true
echo "    ✓ zswap compressed swap service enabled"

echo "==> System setup complete."
