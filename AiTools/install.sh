#!/bin/bash
# AiTools/install.sh - Install common AI CLI tools
# This script installs Claude Code, Gemini CLI, and other AI pair programming tools.

set -e

echo "=> Installing AI CLI Tools..."

# 1. Claude Code
# https://docs.claude.com/en/docs/claude-code/overview
if command -v claude &> /dev/null; then
  echo "Updating Claude Code CLI..."
else
  echo "Installing Claude Code CLI..."
fi
curl -fsSL https://claude.ai/install.sh | bash

# 2. Gemini CLI
# Run instantly with npx (no permanent installation required)
# Reference: https://geminicli.com/docs/get-started/installation/#run-gemini-cli
if command -v npx &> /dev/null; then
  echo "Pre-fetching Gemini CLI via npx..."
  npx --yes @google/gemini-cli --version > /dev/null || echo "⚠️ Failed to fetch Gemini CLI."
  echo "Gemini CLI is ready. You can run it anytime using the 'gemini' alias (mapped to 'npx @google/gemini-cli')."
else
  echo "⚠️ npx is not installed. Skipping Gemini CLI setup."
fi

echo "=> AI CLI tools setup complete!"
