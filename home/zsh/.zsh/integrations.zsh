# =============================================================================
#   INTEGRATIONS — prompt, terminal and tool shell hooks (before compinit)
# =============================================================================

# Starship prompt
(( ! $+commands[starship] )) || eval "$(starship init zsh)"

# Ghostty shell integration
if [[ -n "$GHOSTTY_RESOURCES_DIR" ]]; then
  autoload -Uz -- "$GHOSTTY_RESOURCES_DIR/shell-integration/zsh/ghostty-integration"
  ghostty-integration
  unfunction ghostty-integration
fi

# OrbStack: adds its completions to fpath (PATH is handled in path.zsh)
[[ ! -r "$HOME/.orbstack/shell/init.zsh" ]] || source "$HOME/.orbstack/shell/init.zsh"
