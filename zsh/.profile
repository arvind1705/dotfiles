# POSIX login-shell environment (sh/bash).
# zsh reads ~/.zshenv and ~/.zshrc instead.

[[ -f "$HOME/.cargo/env" ]] && . "$HOME/.cargo/env"

export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/.bun/bin:$PATH"
export PATH="$HOME/.opencode/bin:$PATH"
export PATH="/Applications/Sublime Text.app/Contents/SharedSupport/bin:$PATH"
export PATH="/Library/Frameworks/Python.framework/Versions/3.14/bin:$PATH"
export PATH="$PATH:$HOME/.orbstack/bin"

export BUN_INSTALL="$HOME/.bun"
export EDITOR="subl -w"
export ARUBA_HOME="$HOME/aruba"
export GOPATH="$HOME/.cache/go"
export GOMODCACHE="$HOME/.cache/go/pkg/mod"
export AWS_PROFILE="shared_repo"
export APP_ENV="DEVELOPMENT"
