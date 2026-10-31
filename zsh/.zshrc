# =============================================================================
#   OH MY ZSH
# =============================================================================

export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME=""
plugins=(git)

fpath=("$HOME/.docker/completions" $fpath)

source "$ZSH/oh-my-zsh.sh"


# =============================================================================
#   INTEGRATIONS
# =============================================================================

source "$HOME/.zsh/integrations.zsh"


# =============================================================================
#   PATH
# =============================================================================

typeset -U path PATH

export PATH="$HOME/.local/bin:$PATH"

export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

export PATH="$HOME/.opencode/bin:$PATH"


# =============================================================================
#   ENVIRONMENT
# =============================================================================

export EDITOR="subl -w"
export ARUBA_HOME="$HOME/aruba"

export GOPATH="$HOME/.cache/go"
export GOMODCACHE="$HOME/.cache/go/pkg/mod"



# =============================================================================
#   SECRETS
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


# bun completions
[ -s "/Users/aravindg/.bun/_bun" ] && source "/Users/aravindg/.bun/_bun"
# oMLX: CLI shim path begin
case ":$PATH:" in
  *":$HOME/.omlx/bin:"*) ;;
  *) export PATH="$HOME/.omlx/bin:$PATH" ;;
esac
# oMLX: CLI shim path end

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$('/Users/aravindg/miniconda3/bin/conda' 'shell.zsh' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "/Users/aravindg/miniconda3/etc/profile.d/conda.sh" ]; then
        . "/Users/aravindg/miniconda3/etc/profile.d/conda.sh"
    else
        export PATH="/Users/aravindg/miniconda3/bin:$PATH"
    fi
fi
unset __conda_setup
# <<< conda initialize <<<



# Added by Antigravity CLI installer
export PATH="/Users/aravindg/.local/bin:$PATH"
