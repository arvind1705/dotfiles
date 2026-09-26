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

  echo "→ agy"
  if agy update >/dev/null 2>&1; then
    echo "✓ agy $(agy --version 2>/dev/null)"
  else
    echo "✗ agy failed"
  fi

  echo "→ cmd"
  if cmd update >/dev/null 2>&1; then
    echo "✓ cmd $(cmd --version 2>/dev/null)"
  else
    echo "✗ cmd failed"
  fi

  echo "✓ All upgrades complete"
}


# =============================================================================
# =============================================================================



# =============================================================================
# =============================================================================

