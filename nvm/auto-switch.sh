# shellcheck shell=bash
# Optional: auto-switch Node version via .nvmrc on `cd`.
#
# NOT enabled by default — the old eager `cd` override triggered `nvm use`
# on every directory change, which is slow. Enable per-session with:
#
#     source ~/CodeBis/jesuarva-dotfiles/nvm/auto-switch.sh
#
# Or enable always by uncommenting the line in nvm/lazy.sh.

_nvmrc_auto_switch() {
  # This runs inside a cd wrapper, so nvm is already loaded (the wrapper
  # forces load by calling `nvm` below).
  local nvm_path
  nvm_path=$(nvm_find_up .nvmrc | tr -d '\n')

  if [[ -z "$nvm_path" || ! "$nvm_path" = *[^[:space:]]* ]]; then
    local default_version
    default_version=$(nvm version default)
    if [[ "$default_version" == "N/A" ]]; then
      nvm alias default node
      default_version=$(nvm version default)
    fi
    if [[ "$(nvm current)" != "$default_version" ]]; then
      nvm use default
    fi
  elif [[ -s "$nvm_path/.nvmrc" && -r "$nvm_path/.nvmrc" ]]; then
    local nvm_version resolved
    nvm_version=$(< "$nvm_path/.nvmrc")
    resolved=$(nvm ls --no-colors "$nvm_version" | tail -1 | tr -d '\->*' | tr -d '[:space:]')
    if [[ "$resolved" == "N/A" ]]; then
      nvm install "$nvm_version"
    elif [[ "$(nvm current)" != "$resolved" ]]; then
      nvm use "$nvm_version"
    fi
  fi
}

cdnvm() {
  command cd "$@" || return $?
  # Force nvm load (cheap after first call)
  nvm --version >/dev/null 2>&1 || return 0
  _nvmrc_auto_switch
}
alias cd='cdnvm'

# NOTE: deliberately NOT bootstrapping with `cdnvm "$PWD"` here. Doing so
# forces nvm to load at shell startup (~400 ms) — defeating the lazy loader.
# If you open a terminal inside a project with a .nvmrc, the version switch
# happens on your first `cd` (even `cd .`). If you want startup-time
# switching regardless of cost, add `cdnvm "$PWD"` to ~/.bash_profile.local.
