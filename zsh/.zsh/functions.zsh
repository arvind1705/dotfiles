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

  echo "→ cmd"
  if cmd update >/dev/null 2>&1; then
    echo "✓ cmd $(cmd --version 2>/dev/null)"
  else
    echo "✗ cmd failed"
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
#   GIT / ARUBA
# =============================================================================

# Fetch all git repos under $ARUBA_HOME in parallel
fetcharuba() {
    local jobs=20

    find "$ARUBA_HOME" -type d -name .git -print0 |
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
#   AWS
# =============================================================================

# AWS SSO login — prints verification code in huge text
sso() {
  local profile="${1:-shared_repo}"
  local seen=0
  setopt localoptions pipefail 2>/dev/null
  aws sso login --profile "$profile" --use-device-code --no-browser 2>&1 |
    while IFS= read -r line; do
      local trimmed="${line//[[:space:]]/}"
      if [[ $seen -eq 0 && "$trimmed" =~ ^[A-Z0-9]{4}-[A-Z0-9]{4}$ ]]; then
        echo ""
        python3 -c "
import sys, subprocess
code = sys.argv[1]
parts = code.split('-')
for i, group in enumerate(parts):
    if i > 0:
        print('  \033[1;90m─────\033[0m\n')
    result = subprocess.run(['figlet', '-f', 'banner', group], capture_output=True, text=True)
    lines = result.stdout.splitlines()
    for line in lines:
        print('  \033[1;92m' + line + '\033[0m')
    print()
" "$trimmed"
        seen=1
      fi
      print -r -- "$line"
    done
}
