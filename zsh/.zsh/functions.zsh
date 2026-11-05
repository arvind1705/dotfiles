# =============================================================================
#   CUSTOM FUNCTIONS
# =============================================================================

# =============================================================================
#   UPDATES
# =============================================================================

# Upgrade all development tools
upall() {
  echo "→ brew"
  if brew update >/dev/null 2>&1 && brew upgrade -y >/dev/null 2>&1 && brew cleanup >/dev/null 2>&1; then
    echo "✓ brew latest"
  else
    echo "✗ brew failed"
  fi

  echo "→ opencode"
  if opencode upgrade >/dev/null 2>&1; then
    echo "✓ $(opencode --version 2>/dev/null)"
  else
    echo "✗ opencode failed"
  fi

  echo "→ cmd"
  if cmd update >/dev/null 2>&1; then
    echo "✓ cmd $(cmd --version 2>/dev/null)"
  else
    echo "✗ cmd failed"
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

