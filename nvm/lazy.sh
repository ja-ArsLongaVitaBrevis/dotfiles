# shellcheck shell=bash
# NVM lazy-load — sourced from .bash_profile.
#
# Why: the real nvm.sh is ~4,700 lines; sourcing it at startup costs 500 ms–2 s.
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

  # Expose the default Node on PATH without loading nvm. Scripts and editors
  # that call `node` outside a shell function (no function context) still work.
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

# .nvmrc auto-switch on `cd`. Replaces the old global `cd` override.
# - To enable per-session only: comment the line below and instead run
#     source "$DOTFILES_DIR/nvm/auto-switch.sh"
# - To disable entirely: comment the line below.
[[ -r "$DOTFILES_DIR/nvm/auto-switch.sh" ]] && source "$DOTFILES_DIR/nvm/auto-switch.sh"
