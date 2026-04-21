# shellcheck shell=bash
# Python helpers — all cheap (aliases + functions only).

alias py_venv_create='python3 -m venv .venv && touch requirements.txt'
alias py_venv_activate='source .venv/bin/activate'
alias py_venv_deactivate='deactivate'
alias py_pip_list='python3 -m pip list'
alias py_pip_install_requirements='python3 -m pip install -r requirements.txt'

py_start_server_python2() {
  python -m SimpleHTTPServer "${1:-8000}"
}

py_start_server_python3() {
  python3 -m http.server "${1:-8000}"
}
