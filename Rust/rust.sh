# shellcheck shell=bash
# Rust / Cargo. Guarded so missing install doesn't break the shell.

if [[ -r "$HOME/.cargo/env" ]]; then
  # shellcheck source=/dev/null
  source "$HOME/.cargo/env"
fi
