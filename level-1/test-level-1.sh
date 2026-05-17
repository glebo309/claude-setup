#!/bin/zsh
# Level 1 verification tests
set -uo pipefail

VAULT="${1:-$HOME/Documents/SecondBrain}"
CLAUDE_DIR="$HOME/.claude"
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

echo "Running Level 1 tests..."
echo ""

# Settings
[[ -f "$CLAUDE_DIR/settings.json" ]]
test_it "settings.json exists" "$?"

# Statusline
[[ -x "$CLAUDE_DIR/statusline.sh" ]]
test_it "statusline.sh exists and is executable" "$?"

# MCP servers
[[ -f "$CLAUDE_DIR/mcp_servers.json" ]]
test_it "mcp_servers.json exists" "$?"

# Check MCP has a real API key (not placeholder)
python3 -c "import json; d=json.load(open('$CLAUDE_DIR/mcp_servers.json')); k=d['obsidian']['env']['OBSIDIAN_API_KEY']; assert k and '__' not in k" 2>/dev/null
test_it "Obsidian API key is set (not placeholder)" "$?"

# CLAUDE.md
[[ -f "$CLAUDE_DIR/CLAUDE.md" ]]
test_it "~/.claude/CLAUDE.md exists" "$?"

# Check CLAUDE.md has no placeholders
! grep -q '__.*__' "$CLAUDE_DIR/CLAUDE.md" 2>/dev/null
test_it "CLAUDE.md has no remaining placeholders" "$?"

# Skills
EXPECTED_SKILLS=(paper pdf youtube website process export vault-sync handoff ask git daily)
for skill in "${EXPECTED_SKILLS[@]}"; do
    [[ -f "$CLAUDE_DIR/skills/$skill/SKILL.md" ]]
    test_it "Skill: $skill" "$?"
done

# Check skills have no placeholders
! grep -rq '__VAULT__\|__HOME__' "$CLAUDE_DIR/skills/" 2>/dev/null
test_it "Skills have no remaining placeholders" "$?"

# Notify script
[[ -f "$CLAUDE_DIR/scripts/notify.sh" ]]
test_it "notify.sh exists" "$?"

# Vault structure
[[ -d "$VAULT/_SYSTEM" ]]
test_it "Vault: _SYSTEM/ exists" "$?"

[[ -d "$VAULT/_RESEARCH" ]]
test_it "Vault: _RESEARCH/ exists" "$?"

[[ -d "$VAULT/_CREATIVE" ]]
test_it "Vault: _CREATIVE/ exists" "$?"

[[ -d "$VAULT/_PERSONAL" ]]
test_it "Vault: _PERSONAL/ exists" "$?"

[[ -d "$VAULT/_INBOX" ]]
test_it "Vault: _INBOX/ exists" "$?"

[[ -f "$VAULT/CLAUDE.md" ]]
test_it "Vault CLAUDE.md exists" "$?"

[[ -f "$VAULT/_SYSTEM/AI_WORKFLOW.md" ]]
test_it "AI_WORKFLOW.md exists" "$?"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]] && echo -e "\033[32mLevel 1 complete.\033[0m" || echo -e "\033[33mSome tests failed. Check the output above.\033[0m"
