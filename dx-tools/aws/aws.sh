# shellcheck shell=bash
# AWS CLI setup. Helper functions live in aws-helpers.sh (in this dir).

# Interactive auto-prompt was enabled in the old config; it slows down every
# `aws` invocation. Leave OFF by default — enable per-session with:
#     export AWS_CLI_AUTO_PROMPT=on
# export AWS_CLI_AUTO_PROMPT=on

# Load helper functions (pure function definitions — cheap).
_aws_dir="$(dirname "${BASH_SOURCE[0]}")"
if [[ -r "$_aws_dir/aws-helpers.sh" ]]; then
  # shellcheck source=/dev/null
  source "$_aws_dir/aws-helpers.sh"
fi
unset _aws_dir

# Tab completion: the AWS CLI ships `aws_completer`. Register only if present,
# and do it WITHOUT spawning a subshell (the old `$(which aws_completer)`
# forked at every shell startup).
if command -v aws_completer >/dev/null 2>&1; then
  complete -C aws_completer aws
fi
