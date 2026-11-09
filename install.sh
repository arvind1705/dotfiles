#!/usr/bin/env bash
# =============================================================================
# Unified Installer & Provisioner for Dotfiles, System, Network, and Stacks
# =============================================================================
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<EOF
Usage: $0 [options]

Options:
  --all         Run complete installation (dotfiles + system + network + stacks)
  --dotfiles    Install user shell, git, starship, and editor dotfiles
  --system      Apply host OS configs (headless, ssh, wifi, firewall, apt)
  --network     Deploy Caddy reverse proxy, devbox dashboard, and Avahi mDNS
  --stacks      Initialize container configs, data directories, and systemd boot units
  -h, --help    Show this help message

Examples:
  ./install.sh --all
  ./install.sh --dotfiles
  ./install.sh --stacks
EOF
  exit 0
}

install_dotfiles() {
  echo "========================================================================"
  echo " 1. INSTALLING USER DOTFILES"
  echo "========================================================================"

  # Zsh files
  echo "==> Deploying zsh startup files to ~"
  cp "$REPO_DIR/home/zsh/.zshenv" "$HOME/.zshenv"
  cp "$REPO_DIR/home/zsh/.zprofile" "$HOME/.zprofile"
  cp "$REPO_DIR/home/zsh/.zshrc" "$HOME/.zshrc"

  mkdir -p "$HOME/.zsh"
  cp "$REPO_DIR/home/zsh/.zsh/"*.zsh "$HOME/.zsh/"
  if [[ ! -f "$HOME/.zsh/secrets.zsh" ]] && [[ -f "$REPO_DIR/home/zsh/.zsh/secrets.zsh.example" ]]; then
    cp "$REPO_DIR/home/zsh/.zsh/secrets.zsh.example" "$HOME/.zsh/secrets.zsh.example"
  fi

  # Config directories (~/.config)
  echo "==> Deploying ~/.config configurations"
  mkdir -p "$HOME/.config"
  if [[ -d "$REPO_DIR/home/config/opencode" ]]; then
    mkdir -p "$HOME/.config/opencode"
    cp -r "$REPO_DIR/home/config/opencode/"* "$HOME/.config/opencode/"
  fi
  if [[ -d "$REPO_DIR/home/config/ghostty" ]]; then
    mkdir -p "$HOME/.config/ghostty"
    cp -r "$REPO_DIR/home/config/ghostty/"* "$HOME/.config/ghostty/"
  fi
  if [[ -f "$REPO_DIR/home/config/starship.toml" ]]; then
    cp "$REPO_DIR/home/config/starship.toml" "$HOME/.config/starship.toml"
  fi
  if [[ -f "$REPO_DIR/home/config/git/ignore" ]]; then
    mkdir -p "$HOME/.config/git"
    cp "$REPO_DIR/home/config/git/ignore" "$HOME/.config/git/ignore"
  fi

  # Git config
  if [[ -f "$REPO_DIR/home/git/ignore-global" ]]; then
    git config --global core.excludesfile "$HOME/.config/git/ignore" || true
  fi

  # VSCode
  if [[ -d "$HOME/.config/Code/User" ]]; then
    cp "$REPO_DIR/home/vscode/"*.json "$HOME/.config/Code/User/" 2>/dev/null || true
  fi

  echo "    ✓ User dotfiles installed successfully."
}

install_system() {
  echo "========================================================================"
  echo " 2. APPLYING SYSTEM HARDENING & CONFIGURATION"
  echo "========================================================================"
  "$REPO_DIR/system/setup-system.sh"
}

install_network() {
  echo "========================================================================"
  echo " 3. DEPLOYING NETWORK INGRESS & DISCOVERY"
  echo "========================================================================"
  "$REPO_DIR/network/setup-network.sh"
}

install_stacks() {
  echo "========================================================================"
  echo " 4. BOOTSTRAPPING DOCKER COMPOSE STACKS & AUTO-BOOT"
  echo "========================================================================"
  "$REPO_DIR/stacks/setup-stacks.sh"
  echo "==> Starting all services..."
  "$REPO_DIR/stacks/stacks.sh" up
}

# Parse command line arguments
if [[ $# -eq 0 ]]; then
  usage
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --all)
      install_dotfiles
      install_system
      install_network
      install_stacks
      echo ""
      echo "✓ All components installed and started successfully!"
      exit 0
      ;;
    --dotfiles)
      install_dotfiles
      shift
      ;;
    --system)
      install_system
      shift
      ;;
    --network)
      install_network
      shift
      ;;
    --stacks)
      install_stacks
      shift
      ;;
    -h|--help)
      usage
      ;;
    *)
      echo "Unknown option: $1"
      usage
      ;;
  esac
done
