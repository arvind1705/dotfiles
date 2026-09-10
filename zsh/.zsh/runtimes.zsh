# =============================================================================
#   LANGUAGE RUNTIMES (lazy-loaded)
# =============================================================================

# NVM — lazy-loaded for fast shell startup
export NVM_DIR="$HOME/.nvm"

# Pre-populate PATH with npm global binaries for immediate access
# (node/npm/nvm themselves still lazy-load on first use)
if [ -d "$NVM_DIR/versions/node" ]; then
  _nvm_latest=$(/bin/ls -t "$NVM_DIR/versions/node" 2>/dev/null | head -1)
  [ -n "$_nvm_latest" ] && export PATH="$NVM_DIR/versions/node/$_nvm_latest/bin:$PATH"
  unset _nvm_latest
fi

load-nvm() {
  # Remove wrapper functions first to prevent recursion
  unset -f nvm node npm npx
  # Now load the real nvm
  [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
  [ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"
  # Activate the default node version so node/npm/npx are on PATH
  if command -v nvm >/dev/null 2>&1; then
    nvm use default >/dev/null 2>&1
  fi
  unset -f load-nvm
}
nvm()  { load-nvm; nvm "$@"; }
node() { load-nvm; command node "$@"; }
npm()  { load-nvm; command npm "$@"; }
npx()  { load-nvm; command npx "$@"; }

# Conda — lazy-loaded for fast shell startup
load-conda() {
  __conda_setup="$("$HOME/miniconda3/bin/conda" 'shell.zsh' 'hook' 2> /dev/null)"
  if [ $? -eq 0 ]; then
    eval "$__conda_setup"
  else
    if [ -f "$HOME/miniconda3/etc/profile.d/conda.sh" ]; then
      . "$HOME/miniconda3/etc/profile.d/conda.sh"
    else
      export PATH="$HOME/miniconda3/bin:$PATH"
    fi
  fi
  unset __conda_setup
}
conda() {
  unset -f conda          # Remove wrapper so it doesn't shadow conda's own function
  load-conda              # Loads conda's shell hook (defines a new `conda` function)
  unset -f load-conda     # Clean up the loader
  conda "$@"              # Now resolves to conda's shell function from the hook
}
