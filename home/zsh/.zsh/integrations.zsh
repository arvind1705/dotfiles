# =============================================================================
#   SHELL INTEGRATIONS
# =============================================================================

# Starship prompt
eval "$(starship init zsh)"

# Ghostty shell integration
if [[ -n "$GHOSTTY_RESOURCES_DIR" ]]; then
    autoload -Uz -- "$GHOSTTY_RESOURCES_DIR/shell-integration/zsh/ghostty-integration"
    ghostty-integration
    unfunction ghostty-integration
fi

# OrbStack CLI integration (adds completions; PATH is set in ~/.zsh/path.zsh)
[[ -f "$HOME/.orbstack/shell/init.zsh" ]] && source "$HOME/.orbstack/shell/init.zsh"
