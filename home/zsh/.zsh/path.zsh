# =============================================================================
#   PATH — sourced by ~/.zprofile (login) and ~/.zshrc (interactive)
# =============================================================================

# Keep PATH free of duplicates, including later modifications.
typeset -U path PATH

# Cargo / Rust (adds ~/.cargo/bin when rustup is installed)
[[ -f "$HOME/.cargo/env" ]] && . "$HOME/.cargo/env"

# User-local binaries and tool CLIs, highest priority first.
path=(
  "$HOME/.local/bin"
  "$BUN_INSTALL/bin"
  "$HOME/.opencode/bin"
  "/Applications/Sublime Text.app/Contents/SharedSupport/bin"
  "/Library/Frameworks/Python.framework/Versions/3.14/bin"
  "/opt/homebrew/bin"
  "/opt/homebrew/sbin"
  $path
)
export PATH

# OrbStack CLI (docker, kubectl, orb)
export PATH="$PATH:$HOME/.orbstack/bin"
