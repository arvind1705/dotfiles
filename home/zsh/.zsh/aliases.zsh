# =============================================================================
#   ALIASES
# =============================================================================

# Colors (GNU ls needs the flag; macOS ls uses CLICOLOR from ~/.zshrc)
[[ "$(uname -s)" == Darwin ]] || alias ls='ls --color=auto'
alias grep='grep --color=auto'

alias l='ls -lah'
alias la='ls -lAh'
alias uall='upall'

# GNU timeout on macOS (coreutils installs it as gtimeout)
(( ! $+commands[gtimeout] )) || alias timeout='gtimeout'
