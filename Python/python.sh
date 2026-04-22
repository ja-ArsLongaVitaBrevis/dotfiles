# shellcheck shell=bash
# Python helpers — all cheap (aliases + functions only).

# Stop venv's `activate` script from prepending "(.venv) " to PS1. Our custom
# PS1 starts with "\n" (blank line before each prompt); if venv prepends its
# marker, the marker lands on that blank line alone and looks detached. We
# render our own venv marker from $VIRTUAL_ENV inside PS1 instead.
export VIRTUAL_ENV_DISABLE_PROMPT=1

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
