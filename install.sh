#!/bin/sh
# Dotfiles installer — symlinks repo files into $HOME. No secrets touched.
# Usage: ./install.sh [--force]
set -e
DOT="$(cd "$(dirname "$0")" && pwd)"
FORCE=0
[ "$1" = "--force" ] && FORCE=1

link() {
  src="$DOT/$1"
  dst="$HOME/$2"
  mkdir -p "$(dirname "$dst")"
  if [ -e "$dst" ] && [ ! -L "$dst" ]; then
    if [ "$FORCE" = "1" ]; then
      mv "$dst" "$dst.bak.$(date +%s)"
      echo "backed up $dst"
    else
      echo "skip $dst (exists, use --force)"
      return
    fi
  fi
  ln -sfn "$src" "$dst"
  echo "linked $dst -> $src"
}

link zsh/.zshrc .zshrc
link zsh/.zprofile .zprofile
link zsh/.zshenv .zshenv
link zsh/.profile .profile
link zsh/.zsh/aliases.zsh .zsh/aliases.zsh
link zsh/.zsh/functions.zsh .zsh/functions.zsh
link zsh/.zsh/integrations.zsh .zsh/integrations.zsh
link zsh/.zsh/runtimes.zsh .zsh/runtimes.zsh
link config/ghostty/config .config/ghostty/config
link config/starship.toml .config/starship.toml
link config/opencode/opencode.json .config/opencode/opencode.json
link config/opencode/cli.json .config/opencode/cli.json
link config/zed/settings.json .config/zed/settings.json
link config/git/ignore .config/git/ignore
link git/.gitconfig .gitconfig

# Never symlink secrets: create placeholder if missing
if [ ! -f "$HOME/.zsh/secrets.zsh" ]; then
  cp "$DOT/zsh/.zsh/secrets.zsh.example" "$HOME/.zsh/secrets.zsh"
  chmod 600 "$HOME/.zsh/secrets.zsh"
  echo "created ~/.zsh/secrets.zsh from example (fill in locally)"
fi

echo "done. Set git identity locally:"
echo '  git config --global user.name "Your Name"'
echo '  git config --global user.email "you@example.com"'
