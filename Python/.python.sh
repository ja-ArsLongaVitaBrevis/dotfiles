alias py_venv_create="python3 -m venv .venv && touch requirements.txt"

alias py_venv_activate="source .venv/bin/activate"

alias py_venv_deactivate="deactivate"

alias py_pip_list="python3 -m pip list"

alias py_pip_install_requirements="python3 -m pip install -r requirements.txt"

function py_start_server_python2() {
    PORT=$1
    python -m SimpleHTTPServer ${PORT-8000}
}

function py_start_server_python3() {
    PORT=$1
    python3 -m http.server ${PORT-8000}
}
