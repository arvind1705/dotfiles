# =============================================================================
#   CUSTOM FUNCTIONS
# =============================================================================

# =============================================================================
#   UPDATES
# =============================================================================

# Upgrade all development tools
uall() {
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

  echo "→ codex"
  if codex update >/dev/null 2>&1; then
    echo "✓ codex $(codex --version 2>/dev/null)"
  else
    echo "✗ codex failed"
  fi

  echo "→ agy"
  if agy update >/dev/null 2>&1; then
    echo "✓ agy $(agy --version 2>/dev/null)"
  else
    echo "✗ agy failed"
  fi

  echo "✓ All upgrades complete"
}


# =============================================================================
# =============================================================================



# =============================================================================
# =============================================================================

