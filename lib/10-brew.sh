# shellcheck shell=bash
# Homebrew setup. One `brew shellenv` call (cached via export), and a single
# completion entry point — NOT a loop over every completion file.

# Apple Silicon puts brew in /opt/homebrew; Intel macs use /usr/local.
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /usr/local/bin/brew ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

# bash-completion@2 registers a lazy loader: completions are only sourced when
# you first hit TAB for that command. This replaces the old for-loop that
# eagerly sourced every file in bash_completion.d/.
if [[ -n "$HOMEBREW_PREFIX" && -r "$HOMEBREW_PREFIX/etc/profile.d/bash_completion.sh" ]]; then
  export BASH_COMPLETION_COMPAT_DIR="$HOMEBREW_PREFIX/etc/bash_completion.d"
  source "$HOMEBREW_PREFIX/etc/profile.d/bash_completion.sh"
fi
