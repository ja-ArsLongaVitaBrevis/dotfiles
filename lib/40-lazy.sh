# shellcheck shell=bash
# Lazy loaders for expensive tools. The real tool is only loaded on first use,
# so shell startup stays fast.

# --- NVM lazy-load ------------------------------------------------------------
# The real nvm.sh is ~4700 lines; sourcing it at startup costs 500ms–2s.
# Instead, define stubs for `nvm`, `node`, `npm`, `npx`. First call unsets the
# stubs, sources the real nvm.sh, and re-invokes the command.
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"

if [[ -s "$NVM_DIR/nvm.sh" ]]; then
  _load_nvm() {
    unset -f nvm node npm npx _load_nvm
    # shellcheck source=/dev/null
    \. "$NVM_DIR/nvm.sh"
    [[ -s "$NVM_DIR/bash_completion" ]] && \. "$NVM_DIR/bash_completion"
  }
  nvm()  { _load_nvm; nvm  "$@"; }
  node() { _load_nvm; node "$@"; }
  npm()  { _load_nvm; npm  "$@"; }
  npx()  { _load_nvm; npx  "$@"; }

  # Make the default node available on PATH without loading nvm. This points
  # $PATH at nvm's alias target for `default` so scripts that call `node`
  # without a shell function (e.g. from editors) still work.
  if [[ -s "$NVM_DIR/alias/default" ]]; then
    _nvm_default_version="$(< "$NVM_DIR/alias/default")"
    if [[ -d "$NVM_DIR/versions/node/v$_nvm_default_version/bin" ]]; then
      export PATH="$NVM_DIR/versions/node/v$_nvm_default_version/bin:$PATH"
    elif [[ -d "$NVM_DIR/versions/node/$_nvm_default_version/bin" ]]; then
      export PATH="$NVM_DIR/versions/node/$_nvm_default_version/bin:$PATH"
    fi
    unset _nvm_default_version
  fi
fi

# Opt-in .nvmrc auto-switch: replaces the old global `cd` override.
# To enable per-session: `source $DOTFILES_DIR/tools/nvm-auto-switch.sh`
# To enable always: uncomment the next line.
# [[ -r "$DOTFILES_DIR/tools/nvm-auto-switch.sh" ]] && source "$DOTFILES_DIR/tools/nvm-auto-switch.sh"
