function aws_setup {
  # $BASH_SOURCE is a reference to the absolut_path of this file
  local DIR_PATH=$(dirname "$BASH_SOURCE")

  # Enable `Tab Completion` : https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-completion.html
  export PATH=$(which aws_completer):$PATH

  # Enable `Auto Propmt` : https://docs.aws.amazon.com/cli/latest/userguide/cli-usage-parameters-prompting.html
  export AWS_CLI_AUTO_PROMPT=on

  source "${DIR_PATH}/.aws-helpers.sh"
  
  # awsSetDefaults # function defined in ./.aws-helpers.sh

  ## source aws_complete (❗️ Only needed with AWS-CLI v.1)
  ### Path to `/usr/local/bin/aws_completer` have to be added to $PATH > Added directly to `/etc/paths`
  # complete -C '/usr/local/bin/aws_completer' aws
  # complete -C $(which aws_completer) aws
  ## aws helpers
}

aws_setup