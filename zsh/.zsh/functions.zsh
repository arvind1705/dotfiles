# =============================================================================
#   CUSTOM FUNCTIONS
# =============================================================================

# =============================================================================
#   UPDATES
# =============================================================================

# Upgrade all development tools
upall() {
  # OS package manager: Homebrew on macOS, apt on Ubuntu
  if [[ "$(uname -s)" == "Darwin" ]]; then
    if command -v brew >/dev/null 2>&1; then
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

  echo "→ opencode"
  if opencode upgrade >/dev/null 2>&1; then
    echo "✓ $(opencode --version 2>/dev/null)"
  else
    echo "✗ opencode failed"
  fi

  echo "→ codex"
  if codex update >/dev/null 2>&1; then
    echo "✓ $(codex --version 2>/dev/null)"
  else
    echo "✗ codex failed"
  fi

  echo "→ claude"
  if claude update >/dev/null 2>&1; then
    echo "✓ $(claude --version 2>/dev/null)"
  else
    echo "✗ claude failed"
  fi

  echo "→ agy"
  if agy update >/dev/null 2>&1; then
    echo "✓ $(agy --version 2>/dev/null)"
  else
    echo "✗ agy failed"
  fi

  echo "✓ All upgrades complete"
}


# =============================================================================
# =============================================================================

    local jobs=20

    xargs -0 -n1 -P "$jobs" sh -c '
        repo="${1%/.git}"
        name=$(basename "$repo")

        printf "[START] %s\n" "$name"

        if git -C "$repo" fetch --all --prune --jobs=4 --quiet; then
            printf "[DONE ] %s\n" "$name"
        else
            printf "[ERROR] %s\n" "$name" >&2
        fi
    ' _
}



# =============================================================================
# =============================================================================

