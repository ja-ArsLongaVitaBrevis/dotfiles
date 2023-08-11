function git_setup {
    # $BASH_SOURCE is a reference to the absolut_path of this file
    local DIR_PATH=$(dirname "$BASH_SOURCE")
    
    # Enable git tab completion
    [[ -r "/usr/local/etc/profile.d/bash_completion.sh" ]] && . "/usr/local/etc/profile.d/bash_completion.sh"
    [[ -f "${DIR_PATH}/.git-completion.bash" ]] && . ${DIR_PATH}/.git-completion.bash

    # Add `git` info to $PS1
    source "${DIR_PATH}/.git-prompt.sh"
    
    # Personal customization
    export GIT_PS1_SHOWDIRTYSTATE=1
    export GIT_PS1_SHOWSTASHSTATE=1
    export GIT_PS1_SHOWUNTRACKEDFILES=1
    export GIT_PS1_SHOWUPSTREAM='verbose' # auto | verbose
    export GIT_PS1_SHOWCOLORHINTS=1
    export GIT_PS1_STATESEPARATOR=' '
    export GIT_PS1_DESCRIBE_STYLE='descriptive'


    # Graphs
    alias lg=lg1
    alias lg1="git log --graph --abbrev-commit --decorate --format=format:'%C(bold blue)%h%C(reset) - %C(bold green)(%ar)%C(reset) %C(auto)%s%C(reset) %C(blue)- %an%C(reset)%C(auto)%d%C(reset)'"
    alias lg2="git log --graph --abbrev-commit --decorate --format=format:'%C(bold blue)%h%C(reset) - %C(bold cyan)%aD%C(reset) %C(bold green)(%ar)%C(reset)%C(auto)%d%C(reset)%n''          %C(auto)%s%C(reset) %C(blue)- %an%C(reset)'"
    alias lg3="git log --graph --abbrev-commit --decorate --format=format:'%C(bold blue)%h%C(reset) - %C(bold cyan)%aD%C(reset) %C(bold green)(%ar)%C(reset) %C(bold cyan)(committed: %cD)%C(reset) %C(auto)%d%C(reset)%n''          %C(auto)%s%C(reset)%n''          %C(blue)- %an <%ae> %C(reset) %C(blue)(committer: %cn <%ce>)%C(reset)'"
    
    # Helpers
    alias git_look_up="git log -p -S " # example: git log -p -S <string to look up>
    function git_checkout_to_tag () {
        git checkout $(git rev-list -n 1 ${1})
    }
}

git_setup