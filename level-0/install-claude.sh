#!/bin/zsh
# Install Claude Code CLI
set -euo pipefail

if command -v claude &>/dev/null; then
    echo "Claude Code already installed: $(claude --version)"
    exit 0
fi

if ! command -v npm &>/dev/null; then
    echo "npm not found. Install Node.js first:"
    echo "  brew install node"
    exit 1
fi

npm install -g @anthropic-ai/claude-code
echo "Claude Code installed: $(claude --version)"
