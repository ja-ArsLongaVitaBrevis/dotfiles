# shellcheck shell=bash
# Generic aliases and small helper functions. Cheap — no subprocesses at load.
# (Tool-specific aliases live in tools/*.sh.)

# ls
alias ls='ls -GFh'
alias lsa='ls -al'
alias la='ls -al'

# AI tools shortcuts
alias gemini='npx @google/gemini-cli'

# System info
alias get_os_cores='sysctl hw.physicalcpu hw.logicalcpu'
alias get_process_running_in_port='lsof -i tcp:'
alias get_myip='curl -s ipinfo.io/ip'

# CPU logger — logs to cpu.txt every 10s. Stop with Ctrl+C.
alias track_cpu_usage="while true; do ps -A -o %cpu | awk '{s+=\$1} END {print s \"%\"}' >> cpu.txt; sleep 10; done"
alias cpu_track_usage=track_cpu_usage
# Backwards-compat (typo in old config)
alias track_cpu_ussage=track_cpu_usage
alias cpu_track_ussage=track_cpu_usage

# npm
alias get_npm_global_pkgs='npm list -g --depth 0'
alias npm_get_global_pkgs=get_npm_global_pkgs

# Docker
alias docker_stop_all_containers='docker stop $(docker ps -aq)'
alias drun='docker run -it --rm --network=host -v $(pwd):/opt/work --workdir=/opt/work'

# Apple Silicon only: run a shell under Rosetta 2. `$HOSTTYPE` is a Bash
# builtin (no subprocess) and is `arm64` on Apple Silicon, `x86_64` on Intel.
if [[ "$HOSTTYPE" == "arm64" ]]; then
  alias rosetta2='arch -x86_64 bash --login'
fi

# -- Functions -----------------------------------------------------------------

killPort() {
  if [[ -z "$1" ]]; then
    echo "[ERROR] Please pass a port: killPort <port>" >&2
    return 1
  fi
  echo "**** KILLING PROCESS ON PORT $1 ****"
  lsof -i "tcp:$1"
  kill "$(lsof -ti "tcp:$1")"
}

listProcessOnPort() {
  if [[ -z "$1" ]]; then
    echo "[ERROR] Please pass a port: listProcessOnPort <port>" >&2
    return 1
  fi
  lsof -i "tcp:$1"
}

moveToTrash() {
  if [[ -z "$1" ]]; then
    echo "[ERROR] Please pass a path." >&2
    return 1
  fi
  mv "$1" ~/.Trash
}

# Safer search-and-replace. Usage: replaceTextInFiles <old> <new> [glob]
replaceTextInFiles() {
  if [[ -z "$1" || -z "$2" ]]; then
    echo "[ERROR] Usage: replaceTextInFiles <old-text> <new-text> [file-glob]" >&2
    return 1
  fi
  local glob="${3:-*.json}"
  LC_ALL=C find . -type f -name "$glob" -exec sed -i '' "s/$1/$2/g" {} +
}
