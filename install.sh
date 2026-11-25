#!/usr/bin/env bash
# =============================================================================
# Dotfiles installer (machine roles, stacks and the portal live in the fleet repo)
# =============================================================================
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN=0
BACKUP_DIR=""

usage() {
  cat <<EOF
Usage: $0 [options]

Options:
  --dotfiles    Install user shell, git, starship, and editor dotfiles
  --dry-run     Preview --dotfiles without writing to your home directory
  -h, --help    Show this help message

Host setup, Docker stacks, DNS and the portal moved to
https://github.com/arvind1705/fleet.

Examples:
  ./install.sh --dotfiles
  ./install.sh --dotfiles --dry-run
EOF
  exit 0
}

sync_file() {
  local source="$REPO_DIR/home/$1" target="$2"
  if [[ ! -f "$source" ]]; then
    printf 'Missing managed source: %s\n' "$source" >&2
    return 1
  fi
  if [[ -L "$target" || ( -e "$target" && ! -f "$target" ) ]]; then
    printf 'Skip non-regular destination: %s\n' "$target"
    return 0
  fi
  if cmp -s "$source" "$target"; then
    return 0
  fi
  if [[ -f "$target" ]]; then
    printf 'Replace (with backup): %s\n' "$target"
    if (( ! DRY_RUN )); then
      if [[ -z "$BACKUP_DIR" ]]; then
        BACKUP_DIR="$(mktemp -d "$HOME/.dotfiles-backup.XXXXXX")"
        printf 'Backups: %s\n' "$BACKUP_DIR"
      fi
      mkdir -p "$BACKUP_DIR/$(dirname "$1")"
      cp -p "$target" "$BACKUP_DIR/$1"
    fi
  else
    printf 'Install: %s\n' "$target"
  fi
  if (( ! DRY_RUN )); then
    mkdir -p "$(dirname "$target")"
    cp "$source" "$target"
  fi
}

install_dotfiles() {
  local entry config_dir="$HOME/.config" vscode_dir
  for entry in \
    .zshenv .zprofile .zshrc \
    .zsh/aliases.zsh .zsh/functions.zsh .zsh/integrations.zsh \
    .zsh/path.zsh .zsh/runtimes.zsh; do
    sync_file "zsh/$entry" "$HOME/$entry"
  done
  if [[ ! -e "$HOME/.zsh/secrets.zsh" && ! -e "$HOME/.zsh/secrets.zsh.example" ]]; then
    sync_file zsh/.zsh/secrets.zsh.example "$HOME/.zsh/secrets.zsh.example"
  fi
  for entry in ghostty/config ghostty/material-ocean.icns git/ignore \
    opencode/cli.json starship.toml; do
    sync_file "config/$entry" "$config_dir/$entry"
  done

  if command -v git >/dev/null && ! git config --global --get core.excludesfile >/dev/null; then
    printf 'Set Git global ignore file: %s\n' "$config_dir/git/ignore"
    if (( ! DRY_RUN )); then
      git config --global core.excludesfile "$config_dir/git/ignore"
    fi
  fi

  if [[ "$(uname -s)" == Darwin ]]; then
    vscode_dir="$HOME/Library/Application Support/Code/User"
    if [[ -d "$config_dir/rex" ]]; then
      sync_file config/rex/init.lua "$config_dir/rex/init.lua"
    fi
  else
    vscode_dir="${XDG_CONFIG_HOME:-$config_dir}/Code/User"
  fi
  if [[ -d "$vscode_dir" ]]; then
    for entry in settings.json keybindings.json; do
      sync_file "vscode/$entry" "$vscode_dir/$entry"
    done
  fi
}

# Parse command line arguments
if [[ $# -eq 0 ]]; then
  usage
fi

for arg in "$@"; do
  if [[ "$arg" == --dry-run ]]; then
    if [[ $# -ne 2 || ( "$1" != --dotfiles && "$2" != --dotfiles ) ]]; then
      echo 'Use --dry-run only with --dotfiles.' >&2
      exit 1
    fi
    DRY_RUN=1
    install_dotfiles
    exit 0
  fi
done

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dotfiles)
      install_dotfiles
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
