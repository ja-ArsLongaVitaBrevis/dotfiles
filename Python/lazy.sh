# shellcheck shell=bash
# pyenv lazy-load — sourced from .bash_profile.
#
# Why: `pyenv init -` shells out to pyenv and registers shims + completions;
# running it at startup adds visible latency on every new shell.  Instead,
# define lightweight stubs for `pyenv`, `python`, `python3`, `pip`, and `pip3`.
# The first call unsets the stubs, runs the real init, and re-invokes the
# command — subsequent calls hit the real binaries directly.
#
# COMMON FOOTGUN: Homebrew's post-install note suggests adding
#   eval "$(pyenv init -)"
# to ~/.bash_profile or ~/.profile.  If that block runs AFTER this file it
# defeats the lazy loader entirely.  Run `bin/bench-shell.sh doctor` to detect
# an eager pyenv init in your startup files.

export PYENV_ROOT="${PYENV_ROOT:-$HOME/.pyenv}"

# If pyenv is already a loaded shell function (e.g. someone added an eager
# eval block before us) or PYENV_ROOT doesn't exist, skip defining stubs.
if declare -F pyenv >/dev/null 2>&1; then
  if [[ -n "${DOTFILES_PROFILE:-}" ]]; then
    echo "[dotfiles] pyenv is already loaded before Python/lazy.sh ran —" >&2
    echo "[dotfiles] check ~/.bash_profile for an eager \`eval \"\$(pyenv init -)\"\` block." >&2
  fi
elif [[ -d "$PYENV_ROOT" ]]; then
  # Ensure pyenv's own bin is on PATH so the binary is reachable.
  [[ ":$PATH:" != *":$PYENV_ROOT/bin:"* ]] && export PATH="$PYENV_ROOT/bin:$PATH"

  _load_pyenv() {
    unset -f pyenv python python3 pip pip3 _load_pyenv
    # shellcheck source=/dev/null
    eval "$(pyenv init -)"
  }

  pyenv()   { _load_pyenv; pyenv   "$@"; }
  python()  { _load_pyenv; python  "$@"; }
  python3() { _load_pyenv; python3 "$@"; }
  pip()     { _load_pyenv; pip     "$@"; }
  pip3()    { _load_pyenv; pip3    "$@"; }

  # Expose the active pyenv shims on PATH *without* loading pyenv.
  # Editors and scripts that invoke `python` outside a shell function context
  # (no function dispatch) will still find the pyenv-managed binary.
  if [[ -d "$PYENV_ROOT/shims" ]]; then
    [[ ":$PATH:" != *":$PYENV_ROOT/shims:"* ]] && export PATH="$PYENV_ROOT/shims:$PATH"
  fi
fi
