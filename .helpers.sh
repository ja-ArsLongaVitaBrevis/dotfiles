# ALIAS
alias get_os_cores='sysctl hw.physicalcpu hw.logicalcpu'
alias track_cpu_ussage="while true; do ps -A -o %cpu | awk '{s+=$1} END {print s "%"}' >> cpu.txt; sleep 10; done" # logs CPU ussage to 'cpu.txt'
alias get_process_running_in_port="lsof -i tcp:"
## Print my public IP
alias get_myip='curl ipinfo.io/ip'

# CUSTOM FUNCTIONS

## ls
function ls() {
    # builtin ls "$@"
    exa "$@"
}
# alias ls='ls -GFh'
# alias lsa="ls -al"
alias lsa="exa -al"

function start_server_python2() {
    PORT=$1
    python -m SimpleHTTPServer ${PORT-8000}
}

function start_server_python3() {
    PORT=$1
    python3 -m http.server ${PORT-8000}
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