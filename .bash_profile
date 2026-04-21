# shellcheck shell=bash
# jesuarva-dotfiles entry point.
#
# Architecture: lib/ is infrastructure, each top-level dir is a tool module.
# Modules are sourced in a deliberate order (cheap → lazy). See README.md.
#
# Profile startup time:  DOTFILES_PROFILE=1 bash -lic exit

# Enable `time`-style per-line tracing when DOTFILES_PROFILE=1.
if [[ -n "$DOTFILES_PROFILE" ]]; then
  PS4='+ $EPOCHREALTIME  ${BASH_SOURCE##*/}:$LINENO  '
  set -x
fi

# Resolve repo root regardless of how this is sourced.
if [[ -n "${BASH_SOURCE[0]}" ]]; then
  DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
  DOTFILES_DIR="$HOME/CodeBis/jesuarva-dotfiles"
fi
export DOTFILES_DIR

# Small helper — `require <path>` sources if readable, warns otherwise.
_dotfiles_require() {
  if [[ -r "$1" ]]; then
    # shellcheck source=/dev/null
    source "$1"
  else
    echo "[dotfiles] missing: $1" >&2
  fi
}

# --- Infrastructure (ordered) -------------------------------------------------
_dotfiles_require "$DOTFILES_DIR/lib/00-core.sh"
_dotfiles_require "$DOTFILES_DIR/lib/10-brew.sh"
_dotfiles_require "$DOTFILES_DIR/lib/20-aliases.sh"

# --- Tool modules -------------------------------------------------------------
# Each is cheap (aliases, env vars, function defs only). No eager subprocesses.
_dotfiles_require "$DOTFILES_DIR/dx-tools/aws/aws.sh"
_dotfiles_require "$DOTFILES_DIR/git_setup/git_setup.sh"
_dotfiles_require "$DOTFILES_DIR/Python/python.sh"
_dotfiles_require "$DOTFILES_DIR/Rust/rust.sh"
_dotfiles_require "$DOTFILES_DIR/AiTools/ClaudeBedrock.sh"

# --- Lazy loaders (stubs for expensive tools) ---------------------------------
_dotfiles_require "$DOTFILES_DIR/nvm/lazy.sh"

# --- Prompt (last, so all git_ps1 config is in scope) -------------------------
_dotfiles_require "$DOTFILES_DIR/lib/30-prompt.sh"

# --- Per-machine overrides (git-ignored) --------------------------------------
[[ -r "$DOTFILES_DIR/.local.sh" ]] && source "$DOTFILES_DIR/.local.sh"
[[ -r "$HOME/.bash_profile.local" ]] && source "$HOME/.bash_profile.local"

unset -f _dotfiles_require

if [[ -n "$DOTFILES_PROFILE" ]]; then
  set +x
fi
