# $BASH_SOURCE is a reference to the absolut_path of this file
# DIR_PATH=$(dirname "$BASH_SOURCE")
DIR_PATH="${BASH_SOURCE//\/.bash_profile}"
PARENT_DIR=${DIR_PATH%/*}
USER=$(id -F)

# ALIAS
alias source_bash_profile='source ~/.bash_profile'

# REMOVE `ZSH` WARNING IN CATALINA
export BASH_SILENCE_DEPRECATION_WARNING=1

# HOMEBREW - BREW
source "${DIR_PATH}/.brew.sh"

# AWS
source "${DIR_PATH}/dx-tools/aws/.aws_setup.sh"

# NVM - NODE
source "${DIR_PATH}/nvm/.nvm_setup.sh"

# GIT
source "${DIR_PATH}/git_setup/.git_setup.sh"

# HELPERS
source "${DIR_PATH}/.helpers.sh"

# NPM
# source "${DIR_PATH}/.npm_completion"
alias npm_get_global_pkgs='npm list -g --depth 0'


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

# PROMPT
# '\u' adds the name of the current user to the prompt
# '\$(__git_ps1)' adds git-related stuff
# '\W' adds the name of the current directory
export PS1="\n$red\$(/bin/date)$blue jobs:\j \n$purple\u $light_green\w $blue\$(__git_ps1 \" (%s)\") \n$red[\!] $green$ $reset"




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


## HISTORY
HISTTIMEFORMAT="%F %T: "


# SMART SPACE
alias ssl_local_proxy="nvm use 16.17.0 && local-ssl-proxy -s 29000 -t 3000 -c /Users/jean.ariza/Code/localssl/wildcard.platform.localhost.crt -k /Users/jean.ariza/Code/localssl/wildcard.platform.localhost.key"
alias ssl_local_proxy_3001="nvm use 16.17.0 && local-ssl-proxy -s 29000 -t 3001 -c /Users/jean.ariza/Code/localssl/wildcard.platform.localhost.crt -k /Users/jean.ariza/Code/localssl/wildcard.platform.localhost.key"
# alias ss_local_proxy="local-ssl-proxy -s 29000 -t 3000 -c /mnt/c/JeanTemp/SSL_PROXY/wildcard.platform.localhost.crt -k /mnt/c/JeanTemp/SSL_PROXY/wildcard.platform.localhost.key"

# MAc OS - M1 chip
alias rosetta2="arch -x86_64 bash --login"
