# shellcheck shell=bash
# Homebrew setup. ONE `brew shellenv` subprocess per shell, no for-loop over
# completion files (we use bash-completion@2's lazy loader instead).
#
# Handles:
#   - Apple Silicon Macs (default brew prefix: /opt/homebrew)
#   - Intel Macs         (default brew prefix: /usr/local)
#   - Custom installs    (HOMEBREW_PREFIX pre-set, or brew already on PATH)
#
# Perf note: `brew shellenv` forks + execs Ruby. On Apple Silicon that costs
# ~30–50 ms. We deliberately run it EXACTLY ONCE per shell. An earlier version
# of this file called it twice — that's been merged into the block below.

_brew_cmd=""
if [[ -n "$HOMEBREW_PREFIX" && -x "$HOMEBREW_PREFIX/bin/brew" ]]; then
  _brew_cmd="$HOMEBREW_PREFIX/bin/brew"
elif [[ -x /opt/homebrew/bin/brew ]]; then
  _brew_cmd=/opt/homebrew/bin/brew
elif [[ -x /usr/local/bin/brew ]]; then
  _brew_cmd=/usr/local/bin/brew
elif command -v brew >/dev/null 2>&1; then
  _brew_cmd="$(command -v brew)"
fi

if [[ -n "$_brew_cmd" ]]; then
  # `brew shellenv` exports HOMEBREW_PREFIX, HOMEBREW_CELLAR, HOMEBREW_REPOSITORY
  # and prepends brew's bin/sbin to PATH / MANPATH / INFOPATH.
  eval "$("$_brew_cmd" shellenv)"
fi
unset _brew_cmd

# bash-completion@2 registers a lazy loader: completions are only sourced when
# you first hit TAB for that command. This replaces the old for-loop that
# eagerly sourced every file in bash_completion.d/.
if [[ -n "$HOMEBREW_PREFIX" && -r "$HOMEBREW_PREFIX/etc/profile.d/bash_completion.sh" ]]; then
  export BASH_COMPLETION_COMPAT_DIR="$HOMEBREW_PREFIX/etc/bash_completion.d"
  # shellcheck source=/dev/null
  source "$HOMEBREW_PREFIX/etc/profile.d/bash_completion.sh"
fi
