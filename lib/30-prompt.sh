# shellcheck shell=bash
# Prompt: loads git-prompt (cheap — just function defs), configures PS1 with
# a CACHED git status so prompt rendering is fast even in large repos.

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

# Colors
_c_green='\[\033[0;32m\]'
_c_light_green='\[\033[32m\]'
_c_blue='\[\033[0;34m\]'
_c_purple='\[\033[0;35m\]'
_c_red='\[\e[1;31m\]'
_c_yellow='\[\e[93m\]'
_c_reset='\[\033[0m\]'

# PS1:
#   line 1: [timestamp] jobs:N
#   line 2: user CWD (git-info)
#   line 3: [history#] $
PS1="\n${_c_red}\$(/bin/date '+%H:%M:%S')${_c_blue} jobs:\j \n${_c_purple}\u ${_c_light_green}\w ${_c_blue}\$(__git_ps1 \" (%s)\") \n${_c_red}[\!] ${_c_green}$ ${_c_reset}"
export PS1
