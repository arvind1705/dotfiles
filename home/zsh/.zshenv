# =============================================================================
#   ZSH ENVIRONMENT — loaded by every zsh (login, interactive, scripts)
# =============================================================================

export BUN_INSTALL="$HOME/.bun"

export GOPATH="$HOME/.cache/go"
export GOMODCACHE="$HOME/.cache/go/pkg/mod"

export APP_ENV="DEVELOPMENT"


[[ ! -r "$HOME/.zsh/env.local.zsh" ]] || source "$HOME/.zsh/env.local.zsh"
