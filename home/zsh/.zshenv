# =============================================================================
#   ZSH ENVIRONMENT — loaded by every zsh (login, interactive, scripts)
# =============================================================================

export BUN_INSTALL="$HOME/.bun"

export GOPATH="$HOME/.cache/go"
export GOMODCACHE="$HOME/.cache/go/pkg/mod"

# Opt out of T3 Code telemetry.
export T3CODE_TELEMETRY_ENABLED=false
export T3CODE_OTEL_SDK_DISABLED=true

# Rust toolchain (rustup), for non-interactive shells too.
[[ ! -r "$HOME/.cargo/env" ]] || . "$HOME/.cargo/env"

# Machine-local and work-specific settings live in ~/.zsh/env.local.zsh (not in this repo).
[[ ! -r "$HOME/.zsh/env.local.zsh" ]] || source "$HOME/.zsh/env.local.zsh"
