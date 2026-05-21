#!/bin/zsh
# claude-setup: Interactive installer for the Claude Code harness
# Usage: ./setup.sh [--level 0|1|2]
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="$REPO_DIR/.setup-config"

# Colors
RED='\033[31m'; GREEN='\033[32m'; YELLOW='\033[33m'; CYAN='\033[36m'; BOLD='\033[1m'; RESET='\033[0m'

info()  { echo -e "${CYAN}[INFO]${RESET} $1"; }
ok()    { echo -e "${GREEN}[OK]${RESET} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${RESET} $1"; }
fail()  { echo -e "${RED}[FAIL]${RESET} $1"; }
header() { echo -e "\n${BOLD}${CYAN}═══ $1 ═══${RESET}\n"; }

ask() {
    local prompt="$1"
    local default="$2"
    local var_name="$3"
    if [[ -n "$default" ]]; then
        echo -en "${BOLD}$prompt${RESET} [${default}]: "
    else
        echo -en "${BOLD}$prompt${RESET}: "
    fi
    read -r answer
    answer="${answer:-$default}"
    eval "$var_name='$answer'"
}

confirm() {
    echo -en "${BOLD}$1${RESET} [Y/n]: "
    read -r answer
    [[ -z "$answer" || "$answer" =~ ^[Yy] ]]
}

# Load saved config if exists
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
        info "Loaded saved config from previous run"
    fi
}

save_config() {
    cat > "$CONFIG_FILE" << EOF
USER_NAME="$USER_NAME"
USER_ROLE="$USER_ROLE"
USER_DOMAIN="$USER_DOMAIN"
USER_EMAIL="$USER_EMAIL"
VAULT_PATH="$VAULT_PATH"
VAULT_PRESET="$VAULT_PRESET"
VAULT_DOMAINS="$VAULT_DOMAINS"
USE_ZOTERO="$USE_ZOTERO"
TTYD_PORT="$TTYD_PORT"
EOF
    ok "Config saved to $CONFIG_FILE"
}

# ═══════════════════════════════════════════
# THE INTERVIEW
# ═══════════════════════════════════════════

run_interview() {
    header "Setup Interview"
    echo "I need to know a few things before setting up. Answer each question."
    echo "Press Enter to accept defaults shown in [brackets]."
    echo ""

    # Identity
    ask "Your name" "$(whoami)" USER_NAME
    ask "Your role (e.g. PhD student, software engineer, writer)" "" USER_ROLE

    while [[ -z "$USER_ROLE" ]]; do
        warn "Role cannot be empty. This helps Claude tailor its responses."
        ask "Your role" "" USER_ROLE
    done

    ask "Your domain/field (e.g. biocatalysis, web dev, journalism)" "" USER_DOMAIN

    while [[ -z "$USER_DOMAIN" ]]; do
        warn "Domain cannot be empty. What area do you work in?"
        ask "Your domain/field" "" USER_DOMAIN
    done

    ask "Email for notifications (optional, press Enter to skip)" "" USER_EMAIL

    # Vault
    echo ""
    info "The vault is your Obsidian knowledge base. Claude reads and writes to it."
    ask "Obsidian vault path" "$HOME/Documents/SecondBrain" VAULT_PATH
    VAULT_PATH="${VAULT_PATH/#\~/$HOME}"

    if [[ ! -d "$VAULT_PATH" ]]; then
        if confirm "Vault directory does not exist. Create it?"; then
            mkdir -p "$VAULT_PATH"
            ok "Created $VAULT_PATH"
        else
            fail "Cannot continue without a vault path."
            exit 1
        fi
    fi

    # Vault structure
    echo ""
    info "Choose your vault's top-level folder structure."
    info "_INBOX/ (quick capture) and _SYSTEM/ (infrastructure) are always included."
    echo ""
    echo "  1) Academic     _RESEARCH/  _CREATIVE/  _PERSONAL/"
    echo "  2) Simple       _PERSONAL/  _WORK/"
    echo "  3) Custom       You pick the folder names"
    echo ""
    ask "Structure preset" "2" VAULT_PRESET

    case "$VAULT_PRESET" in
        1)
            VAULT_DOMAINS="_RESEARCH:Research, papers, lab work, academic career:Science or work-related;_CREATIVE:Creative projects, writing, published output:Created for others to see;_PERSONAL:Personal life, journal, goals, health:Private life"
            ;;
        2)
            VAULT_DOMAINS="_PERSONAL:Personal life, journal, goals, hobbies:Private, not work-related;_WORK:Work projects, notes, professional development:Work-related"
            ;;
        3)
            VAULT_DOMAINS=""
            info "Enter folder names. We add the _ prefix automatically. Empty line to finish."
            while true; do
                echo -en "${BOLD}Folder name (or Enter to finish)${RESET}: "
                read -r fname
                [[ -z "$fname" ]] && break
                fname="_$(echo "${fname#_}" | tr '[:lower:]' '[:upper:]')"
                echo -en "${BOLD}  Short purpose${RESET}: "
                read -r fpurpose
                [[ -n "$VAULT_DOMAINS" ]] && VAULT_DOMAINS="${VAULT_DOMAINS};"
                VAULT_DOMAINS="${VAULT_DOMAINS}${fname}:${fpurpose}:${fpurpose}"
            done
            if [[ -z "$VAULT_DOMAINS" ]]; then
                warn "No folders entered. Using Simple preset."
                VAULT_DOMAINS="_PERSONAL:Personal life, journal, goals, hobbies:Private, not work-related;_WORK:Work projects, notes, professional development:Work-related"
            fi
            ;;
        *)
            warn "Unknown preset. Using Simple."
            VAULT_PRESET="2"
            VAULT_DOMAINS="_PERSONAL:Personal life, journal, goals, hobbies:Private, not work-related;_WORK:Work projects, notes, professional development:Work-related"
            ;;
    esac

    # Zotero
    echo ""
    if confirm "Do you use Zotero for reference management?"; then
        USE_ZOTERO="yes"
        info "The paper skill will include Zotero integration."
    else
        USE_ZOTERO="no"
        info "Skipping Zotero. The paper skill will work without it."
    fi

    # Projects
    echo ""
    info "List your code projects so Claude knows where they live."
    info "Enter each as 'Name:Path' (e.g. 'MyApp:~/Projects/MyApp'). Empty line to finish."
    PROJECTS=()
    while true; do
        echo -en "${BOLD}Project (name:path, or Enter to finish)${RESET}: "
        read -r proj
        [[ -z "$proj" ]] && break
        PROJECTS+=("$proj")
    done

    # Terminal
    echo ""
    ask "ttyd port (for browser sidebar terminal)" "7681" TTYD_PORT

    # Summary
    header "Configuration Summary"
    echo "  Name:     $USER_NAME"
    echo "  Role:     $USER_ROLE"
    echo "  Domain:   $USER_DOMAIN"
    echo "  Email:    ${USER_EMAIL:-none}"
    echo "  Vault:    $VAULT_PATH"
    echo "  Structure: preset $VAULT_PRESET"
    IFS=';' read -rA _sum_domains <<< "$VAULT_DOMAINS"
    for _d in "${_sum_domains[@]}"; do echo "             ${_d%%:*}/"; done
    echo "  Zotero:   $USE_ZOTERO"
    echo "  Projects: ${#PROJECTS[@]} registered"
    for p in "${PROJECTS[@]:-}"; do
        [[ -n "$p" ]] && echo "            $p"
    done
    echo "  ttyd:     localhost:$TTYD_PORT"
    echo ""

    if ! confirm "Does this look right?"; then
        warn "Run setup.sh again to redo the interview."
        exit 0
    fi

    save_config
}

# ═══════════════════════════════════════════
# LEVEL 0: Foundation
# ═══════════════════════════════════════════

run_level_0() {
    header "Level 0: Foundation"

    # Claude Code
    if command -v claude &>/dev/null; then
        ok "Claude Code already installed: $(which claude)"
    else
        info "Installing Claude Code..."
        bash "$REPO_DIR/level-0/install-claude.sh"
    fi

    # ttyd
    if command -v ttyd &>/dev/null; then
        ok "ttyd already installed: $(which ttyd)"
    else
        info "Installing ttyd..."
        bash "$REPO_DIR/level-0/install-ttyd.sh"
    fi

    # sleepwatcher (for wake triggers in Level 2)
    if command -v sleepwatcher &>/dev/null; then
        ok "sleepwatcher already installed"
    else
        info "Installing sleepwatcher (for wake-triggered automations)..."
        brew install sleepwatcher
        brew services start sleepwatcher
        ok "sleepwatcher installed and started"
    fi

    # terminal-notifier
    if command -v terminal-notifier &>/dev/null; then
        ok "terminal-notifier already installed"
    else
        info "Installing terminal-notifier..."
        brew install terminal-notifier
        ok "terminal-notifier installed"
    fi

    # LaunchAgent for ttyd
    local PLIST_NAME="com.$(whoami).ttyd-claude"
    local PLIST_PATH="$HOME/Library/LaunchAgents/${PLIST_NAME}.plist"
    local CLAUDE_BIN
    CLAUDE_BIN="$(which claude)"
    local TTYD_BIN
    TTYD_BIN="$(which ttyd)"

    if [[ -f "$PLIST_PATH" ]]; then
        ok "ttyd LaunchAgent already exists"
    else
        info "Creating ttyd LaunchAgent on port $TTYD_PORT..."
        sed -e "s|__LABEL__|${PLIST_NAME}|g" \
            -e "s|__TTYD_BIN__|${TTYD_BIN}|g" \
            -e "s|__PORT__|${TTYD_PORT}|g" \
            -e "s|__CLAUDE_BIN__|${CLAUDE_BIN}|g" \
            "$REPO_DIR/level-0/launchagent-ttyd.plist.tmpl" > "$PLIST_PATH"

        launchctl load "$PLIST_PATH" 2>/dev/null || true
        ok "ttyd LaunchAgent created and loaded"
    fi

    # Run tests
    echo ""
    info "Running Level 0 tests..."
    bash "$REPO_DIR/level-0/test-level-0.sh" "$TTYD_PORT"
}

# ═══════════════════════════════════════════
# Skill dependency installer
# ═══════════════════════════════════════════

install_skill_deps() {
    header "Installing Skill Dependencies"

    # yt-dlp (youtube skill)
    if command -v yt-dlp &>/dev/null; then
        ok "yt-dlp already installed"
    else
        info "Installing yt-dlp (for YouTube transcripts)..."
        brew install yt-dlp
        ok "yt-dlp installed"
    fi

    # pymupdf (pdf skill)
    if python3 -c "import pymupdf" 2>/dev/null; then
        ok "pymupdf already installed"
    else
        info "Installing pymupdf (for PDF to markdown)..."
        pip3 install --quiet pymupdf
        ok "pymupdf installed"
    fi

    # pandoc (export skill)
    if command -v pandoc &>/dev/null; then
        ok "pandoc already installed"
    else
        info "Installing pandoc (for Word/LaTeX export)..."
        brew install pandoc
        ok "pandoc installed"
    fi

    # webclaw (website skill)
    if command -v webclaw &>/dev/null; then
        ok "webclaw already installed"
    else
        info "Installing webclaw (for web page scraping)..."
        brew install webclaw 2>/dev/null || pip3 install --quiet webclaw
        ok "webclaw installed"
    fi

    # Zotero (paper skill) -- only if user opted in
    if [[ "${USE_ZOTERO:-no}" == "yes" ]]; then
        if command -v zotero-cli &>/dev/null; then
            ok "zotero-cli already installed"
        else
            info "Installing zotero-cli (for paper pipeline)..."
            pip3 install --quiet zotero-cli
            ok "zotero-cli installed"
        fi
        info "Make sure Zotero desktop is running with the Local REST API plugin."
    fi
}

# ═══════════════════════════════════════════
# LEVEL 1: Core Setup
# ═══════════════════════════════════════════

run_level_1() {
    header "Level 1: Core Setup"

    local CLAUDE_DIR="$HOME/.claude"
    mkdir -p "$CLAUDE_DIR/skills" "$CLAUDE_DIR/scripts"

    # --- Settings ---
    if [[ -f "$CLAUDE_DIR/settings.json" ]]; then
        if confirm "settings.json already exists. Overwrite?"; then
            cp "$REPO_DIR/level-1/settings.json" "$CLAUDE_DIR/settings.json"
            ok "settings.json installed"
        else
            warn "Skipping settings.json"
        fi
    else
        cp "$REPO_DIR/level-1/settings.json" "$CLAUDE_DIR/settings.json"
        ok "settings.json installed"
    fi

    # --- Statusline ---
    cp "$REPO_DIR/level-1/statusline.sh" "$CLAUDE_DIR/statusline.sh"
    chmod +x "$CLAUDE_DIR/statusline.sh"
    ok "statusline.sh installed"

    # --- Notification helper ---
    local NOTIFY_DEST="$CLAUDE_DIR/scripts/notify.sh"
    sed -e "s|__EMAIL__|${USER_EMAIL:-}|g" \
        "$REPO_DIR/level-1/notify.sh" > "$NOTIFY_DEST"
    chmod +x "$NOTIFY_DEST"
    ok "notify.sh installed"

    # --- MCP Servers ---
    info "Setting up MCP servers (Obsidian + Webclaw)..."
    local OBSIDIAN_KEY=""
    if [[ -f "$CLAUDE_DIR/mcp_servers.json" ]]; then
        OBSIDIAN_KEY=$(python3 -c "import json; d=json.load(open('$CLAUDE_DIR/mcp_servers.json')); print(d.get('obsidian',{}).get('env',{}).get('OBSIDIAN_API_KEY',''))" 2>/dev/null || true)
    fi
    if [[ -z "$OBSIDIAN_KEY" ]]; then
        echo ""
        info "The Obsidian MCP server needs an API key."
        info "Find it in Obsidian > Settings > Community Plugins > Local REST API"
        ask "Obsidian API key" "" OBSIDIAN_KEY
    fi

    local UVX_BIN
    UVX_BIN="$(which uvx 2>/dev/null || echo "$HOME/.local/bin/uvx")"
    local WEBCLAW_BIN
    WEBCLAW_BIN="$(which webclaw-mcp 2>/dev/null || echo "/opt/homebrew/bin/webclaw-mcp")"

    sed -e "s|__UVX_BIN__|${UVX_BIN}|g" \
        -e "s|__OBSIDIAN_API_KEY__|${OBSIDIAN_KEY}|g" \
        -e "s|__WEBCLAW_BIN__|${WEBCLAW_BIN}|g" \
        "$REPO_DIR/level-1/mcp_servers.json.tmpl" > "$CLAUDE_DIR/mcp_servers.json"
    ok "mcp_servers.json installed"

    # --- Skills ---
    info "Installing skills..."
    for skill_dir in "$REPO_DIR/skills"/*/; do
        skill_name=$(basename "$skill_dir")
        dest="$CLAUDE_DIR/skills/$skill_name"
        mkdir -p "$dest"
        sed -e "s|__VAULT__|${VAULT_PATH}|g" \
            -e "s|__HOME__|${HOME}|g" \
            "$skill_dir/SKILL.md" > "$dest/SKILL.md"
        ok "  $skill_name"
    done

    # --- CLAUDE.md (global) ---
    info "Generating ~/.claude/CLAUDE.md..."
    local PROJECTS_TABLE=""
    for p in "${PROJECTS[@]:-}"; do
        if [[ -n "$p" ]]; then
            local pname="${p%%:*}"
            local ppath="${p##*:}"
            ppath="${ppath/#\~/$HOME}"
            PROJECTS_TABLE="${PROJECTS_TABLE}| ${pname} | \`${ppath}\` |\n"
        fi
    done

    sed -e "s|__USER_NAME__|${USER_NAME}|g" \
        -e "s|__USER_ROLE__|${USER_ROLE}|g" \
        -e "s|__USER_DOMAIN__|${USER_DOMAIN}|g" \
        -e "s|__VAULT_PATH__|${VAULT_PATH}|g" \
        -e "s|__PROJECTS_TABLE__|${PROJECTS_TABLE}|g" \
        "$REPO_DIR/level-1/claude-md.tmpl" > "$CLAUDE_DIR/CLAUDE.md"
    ok "CLAUDE.md generated"

    # --- Skill dependencies ---
    install_skill_deps

    # --- Vault setup ---
    info "Setting up vault structure..."
    mkdir -p "$VAULT_PATH"/{_SYSTEM,_INBOX}

    # Create domain folders from VAULT_DOMAINS (semicolon-separated, colon-delimited fields)
    IFS=';' read -rA domain_entries <<< "$VAULT_DOMAINS"
    local VAULT_DOMAIN_ROWS=""
    for entry in "${domain_entries[@]}"; do
        local dname="${entry%%:*}"
        local rest="${entry#*:}"
        local dpurpose="${rest%%:*}"
        local drule="${rest##*:}"
        mkdir -p "$VAULT_PATH/$dname"
        VAULT_DOMAIN_ROWS="${VAULT_DOMAIN_ROWS}| \`${dname}/\` | ${dpurpose} | ${drule} |
"
        ok "  $dname/"
    done

    # Vault CLAUDE.md (use python3 for multi-line domain rows)
    python3 - "$REPO_DIR/level-1/vault-claude-md.tmpl" "$VAULT_PATH/CLAUDE.md" \
        "$USER_NAME" "$USER_ROLE" "$USER_DOMAIN" "$VAULT_PATH" "$VAULT_DOMAIN_ROWS" << 'PYEOF'
import sys
tmpl = open(sys.argv[1]).read()
replacements = {
    '__USER_NAME__': sys.argv[3],
    '__USER_ROLE__': sys.argv[4],
    '__USER_DOMAIN__': sys.argv[5],
    '__VAULT_PATH__': sys.argv[6],
    '__VAULT_DOMAIN_ROWS__': sys.argv[7],
}
for k, v in replacements.items():
    tmpl = tmpl.replace(k, v)
with open(sys.argv[2], 'w') as f:
    f.write(tmpl)
PYEOF
    ok "Vault CLAUDE.md generated"

    # _SYSTEM files
    sed -e "s|__USER_NAME__|${USER_NAME}|g" \
        -e "s|__USER_ROLE__|${USER_ROLE}|g" \
        -e "s|__USER_DOMAIN__|${USER_DOMAIN}|g" \
        -e "s|__VAULT_PATH__|${VAULT_PATH}|g" \
        "$REPO_DIR/level-1/vault-ai-workflow.tmpl" > "$VAULT_PATH/_SYSTEM/AI_WORKFLOW.md"
    ok "AI_WORKFLOW.md generated"

    cp "$REPO_DIR/level-1/vault-readme.tmpl" "$VAULT_PATH/_SYSTEM/README.md"
    ok "README.md copied"

    # --- Run tests ---
    echo ""
    info "Running Level 1 tests..."
    bash "$REPO_DIR/level-1/test-level-1.sh" "$VAULT_PATH"
}

# ═══════════════════════════════════════════
# LEVEL 2: Automations Guide
# ═══════════════════════════════════════════

run_level_2() {
    header "Level 2: Automations"

    # --- Daily Briefing ---
    echo ""
    info "The daily briefing scans your vault for #due/ deadlines, commitments,"
    info "and recent notes, then calls Claude to write a morning orientation."
    info "It fires on laptop wake (via sleepwatcher) and costs ~1 Opus call/day."
    echo ""
    if confirm "Install the daily briefing automation?"; then
        local SCRIPTS_DIR="$HOME/.claude/scripts"
        mkdir -p "$SCRIPTS_DIR" "$HOME/.claude/logs"

        # Install briefing script with vault path
        sed -e "s|__VAULT__|${VAULT_PATH}|g" \
            -e "s|__USER_NAME__|${USER_NAME}|g" \
            "$REPO_DIR/level-2/scripts/daily-briefing.sh" > "$SCRIPTS_DIR/daily-briefing.sh"
        chmod +x "$SCRIPTS_DIR/daily-briefing.sh"
        ok "daily-briefing.sh installed"

        # Install wakeup trigger
        cp "$REPO_DIR/level-2/scripts/wakeup.sh" "$HOME/.wakeup"
        chmod +x "$HOME/.wakeup"
        ok "~/.wakeup installed (sleepwatcher trigger)"

        # Install LaunchAgent (boot fallback)
        local PLIST_NAME="com.$(whoami).daily-briefing"
        local PLIST_PATH="$HOME/Library/LaunchAgents/${PLIST_NAME}.plist"
        if [[ -f "$PLIST_PATH" ]]; then
            ok "Briefing LaunchAgent already exists"
        else
            sed -e "s|__LABEL__|${PLIST_NAME}|g" \
                -e "s|__HOME__|${HOME}|g" \
                "$REPO_DIR/level-2/scripts/launchagent-briefing.plist.tmpl" > "$PLIST_PATH"
            launchctl load "$PLIST_PATH" 2>/dev/null || true
            ok "Briefing LaunchAgent created and loaded"
        fi

        # Create journal directory
        local YEAR
        YEAR=$(/bin/date +%Y)
        mkdir -p "$VAULT_PATH/_PERSONAL/Journal/$YEAR"
        ok "Journal directory ready"

        echo ""
        ok "Daily briefing installed. It will run on next laptop wake after 06:30."
        info "Use /daily in Claude Code to respond to the briefing interactively."
    else
        info "Skipping daily briefing."
    fi

    # --- Weekly Reflection ---
    echo ""
    info "The weekly reflection reads your daily journal entries and #done tags,"
    info "then asks Claude (Sonnet) to write a short retrospective every Sunday evening."
    echo ""
    if confirm "Install the weekly reflection? (runs Sundays at 20:00)"; then
        local SCRIPTS_DIR="$HOME/.claude/scripts"

        sed -e "s|__VAULT__|${VAULT_PATH}|g" \
            -e "s|__USER_NAME__|${USER_NAME}|g" \
            "$REPO_DIR/level-2/scripts/weekly-reflection.sh" > "$SCRIPTS_DIR/weekly-reflection.sh"
        chmod +x "$SCRIPTS_DIR/weekly-reflection.sh"
        ok "weekly-reflection.sh installed"

        local PLIST_NAME="com.$(whoami).weekly-reflection"
        local PLIST_PATH="$HOME/Library/LaunchAgents/${PLIST_NAME}.plist"
        if [[ -f "$PLIST_PATH" ]]; then
            ok "Weekly LaunchAgent already exists"
        else
            sed -e "s|__LABEL__|${PLIST_NAME}|g" \
                -e "s|__HOME__|${HOME}|g" \
                "$REPO_DIR/level-2/scripts/launchagent-weekly.plist.tmpl" > "$PLIST_PATH"
            launchctl load "$PLIST_PATH" 2>/dev/null || true
            ok "Weekly LaunchAgent created (Sundays at 20:00)"
        fi
    else
        info "Skipping weekly reflection."
    fi

    # --- Monthly Reflection ---
    echo ""
    info "The monthly reflection reads all weekly reflections and daily notes,"
    info "then asks Claude (Sonnet) for a higher-level summary on the 1st of each month."
    echo ""
    if confirm "Install the monthly reflection? (runs 1st of each month at 09:00)"; then
        local SCRIPTS_DIR="$HOME/.claude/scripts"

        sed -e "s|__VAULT__|${VAULT_PATH}|g" \
            -e "s|__USER_NAME__|${USER_NAME}|g" \
            "$REPO_DIR/level-2/scripts/monthly-reflection.sh" > "$SCRIPTS_DIR/monthly-reflection.sh"
        chmod +x "$SCRIPTS_DIR/monthly-reflection.sh"
        ok "monthly-reflection.sh installed"

        local PLIST_NAME="com.$(whoami).monthly-reflection"
        local PLIST_PATH="$HOME/Library/LaunchAgents/${PLIST_NAME}.plist"
        if [[ -f "$PLIST_PATH" ]]; then
            ok "Monthly LaunchAgent already exists"
        else
            sed -e "s|__LABEL__|${PLIST_NAME}|g" \
                -e "s|__HOME__|${HOME}|g" \
                "$REPO_DIR/level-2/scripts/launchagent-monthly.plist.tmpl" > "$PLIST_PATH"
            launchctl load "$PLIST_PATH" 2>/dev/null || true
            ok "Monthly LaunchAgent created (1st of month at 09:00)"
        fi
    else
        info "Skipping monthly reflection."
    fi

    # --- Guide for other automations ---
    echo ""
    header "Other Automations"
    echo "The following guides teach you additional automation patterns:"
    echo ""
    echo "  Concepts:"
    echo "    level-2/README.md                        Overview"
    echo "    level-2/patterns/on-wake.md              Trigger on laptop open"
    echo "    level-2/patterns/scheduled.md            Trigger at specific times"
    echo "    level-2/patterns/file-watch.md           Trigger on file changes"
    echo "    level-2/patterns/persistent-service.md   Always-on background service"
    echo "    level-2/patterns/chained.md              One automation calls another"
    echo ""
    echo "  Recipes:"
    echo "    level-2/recipes/deadline-scanner.md      Tag-based deadline tracking"
    echo "    level-2/recipes/inbox-processor.md       Weekly AI-powered filing"
    echo "    level-2/recipes/review-cycle.md          Weekly/monthly retrospectives"
    echo "    level-2/recipes/notification-helper.md   macOS + email notifications"
    echo ""
    echo "  Templates:"
    echo "    level-2/templates/launchagent.plist.tmpl      macOS skeleton"
    echo "    level-2/templates/task-scheduler.xml.tmpl     Windows skeleton"
    echo "    level-2/templates/automation-script.sh.tmpl   Script skeleton"
    echo ""
    echo "Read these when you are ready, then tell Claude what you want to automate."
}

# ═══════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════

main() {
    echo ""
    echo -e "${BOLD}${CYAN}╔═══════════════════════════════════════╗${RESET}"
    echo -e "${BOLD}${CYAN}║       Claude Code Harness Setup       ║${RESET}"
    echo -e "${BOLD}${CYAN}╚═══════════════════════════════════════╝${RESET}"
    echo ""
    echo "This sets up your complete AI harness: agent, vault, skills, automations."
    echo "See WHAT_IS_THIS.md for what that means."
    echo ""

    local LEVEL="${1:-all}"
    if [[ "$LEVEL" == "--level" ]]; then
        LEVEL="${2:-all}"
    fi

    load_config

    # Run interview if no saved config
    if [[ -z "${USER_NAME:-}" ]] || [[ "$LEVEL" == "all" && ! -f "$CONFIG_FILE" ]]; then
        run_interview
    else
        info "Using saved config (run setup.sh without --level to redo interview)"
    fi

    case "$LEVEL" in
        0)
            run_level_0
            ;;
        1)
            run_level_1
            ;;
        2)
            run_level_2
            ;;
        all)
            run_level_0
            run_level_1
            run_level_2
            ;;
        *)
            fail "Unknown level: $LEVEL. Use 0, 1, 2, or omit for all."
            exit 1
            ;;
    esac

    echo ""
    header "Setup Complete"
    echo "Open localhost:$TTYD_PORT in your browser sidebar to start using Claude Code."
    echo ""
}

main "$@"
