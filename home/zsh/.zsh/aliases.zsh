# =============================================================================
#   ALIASES
# =============================================================================

alias l='ls -lah'
alias la='ls -lAh'
alias uall='upall'

# GNU timeout on macOS (coreutils installs it as gtimeout)
(( ! $+commands[gtimeout] )) || alias timeout='gtimeout'
