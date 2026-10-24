# =============================================================================
#   LANGUAGE RUNTIMES (lazy-loaded)
# =============================================================================

# NVM — lazy-loaded for fast shell startup
export NVM_DIR="$HOME/.nvm"

# Pre-populate PATH with npm global binaries for immediate access
# (node/npm/nvm themselves still lazy-load on first use)
if [ -d "$NVM_DIR/versions/node" ]; then
  # Prefer the configured default alias when it points at an installed version;
  # otherwise fall back to the most recently installed version.
  _nvm_default=""
  [ -f "$NVM_DIR/alias/default" ] && _nvm_default=$(cat "$NVM_DIR/alias/default" 2>/dev/null)
  if [ -n "$_nvm_default" ] && [ -d "$NVM_DIR/versions/node/$_nvm_default" ]; then
    _nvm_latest="$_nvm_default"
  else
    _nvm_latest=$(/bin/ls -t "$NVM_DIR/versions/node" 2>/dev/null | head -1)
  fi
  [ -n "$_nvm_latest" ] && export PATH="$NVM_DIR/versions/node/$_nvm_latest/bin:$PATH"
  unset _nvm_default _nvm_latest
fi

load-nvm() {
  # Remove wrapper functions first to prevent recursion
  unset -f nvm node npm npx corepack pnpm yarn
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
corepack() { load-nvm; command corepack "$@"; }
pnpm()    { load-nvm; command pnpm "$@"; }
yarn()    { load-nvm; command yarn "$@"; }

# Conda is loaded eagerly via the conda init block in ~/.zshrc.
# Base auto-activates (auto_activate_base: true in ~/.condarc), so
# `python`/`python3` resolve to miniconda's Python by default.


export APP_ENV="DEVELOPMENT"
