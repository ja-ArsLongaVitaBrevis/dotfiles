# CLAUDE

alias claude="npx --yes @anthropic-ai/claude-code"

## Enable Bedrock integration
export CLAUDE_CODE_USE_BEDROCK=1
export AWS_REGION=us-east-1  # or your preferred region
### Recommended output token settings for Bedrock: https://docs.claude.com/en/docs/claude-code/amazon-bedrock#5-output-token-configuration
export CLAUDE_CODE_MAX_OUTPUT_TOKENS=4096
export MAX_THINKING_TOKENS=1024
# ### Optional: Override the region for the small/fast model (Haiku)
# export ANTHROPIC_SMALL_FAST_MODEL_AWS_REGION=us-west-2
# ### Optional: Disable prompt caching if needed
# export DISABLE_PROMPT_CACHING=1

### TO CUSTOMIZE MODELS: https://docs.claude.com/en/docs/claude-code/amazon-bedrock#4-model-configuration
# #### Using inference profile ID
# export ANTHROPIC_MODEL='global.anthropic.claude-sonnet-4-5-20250929-v1:0'
# export ANTHROPIC_SMALL_FAST_MODEL='us.anthropic.claude-3-5-haiku-20241022-v1:0'
# #### Using application inference profile ARN
# export ANTHROPIC_MODEL='arn:aws:bedrock:us-east-2:your-account-id:application-inference-profile/your-model-id'

