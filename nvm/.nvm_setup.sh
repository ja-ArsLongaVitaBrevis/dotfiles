function nvm_setup {
  # $BASH_SOURCE is a reference to the absolut_path of this file
  local DIR_PATH=$(dirname "$BASH_SOURCE")
  echo $DIR_PATH

  export NVM_DIR="$HOME/.nvm"
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
  [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

  ## Deep Shell Integration: https://github.com/nvm-sh/nvm#automatically-call-nvm-use
  source "${DIR_PATH}/.nvm_shell_integration.sh"
}


nvm_setup
