alias py_venv_create="python3 -m venv .venv"

alias py_venv_activate="source .env/bin/activate"

alias py_venv_deactivate="deactivate"

function py_start_server_python2() {
    PORT=$1
    python -m SimpleHTTPServer ${PORT-8000}
}

function py_start_server_python3() {
    PORT=$1
    python3 -m http.server ${PORT-8000}
}
