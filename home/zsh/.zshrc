# =============================================================================
#   SHELL DEFAULTS
# =============================================================================

: ${HISTFILE:=$HOME/.zsh_history}
HISTSIZE=50000
SAVEHIST=10000
setopt extended_history hist_expire_dups_first hist_ignore_dups hist_ignore_space hist_verify share_history
setopt auto_cd auto_pushd pushd_ignore_dups pushdminus

bindkey -e
autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey '^[[A' up-line-or-beginning-search
bindkey '^[OA' up-line-or-beginning-search
bindkey '^[[B' down-line-or-beginning-search
bindkey '^[OB' down-line-or-beginning-search


# =============================================================================
#   PATH
# =============================================================================

source "$HOME/.zsh/path.zsh"

if (( ! $+functions[compdef] )); then
    autoload -Uz compinit
    compinit
fi


# =============================================================================
#   INTEGRATIONS
# =============================================================================

source "$HOME/.zsh/integrations.zsh"


# =============================================================================
#   ENVIRONMENT (interactive shells)
# =============================================================================

export EDITOR="subl -w"


# =============================================================================
#   SECRETS — never committed
# =============================================================================

[[ -f "$HOME/.zsh/secrets.zsh" ]] && source "$HOME/.zsh/secrets.zsh"


# =============================================================================
#   RUNTIMES
# =============================================================================

source "$HOME/.zsh/runtimes.zsh"


# =============================================================================
#   FUNCTIONS
# =============================================================================

source "$HOME/.zsh/functions.zsh"


# =============================================================================
#   OPENCODE
# =============================================================================

source "$HOME/.zsh/oc.zsh"


# =============================================================================
#   ALIASES
# =============================================================================

source "$HOME/.zsh/aliases.zsh"


# =============================================================================
#   COMPLETIONS
# =============================================================================

[[ -s "$BUN_INSTALL/_bun" ]] && source "$BUN_INSTALL/_bun"


# =============================================================================
#   FILE ENCRYPTION
# =============================================================================

encrypt() { openssl enc -aes-256-cbc -pbkdf2 -salt -in "${1:?usage: encrypt file}" -out "$1.enc"; }
decrypt() { openssl enc -d -aes-256-cbc -pbkdf2 -in "${1:?usage: decrypt file.enc}" -out "${1%.enc}"; }

[[ ! -r "$HOME/.zsh/local.zsh" ]] || source "$HOME/.zsh/local.zsh"
