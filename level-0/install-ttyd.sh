#!/bin/zsh
# Install ttyd (terminal-in-browser)
set -euo pipefail

if command -v ttyd &>/dev/null; then
    echo "ttyd already installed: $(which ttyd)"
    exit 0
fi

if ! command -v brew &>/dev/null; then
    echo "Homebrew not found. Install it first:"
    echo '  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
    exit 1
fi

brew install ttyd
echo "ttyd installed: $(which ttyd)"
