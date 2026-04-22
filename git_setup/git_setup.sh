# shellcheck shell=bash
# Git aliases + helper functions. NOTE: git-prompt.sh (for PS1) is sourced
# from lib/30-prompt.sh. The big git-completion.bash is NOT sourced here —
# bash-completion@2 (loaded in lib/10-brew.sh) loads it lazily on first TAB.

# Pretty log graphs
alias lg='lg1'
alias lg1="git log --graph --abbrev-commit --decorate --format=format:'%C(bold blue)%h%C(reset) - %C(bold green)(%ar)%C(reset) %C(auto)%s%C(reset) %C(blue)- %an%C(reset)%C(auto)%d%C(reset)'"
alias lg2="git log --graph --abbrev-commit --decorate --format=format:'%C(bold blue)%h%C(reset) - %C(bold cyan)%aD%C(reset) %C(bold green)(%ar)%C(reset)%C(auto)%d%C(reset)%n''          %C(auto)%s%C(reset) %C(blue)- %an%C(reset)'"
alias lg3="git log --graph --abbrev-commit --decorate --format=format:'%C(bold blue)%h%C(reset) - %C(bold cyan)%aD%C(reset) %C(bold green)(%ar)%C(reset) %C(bold cyan)(committed: %cD)%C(reset) %C(auto)%d%C(reset)%n''          %C(auto)%s%C(reset)%n''          %C(blue)- %an <%ae> %C(reset) %C(blue)(committer: %cn <%ce>)%C(reset)'"

# Search history for a string (pickaxe)
alias git_look_up='git log -p -S'

git_checkout_to_tag() {
  if [[ -z "$1" ]]; then
    echo "[ERROR] Usage: git_checkout_to_tag <tag>" >&2
    return 1
  fi
  git checkout "$(git rev-list -n 1 "$1")"
}

# Force-load git-completion.bash right now. Usually NOT needed — git_setup/
# lazy.sh auto-loads it on the first TAB after `git`/`gitk`. Useful for
# tooling that needs completions registered up front (e.g. completion tests,
# or scripts that inspect the completion function table).
git_completion_load() {
  local f="${DOTFILES_DIR}/git_setup/git-completion.bash"
  if [[ -r "$f" ]]; then
    # shellcheck source=/dev/null
    source "$f"
    echo "git completion loaded."
  else
    echo "[ERROR] $f not found" >&2
    return 1
  fi
}
