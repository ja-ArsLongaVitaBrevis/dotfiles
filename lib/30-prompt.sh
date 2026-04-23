# shellcheck shell=bash
# Prompt: loads git-prompt (cheap — just function defs), configures PS1 with
# a CACHED git status so prompt rendering is fast even in large repos.
#
# Layout (Nerd Font required):
#   ╭─  HH:MM:SS   user   cwd   git   venv   jobs
#   ╰─ ✓ ❯
#
# Segments only render when relevant: venv when $VIRTUAL_ENV set, jobs when
# >0 background jobs, exit-code number only on failure.

# Source git-prompt.sh (defines __git_ps1). This is needed for PS1.
if [[ -r "${DOTFILES_DIR}/git_setup/git-prompt.sh" ]]; then
  source "${DOTFILES_DIR}/git_setup/git-prompt.sh"
fi

# Tuning: these flags make __git_ps1 much slower because it runs extra git
# commands per prompt. Keep the cheap ones on, the expensive ones off.
export GIT_PS1_SHOWDIRTYSTATE=1
export GIT_PS1_SHOWSTASHSTATE=1
export GIT_PS1_SHOWCOLORHINTS=1
export GIT_PS1_STATESEPARATOR=' '
export GIT_PS1_DESCRIBE_STYLE='default'
# Heavy flags — disabled for speed. Uncomment if you really need them:
# export GIT_PS1_SHOWUNTRACKEDFILES=1      # extra `git ls-files` per prompt
# export GIT_PS1_SHOWUPSTREAM='verbose'    # extra `git rev-list` per prompt

# Colors for use directly in PS1 (\[ \] tells readline these are non-printing).
_c_reset='\[\033[0m\]'
_c_dim='\[\033[38;5;240m\]'
_c_cyan='\[\033[38;5;75m\]'
_c_purple='\[\033[38;5;141m\]'
_c_green='\[\033[38;5;114m\]'
_c_yellow='\[\033[38;5;179m\]'
_c_blue='\[\033[38;5;111m\]'

# Capture exit status of the last user command BEFORE any $(...) in PS1
# clobbers $?. PROMPT_COMMAND runs first, so __last_exit is reliable.
PROMPT_COMMAND='__last_exit=$?'

# Helpers below print escape codes inline. Inside a $(...) substitution we
# can't use \[ \] (those are PS1-parser tokens), so we use the readline
# equivalents \001 (start non-printing) and \002 (end non-printing).

# Exit-status glyph: green ✓ on success, red ✗ N on failure.
_status_ps1() {
  if [[ ${__last_exit:-0} -eq 0 ]]; then
    printf '\001\033[38;5;114m\002✓\001\033[0m\002'
  else
    printf '\001\033[38;5;203m\002✗ %d\001\033[0m\002' "${__last_exit}"
  fi
}

# Background jobs: shown only when there's at least one.
_jobs_ps1() {
  local n
  n=$(jobs -p | wc -l | tr -d ' ')
  if (( n > 0 )); then
    printf '   \001\033[38;5;215m\002  jobs %d\001\033[0m\002' "$n"
  fi
}

# Python venv marker — prints "  venv-name" when $VIRTUAL_ENV is set.
# We render this ourselves because VIRTUAL_ENV_DISABLE_PROMPT=1 (set in
# Python/python.sh) suppresses activate's own PS1 mangling.
_venv_ps1() {
  if [[ -n "$VIRTUAL_ENV" ]]; then
    printf '   \001\033[38;5;213m\002  %s\001\033[0m\002' "$(basename "$VIRTUAL_ENV")"
  fi
}

# Compact CWD (fish-style): leaf stays full, parents collapse to their
# first char (preserving a leading dot for hidden dirs).
#   ~/Code/jesuarva-github/jesuarva-dotfiles  →  ~/C/j/jesuarva-dotfiles
_pwd_ps1() {
  local p="$PWD"
  [[ "$p" == "$HOME" || "$p" == "$HOME"/* ]] && p="~${p#$HOME}"
  local IFS=/
  local -a parts
  read -ra parts <<< "$p"
  local n=${#parts[@]}
  local out="" i part prefix
  for (( i=0; i<n; i++ )); do
    part="${parts[i]}"
    if (( i == n - 1 )) || [[ -z "$part" ]] || [[ "$part" == "~" ]]; then
      out+="$part"
    else
      prefix=""
      [[ "$part" == .* ]] && { prefix="."; part="${part:1}"; }
      out+="${prefix}${part:0:1}"
    fi
    (( i < n - 1 )) && out+="/"
  done
  printf '%s' "$out"
}

# PS1 — three visual lines linked by box-drawing chars.
#   ╭─  HH:MM:SS    git   venv   jobs
#   ├─  user    cwd
#   ╰─ ✓ ❯
PS1="\n"
PS1+="${_c_dim}╭─${_c_reset} "
PS1+="${_c_cyan} \$(/bin/date '+%H:%M:%S')${_c_reset}"
PS1+="${_c_yellow}\$(__git_ps1 '     %s')${_c_reset}"
PS1+="\$(_venv_ps1)"
PS1+="\$(_jobs_ps1)"
PS1+="\n"
PS1+="${_c_dim}├─${_c_reset} "
PS1+="${_c_purple} \u${_c_reset}   "
PS1+="${_c_green} \$(_pwd_ps1)${_c_reset}"
PS1+="\n"
PS1+="${_c_dim}╰─${_c_reset} \$(_status_ps1) ${_c_blue}❯${_c_reset} "
export PS1
