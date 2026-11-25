# =============================================================================
#   PATH — sourced by ~/.zprofile (login shells, after macOS path_helper) and
#   ~/.zshrc (interactive shells). Safe to source more than once.
# =============================================================================

# No duplicates, even when entries are added later.
typeset -U path PATH

# Highest priority first; system entries keep their order after these.
path=(
  "$HOME/.local/bin"
  "$BUN_INSTALL/bin"
  "$HOME/.opencode/bin"
  "/Applications/Sublime Text.app/Contents/SharedSupport/bin"
  "/Library/Frameworks/Python.framework/Versions/3.14/bin"
  /opt/homebrew/bin
  /opt/homebrew/sbin
  $path
  "$HOME/.orbstack/bin"
)

# Drop directories that do not exist on this machine (e.g. macOS paths on Linux).
path=(${^path}(N-/))
export PATH
