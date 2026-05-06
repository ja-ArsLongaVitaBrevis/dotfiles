# shellcheck shell=bash
# `dotfiles` repo entry point.
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

# Resolve repo root dynamically. The repo can live anywhere on disk — this
# block derives its own location from BASH_SOURCE, follows symlinks, and
# works identically on any device as long as ~/.bash_profile sources (or
# symlinks to) this file.
#
# Supports two install styles:
#   1) source <repo>/.bash_profile          — absolute or relative path
#   2) ln -s <repo>/.bash_profile ~/.bash_profile   — symlinked
_dotfiles_src="${BASH_SOURCE[0]:-}"
if [[ -z "$_dotfiles_src" ]]; then
  echo "[dotfiles] ERROR: BASH_SOURCE unavailable; cannot locate repo." >&2
  unset _dotfiles_src
  return 1 2>/dev/null || exit 1
fi
# Resolve symlink chain manually (macOS lacks `readlink -f`).
while [[ -L "$_dotfiles_src" ]]; do
  _dotfiles_dir="$(cd "$(dirname "$_dotfiles_src")" && pwd -P)"
  _dotfiles_src="$(readlink "$_dotfiles_src")"
  [[ "$_dotfiles_src" != /* ]] && _dotfiles_src="$_dotfiles_dir/$_dotfiles_src"
done
DOTFILES_DIR="$(cd "$(dirname "$_dotfiles_src")" && pwd -P)"
unset _dotfiles_src _dotfiles_dir
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
_dotfiles_require "$DOTFILES_DIR/git_setup/identities/identities.sh"
_dotfiles_require "$DOTFILES_DIR/Python/python.sh"
_dotfiles_require "$DOTFILES_DIR/Rust/rust.sh"
_dotfiles_require "$DOTFILES_DIR/AiTools/ClaudeBedrock.sh"

# --- Lazy loaders (stubs for expensive tools) ---------------------------------
_dotfiles_require "$DOTFILES_DIR/nvm/lazy.sh"
_dotfiles_require "$DOTFILES_DIR/Python/lazy.sh"
_dotfiles_require "$DOTFILES_DIR/git_setup/lazy.sh"

# --- Prompt (last, so all git_ps1 config is in scope) -------------------------
_dotfiles_require "$DOTFILES_DIR/lib/30-prompt.sh"

# --- Per-machine overrides (git-ignored) --------------------------------------
[[ -r "$DOTFILES_DIR/.local.sh" ]] && source "$DOTFILES_DIR/.local.sh"
[[ -r "$HOME/.bash_profile.local" ]] && source "$HOME/.bash_profile.local"

unset -f _dotfiles_require

if [[ -n "$DOTFILES_PROFILE" ]]; then
  set +x
fi
