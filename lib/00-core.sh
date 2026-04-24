# shellcheck shell=bash
# Core shell setup — always cheap. No subprocess calls here.

# Silence macOS's "default shell is now zsh" warning.
export BASH_SILENCE_DEPRECATION_WARNING=1

# History.
export HISTTIMEFORMAT="%F %T: "
export HISTSIZE=10000
export HISTFILESIZE=20000
shopt -s histappend 2>/dev/null || true

# Re-source this whole setup easily.
alias source_bash_profile='source ~/.bash_profile'
alias reload='source ~/.bash_profile'

export PATH="$HOME/.local/bin:$PATH"
