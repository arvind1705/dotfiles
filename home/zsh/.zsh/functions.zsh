# =============================================================================
#   FUNCTIONS
# =============================================================================

# --- Updates ----------------------------------------------------------------------

# Upgrade the OS packages (Homebrew or apt) and the agent CLIs that are installed.
upall() {
  if [[ "$(uname -s)" == Darwin ]]; then
    if (( $+commands[brew] )); then
      echo "→ brew"
      if brew update >/dev/null 2>&1 && brew upgrade >/dev/null 2>&1 && brew cleanup >/dev/null 2>&1; then
        echo "✓ brew latest"
      else
        echo "✗ brew failed"
      fi
    fi
  elif [[ -r /etc/os-release ]] && grep -q '^ID=ubuntu$' /etc/os-release; then
    echo "→ apt"
    if sudo apt update -qq && sudo apt upgrade -y -qq && sudo apt autoremove -y -qq && sudo apt autoclean -qq; then
      echo "✓ apt latest"
    else
      echo "✗ apt failed"
    fi
  fi

  local tool
  for tool in codex claude agy; do
    (( $+commands[$tool] )) || continue
    echo "→ $tool"
    if "$tool" update >/dev/null 2>&1; then
      echo "✓ $("$tool" --version 2>/dev/null | head -n 1)"
    else
      echo "✗ $tool failed"
    fi
  done

  echo "✓ All upgrades complete"
}

# --- Files ------------------------------------------------------------------------

# Passphrase-encrypt a file to FILE.enc, and back.
encrypt() { openssl enc -aes-256-cbc -pbkdf2 -salt -in "${1:?usage: encrypt file}" -out "$1.enc"; }
decrypt() { openssl enc -d -aes-256-cbc -pbkdf2 -in "${1:?usage: decrypt file.enc}" -out "${1%.enc}"; }
