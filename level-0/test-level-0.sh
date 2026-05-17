#!/bin/zsh
# Level 0 verification tests
set -uo pipefail

PORT="${1:-7681}"
PASS=0; FAIL=0

test_it() {
    local name="$1"
    local result="$2"
    if [[ "$result" == "0" ]]; then
        echo -e "\033[32m  PASS\033[0m $name"
        ((PASS++))
    else
        echo -e "\033[31m  FAIL\033[0m $name"
        ((FAIL++))
    fi
}

echo "Running Level 0 tests..."
echo ""

# Claude Code installed
command -v claude &>/dev/null
test_it "Claude Code is installed" "$?"

# ttyd installed
command -v ttyd &>/dev/null
test_it "ttyd is installed" "$?"

# sleepwatcher installed
command -v sleepwatcher &>/dev/null
test_it "sleepwatcher is installed" "$?"

# terminal-notifier installed
command -v terminal-notifier &>/dev/null
test_it "terminal-notifier is installed" "$?"

# LaunchAgent exists
PLIST="$HOME/Library/LaunchAgents/com.$(whoami).ttyd-claude.plist"
[[ -f "$PLIST" ]]
test_it "ttyd LaunchAgent exists" "$?"

# ttyd responds on port
curl -s -o /dev/null -w "%{http_code}" "http://localhost:$PORT" 2>/dev/null | grep -q "200"
test_it "ttyd responds on localhost:$PORT" "$?"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]] && echo -e "\033[32mLevel 0 complete.\033[0m" || echo -e "\033[33mSome tests failed. Check the output above.\033[0m"
