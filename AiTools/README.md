# AiTools

Shell environment for **Claude Code via Amazon Bedrock**.

> Back to → [dotfiles root](../README.md)

---

## ClaudeBedrock.sh

Source: [`ClaudeBedrock.sh`](./ClaudeBedrock.sh)  
Docs: <https://docs.claude.com/en/docs/claude-code/amazon-bedrock>

### Prerequisites

- AWS credentials configured (profile or env vars).
- Node / npx available (the module lazy-loads nvm, so just `nvm` / `node` once if first use).

### Required env vars

Uncomment these lines in `ClaudeBedrock.sh` to activate Bedrock mode:

```bash
export CLAUDE_CODE_USE_BEDROCK=1
export AWS_REGION=us-east-1          # Bedrock region; must have model access
```

Then run Claude Code:

```bash
npx --yes @anthropic-ai/claude-code
```

### Optional overrides

| Variable | Default | Purpose |
|---|---|---|
| `CLAUDE_CODE_MAX_OUTPUT_TOKENS` | provider default | Max tokens per response |
| `MAX_THINKING_TOKENS` | provider default | Budget for extended thinking |
| `ANTHROPIC_MODEL` | provider default | Override the primary model ID |
| `ANTHROPIC_SMALL_FAST_MODEL` | provider default | Override the lightweight model ID |
| `ANTHROPIC_SMALL_FAST_MODEL_AWS_REGION` | `AWS_REGION` | Region for fast model (if different) |
| `DISABLE_PROMPT_CACHING` | unset | Set to `1` to turn off prompt caching |

---

## Google Cloud Vertex AI

Auth setup for Vertex AI in a local dev environment:

```bash
gcloud auth application-default login
```

Reference: <https://cloud.google.com/docs/authentication/set-up-adc-local-dev-environment>

Quotas and system limits: <https://cloud.google.com/vertex-ai/generative-ai/docs/quotas>
