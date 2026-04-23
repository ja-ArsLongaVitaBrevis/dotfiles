# shellcheck shell=bash
# NVM lazy-load — sourced from .bash_profile.
#
# Why: the real nvm.sh is ~4,700 lines; sourcing it at startup costs 250 ms–2 s
# on Apple Silicon. Instead, define stubs for `nvm`, `node`, `npm`, `npx`.
# First call unsets the stubs, sources the real nvm.sh, and re-invokes the
# command.
#
# COMMON FOOTGUN: many NVM install instructions append an EAGER loader block
# (`[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"`) to `~/.bash_profile`.
# If that block runs AFTER this file, it defeats the lazy loader entirely.
# See `bin/bench-shell.sh` — an interactive login shell should measure ≤0.10 s
# on any modern Mac; if you see 0.30 s+, grep ~/.bash_profile for `nvm.sh`
# and remove any eager source line.

export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"

# Skip defining stubs if nvm is already a loaded function (someone else beat
# us to it — probably the eager loader described above). In that case the
# real `nvm` is already in scope; defining stubs would be a no-op at best
# and could mask bugs at worst. Emit a hint only in profile mode.
if declare -F nvm >/dev/null 2>&1; then
  if [[ -n "${DOTFILES_PROFILE:-}" ]]; then
    echo "[dotfiles] nvm is already loaded before nvm/lazy.sh ran — "   >&2
    echo "[dotfiles] check ~/.bash_profile for an eager \`. nvm.sh\` block." >&2
  fi
elif [[ -s "$NVM_DIR/nvm.sh" ]]; then
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
