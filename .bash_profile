DIR_PATH="${BASH_SOURCE//\/.bash_profile}"
PARENT_DIR=${DIR_PATH%/*}
USER=$(id -F)

# Reset="\x1b[0m"
# Bright="\x1b[1m"
# Dim="\x1b[2m"
# Underscore="\x1b[4m"
# Blink="\x1b[5m"
# Reverse="\x1b[7m"
# Hidden="\x1b[8m"
# FgBlack="\x1b[30m"
# FgRed="\x1b[31m"
# FgGreen="\x1b[32m"
# FgYellow="\x1b[33m"
# FgBlue="\x1b[34m"
# FgMagenta="\x1b[35m"
# FgCyan="\x1b[36m"
# FgWhite="\x1b[37m"
# BgBlack="\x1b[40m"
# BgRed="\x1b[41m"
# BgGreen="\x1b[42m"
# BgYellow="\x1b[43m"
# BgBlue="\x1b[44m"
# BgMagenta="\x1b[45m"
# BgCyan="\x1b[46m"
# BgWhite="\x1b[47m"

# colors!
green="\[\033[0;32m\]"
light_green="\[\033[32m\]"
blue="\[\033[0;34m\]"
purple="\[\033[0;35m\]"
reset="\[\033[0m\]"
red="\[\e[1;31m\]"
yellow="\[\e[93m\]"

# REMOVE `ZSH` WARNING IN CATALINA
export BASH_SILENCE_DEPRECATION_WARNING=1


alias get_npm_global_pkgs='npm list -g --depth 0'
alias source_bash_profile='source ~/.bash_profile'
alias get_os_cores='sysctl hw.physicalcpu hw.logicalcpu'
alias track_cpu_ussage="while true; do ps -A -o %cpu | awk '{s+=$1} END {print s "%"}' >> cpu.txt; sleep 10; done" # logs CPU ussage to 'cpu.txt'
alias get_process_in_running_in_port="lsof -i tcp:"

# IF .nvmrc EXIST SET `NODE` VERSION FOR CURRENT TERMINAL SESSION
function updateNodeVersion() {
    if [ -f ./.nvmrc ]
    then
        echo ''
        echo '.nvmrc FOUND - SETTING UP PORPER NODE VERSION'
        nvm install
    else
        echo "NODE VERSION: $(node -v)"
    fi
}
# updateNodeVersion


# GIT
## Enable git tab completion
[[ -r "/usr/local/etc/profile.d/bash_completion.sh" ]] && . "/usr/local/etc/profile.d/bash_completion.sh"
[[ -f "${DIR_PATH}/.git-completion.bash" ]] && . ${DIR_PATH}/.git-completion.bash

source "${DIR_PATH}/.git-prompt.sh"
export GIT_PS1_SHOWDIRTYSTATE=1
export GIT_PS1_SHOWSTASHSTATE=1
export GIT_PS1_SHOWUNTRACKEDFILES=1
export GIT_PS1_SHOWUPSTREAM='verbose' # auto | verbose
export GIT_PS1_SHOWCOLORHINTS=1
export GIT_PS1_STATESEPARATOR=' '
export GIT_PS1_DESCRIBE_STYLE='descriptive'
alias git_look_up="git log -p -S " # example: git log -p -S <string to look up>
## Graphs
alias lg=lg1
alias lg1="git log --graph --abbrev-commit --decorate --format=format:'%C(bold blue)%h%C(reset) - %C(bold green)(%ar)%C(reset) %C(auto)%s%C(reset) %C(blue)- %an%C(reset)%C(auto)%d%C(reset)'"
alias lg2="git log --graph --abbrev-commit --decorate --format=format:'%C(bold blue)%h%C(reset) - %C(bold cyan)%aD%C(reset) %C(bold green)(%ar)%C(reset)%C(auto)%d%C(reset)%n''          %C(auto)%s%C(reset) %C(blue)- %an%C(reset)'"
alias lg3="git log --graph --abbrev-commit --decorate --format=format:'%C(bold blue)%h%C(reset) - %C(bold cyan)%aD%C(reset) %C(bold green)(%ar)%C(reset) %C(bold cyan)(committed: %cD)%C(reset) %C(auto)%d%C(reset)%n''          %C(auto)%s%C(reset)%n''          %C(blue)- %an <%ae> %C(reset) %C(blue)(committer: %cn <%ce>)%C(reset)'"


# SDKMAN
export SDKMAN_DIR="/Users/${USER}/.sdkman"
[[ -s "/Users/${USER}/.sdkman/bin/sdkman-init.sh" ]] && source "/Users/${USER}/.sdkman/bin/sdkman-init.sh"


# # JAVA
# alias java_get_all_versions="/usr/libexec/java_home -V"
# # SET DEFAULT VERSION
# export JAVA_HOME=$(/usr/libexec/java_home -v 1.8.0_251) # Java SE 8
# # export JAVA_HOME=$(/usr/libexec/java_home -v 1.6.0_65-b14-468) # Java SE 6


# DOCKER
alias docker_stop_all_containers="docker stop \$(docker ps -aq)"
alias drun='docker run -it --rm --network=host -v $(pwd):/opt/work --workdir=/opt/work' # ? ASK @MAREQ i.e: drun debian:latest /bin/bash
alias drun-cloud-infrastructure-build="drun fluidic.azurecr.io/ci-cloud-rust:1.53.0-slim-buster just cloud-infrastructure-build" # debian.buster === stable  . debian.bulleye === testing
alias drun-data-analytics-build="drun fluidic.azurecr.io/ci-cloud-rust:1.53.0-slim-buster just data-analytics-build" # debian.buster === stable  . debian.bulleye === testing

# MYSQL
# MySQL Client
# alias mysql='/Applications/MySQLWorkbench.app/Contents/MacOS/mysql'
# MySQL Dump
# ln -s /Applications/MySQLWorkbench.app/Contents/MacOS/mysqldump /usr/local/bin/mysqldump

# AWS
## source aws_complete
### Path to `/usr/local/bin/aws_completer` have to be added to $PATH > Added directly to `/etc/paths`
# complete -C '/usr/local/bin/aws_completer' aws
# complete -C $(which aws_completer) aws
## aws helpers
# source $PARENT_DIR/dx-tools/deployment-permissions.sh

# awsSetDefaults # function defined in ../dx-tools/deployment-permissions.sh

# PROMPT
# '\u' adds the name of the current user to the prompt
# '\$(__git_ps1)' adds git-related stuff
# '\W' adds the name of the current directory
export PS1="\n$red\$(/bin/date)$blue jobs:\j \n$purple\u $light_green\w $blue\$(__git_ps1 \" (%s)\") \n$red[\!] $green$ $reset"


# ITERM
test -e "${HOME}/.iterm2_shell_integration.bash" && source "${HOME}/.iterm2_shell_integration.bash"


# CUSTOM COMMANDS
## Print my public IP
alias myip='curl ipinfo.io/ip'

## HISTORY
HISTTIMEFORMAT="%F %T: "


## ls
function ls() {
    # builtin ls "$@"
    exa "$@"
}
# alias ls='ls -GFh'
# alias lsa="ls -al"
alias lsa="exa -al"

## cd
export CDPATH=:~:~/Repos:~/Code:~/Sites
# function cd() {
#     builtin cd "$@"
#     updateNodeVersion
# }


# CUSTOM FUNCTIONS
function start_server() {
    PORT=$1
    python -m SimpleHTTPServer ${PORT-8000}
}

function killPort() {
    if [ -z "$1" ]
    then
        echo "[ ERROR ] Please pass a port, run: 'killPort <port>'"
    else
        echo "**** KILLING FOLLOWING PROCCESS ****"
        lsof -i tcp:$1
        kill $(lsof -ti tcp:$1)
    fi
}

function listProcessOnPort() {
    if [ -z "$1" ]
    then
        echo "[ ERROR ] Please pass a port, run: 'listProcessOnPort <port>'"
    else
        lsof -i tcp:$1
    fi
}

function moveToTrash () {
    if [ -z "$1" ]
    then
        echo "[ ERROR ] Please pass a dir or file path."
    else
        mv ${1} ~/.Trash
    fi
}

function replaceTextInFiles() {
    if [[ -z "$1" || -z "$2" ]]
    then
        echo "[ ERROR ] Missing args, run: 'replaceTextInFiles <original-text> <new-text> <file-glob>? '"
    else
        # LC_ALL=C find . -type f -name '*.json' -exec $(sed -i '' s/${$1}/${2}/ {}) +
        LC_ALL=C find . -type f -name '*.json' -exec sed -i '' s/F1W-058/F1W-001/ {} +
    fi
}
