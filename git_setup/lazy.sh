# shellcheck shell=bash
# Lazy git completion — defer sourcing git-completion.bash (~71 KB) until the
# user first presses TAB after `git` or `gitk`. Same spirit as nvm/lazy.sh:
# cheap stub now, one-time load on demand, transparent re-dispatch.
#
# Why not rely on bash-completion@2 alone? bash-completion@2's dynamic loader
# scans $HOMEBREW_PREFIX/share/bash-completion/completions/. We ship our OWN
# vendored git-completion.bash in this repo (so completions are portable
# regardless of what Homebrew installed), and want it loaded on demand.

if [[ -r "${DOTFILES_DIR}/git_setup/git-completion.bash" ]]; then

  _git_lazy_completion() {
    # Remove the lazy stubs so the real completion (registered by sourcing
    # git-completion.bash) replaces them cleanly — no recursion on next TAB.
    complete -r git gitk 2>/dev/null
    unset -f _git_lazy_completion

    # shellcheck source=/dev/null
    source "${DOTFILES_DIR}/git_setup/git-completion.bash"

    # Re-dispatch THIS TAB to the freshly-registered completer. Without this,
    # bash has already committed to the stub for this TAB cycle and the user
    # would need to press TAB again to see any completions.
    case "${COMP_WORDS[0]}" in
      git)
        declare -F __git_wrap__git_main >/dev/null 2>&1 && __git_wrap__git_main
        ;;
      gitk)
        declare -F __git_wrap__gitk_main >/dev/null 2>&1 && __git_wrap__gitk_main
        ;;
    esac
  }

  complete -o bashdefault -o default -o nospace -F _git_lazy_completion git gitk
fi
