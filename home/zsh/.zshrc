# =============================================================================
#   ~/.zshrc — interactive shells
#
#   Load order: options → PATH → integrations → completion → editor →
#   secrets → runtimes → functions → aliases → ~/.zsh/local.zsh (last, so
#   machine-local settings can override anything above).
#   Environment for every shell lives in ~/.zshenv; PATH in ~/.zsh/path.zsh.
# =============================================================================

# --- History and options ------------------------------------------------------

: ${HISTFILE:=$HOME/.zsh_history}
HISTSIZE=50000
SAVEHIST=10000
setopt extended_history hist_expire_dups_first hist_ignore_dups hist_ignore_space hist_verify share_history
setopt auto_cd auto_pushd pushd_ignore_dups pushdminus

# --- Key bindings (emacs; arrows search history by prefix) ----------------------

bindkey -e
autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey '^[[A' up-line-or-beginning-search
bindkey '^[OA' up-line-or-beginning-search
bindkey '^[[B' down-line-or-beginning-search
bindkey '^[OB' down-line-or-beginning-search

# --- PATH, prompt and tool integrations -------------------------------------

source "$HOME/.zsh/path.zsh"
source "$HOME/.zsh/integrations.zsh"

# --- Completion (after integrations, which may extend fpath) -------------------

if (( ! $+functions[compdef] )); then
  autoload -Uz compinit
  compinit
fi
[[ ! -s "$BUN_INSTALL/_bun" ]] || source "$BUN_INSTALL/_bun"

# --- Editor ---------------------------------------------------------------------

if (( $+commands[subl] )); then
  export EDITOR="subl -w"
else
  export EDITOR="vim"
fi

# --- Secrets (never committed) ------------------------------------------------

[[ ! -r "$HOME/.zsh/secrets.zsh" ]] || source "$HOME/.zsh/secrets.zsh"

# --- Runtimes, functions, aliases --------------------------------------------

source "$HOME/.zsh/runtimes.zsh"
source "$HOME/.zsh/functions.zsh"
source "$HOME/.zsh/aliases.zsh"

# --- Machine-local overrides (not in this repo) ------------------------------

[[ ! -r "$HOME/.zsh/local.zsh" ]] || source "$HOME/.zsh/local.zsh"
