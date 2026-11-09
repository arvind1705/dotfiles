#!/usr/bin/env bash
# =============================================================================
# Setup & Bootstrap Docker Compose Stacks on Host
# =============================================================================
set -euo pipefail

STACKS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

detect_ip() {
  ip -4 route get 1.1.1.1 2>/dev/null \
    | awk '{for (i=1; i<=NF; i++) if ($i=="src") {print $(i+1); exit}}'
}
detect_tz() {
  cat /etc/timezone 2>/dev/null \
    || timedatectl show -p Timezone --value 2>/dev/null \
    || echo "Etc/UTC"
}

LAN_IP="${LAN_IP:-$(detect_ip)}"; LAN_IP="${LAN_IP:-127.0.0.1}"
TZONE="$(detect_tz)"
USER_ID="$(id -u)"
GROUP_ID="$(id -g)"
RENDER_GID="$(getent group render 2>/dev/null | cut -d: -f3 || echo 991)"
VIDEO_GID="$(getent group video 2>/dev/null | cut -d: -f3 || echo 44)"

echo "==> Configuring Docker Compose Stacks (LAN IP: $LAN_IP)..."

# 1. Create persistent host data directories
echo "==> Ensuring host data directories exist..."
mkdir -p "$HOME/data/9router"
chmod 700 "$HOME/data/9router"

# Media storage dirs
MEDIA_ROOT="${MEDIA_ROOT:-$HOME/data/media}"
mkdir -p \
  "$MEDIA_ROOT/config/jellyfin" \
  "$MEDIA_ROOT/config/qbittorrent" \
  "$MEDIA_ROOT/library/movies" \
  "$MEDIA_ROOT/library/tv" \
  "$MEDIA_ROOT/library/incomplete"

# 2. Initialize devdeps .env
if [[ ! -f "$STACKS_DIR/devdeps/.env" ]]; then
  echo "==> Creating stacks/devdeps/.env from template..."
  sed "s/192.168.0.172/$LAN_IP/g" "$STACKS_DIR/devdeps/.env.example" > "$STACKS_DIR/devdeps/.env"
  chmod 600 "$STACKS_DIR/devdeps/.env"
fi

# 3. Initialize langfuse.env
if [[ ! -f "$STACKS_DIR/langfuse/langfuse.env" ]]; then
  echo "==> Generating stacks/langfuse/langfuse.env with cryptographically secure keys..."
  SECRET_KEY="$(openssl rand -base64 32)"
  SALT_KEY="$(openssl rand -base64 32)"
  ENC_KEY="$(openssl rand -hex 32)"

  sed -e "s/generate_with_openssl_rand_base64_32/$SECRET_KEY/" \
      -e "s/generate_with_openssl_rand_base64_32/$SALT_KEY/" \
      -e "s/generate_64_hex_chars_with_openssl_rand_hex_32/$ENC_KEY/" \
      "$STACKS_DIR/langfuse/langfuse.env.example" > "$STACKS_DIR/langfuse/langfuse.env"
  chmod 600 "$STACKS_DIR/langfuse/langfuse.env"
fi

# 4. Initialize 9router .env
if [[ ! -f "$STACKS_DIR/9router/.env" ]]; then
  echo "==> Creating stacks/9router/.env from template..."
  cp "$STACKS_DIR/9router/.env.example" "$STACKS_DIR/9router/.env"
  chmod 600 "$STACKS_DIR/9router/.env"
fi

# 5. Initialize media-server .env
if [[ ! -f "$STACKS_DIR/media-server/.env" ]]; then
  echo "==> Creating stacks/media-server/.env with detected machine values..."
  cat > "$STACKS_DIR/media-server/.env" <<EOF
MEDIA_ROOT=$MEDIA_ROOT
LAN_IP=$LAN_IP
JELLYFIN_PORT=8096
JELLYFIN_PUBLISHED_URL=http://jellyfin.local
QBT_WEBUI_PORT=8081
QBT_LISTEN_PORT=6881
PUID=$USER_ID
PGID=$GROUP_ID
TZ=$TZONE
RENDER_GID=$RENDER_GID
VIDEO_GID=$VIDEO_GID
MEDIA_USER=aravind
MEDIA_PASSWORD=change_this_password
EOF
  chmod 600 "$STACKS_DIR/media-server/.env"
fi

# 6. Install systemd stack@.service template for auto-boot
if [[ -d /etc/systemd/system ]]; then
  echo "==> Installing systemd stack@.service for boot auto-start..."
  sudo cp "$STACKS_DIR/systemd/stack@.service" /etc/systemd/system/stack@.service
  sudo systemctl daemon-reload

  # Enable all stacks on boot
  for stack in devdeps langfuse 9router media-server; do
    echo "    Enabling boot service: stack@$stack..."
    sudo systemctl enable "stack@$stack"
  done

  # Clean up legacy media-stack.service if present
  if systemctl is-enabled media-stack.service >/dev/null 2>&1; then
    echo "==> Cleaning up superseded legacy media-stack.service..."
    sudo systemctl disable --now media-stack.service || true
    sudo rm -f /etc/systemd/system/media-stack.service
    sudo systemctl daemon-reload
    echo "    ✓ Replaced by stack@media-server"
  fi
fi

echo "==> Stacks bootstrap complete."
