# claude-setup

Personal Claude Code harness setup. Clone on any new machine, run the setup, get the full system.

**Read [WHAT_IS_THIS.md](WHAT_IS_THIS.md) first** if you want to understand what an AI harness is and why this exists.

---

## Quick Start

```bash
git clone git@github.com:glebo309/claude-setup.git
cd claude-setup
chmod +x setup.sh
./setup.sh
```

The setup script is interactive. It walks through three levels, running tests after each one.

---

## The Three Levels

### Level 0: Foundation

Installs the infrastructure. After this you have Claude Code running in a browser sidebar.

**What it does:**
- Installs Claude Code (if missing)
- Installs ttyd (terminal-in-browser server)
- Creates a LaunchAgent so ttyd starts on boot
- Installs sleepwatcher (for wake-triggered automations later)
- Installs terminal-notifier (for macOS notifications)
- Runs verification tests

**Result:** Open `localhost:7681` in any browser sidebar panel.

### Level 1: Core Setup

Configures Claude Code with your identity, skills, settings, and vault integration.

**What it does:**
- Copies settings.json (permissions, hooks, model, plugins, statusline)
- Copies all skills to `~/.claude/skills/`
- Sets up the statusline (model, context %, cost, git info in every prompt)
- Sets up MCP servers (Obsidian vault access, web scraping)
- Generates `~/.claude/CLAUDE.md` (global instructions)
- Sets up the Obsidian vault structure and CLAUDE.md
- Copies the notification helper script
- Runs verification tests for each component

**Result:** Claude Code knows who you are, understands your vault, and responds to custom skills.

### Level 2: Automations (Guide)

Not a script. A guide that teaches you the automation patterns so you can build your own.

**What it contains:**
- Pattern guides: on-wake, scheduled, file-watch, persistent service, chained
- Recipe examples: morning briefing, deadline scanner, inbox processor, review cycle
- Skeleton templates for LaunchAgents and scripts
- Cross-platform notes (macOS LaunchAgents vs Windows Task Scheduler)

**Result:** You understand how to make the agent work while you sleep.

---

## Repo Structure

```
claude-setup/
├── README.md                         # This file
├── WHAT_IS_THIS.md                   # AI Chat vs Agent vs Harness
├── setup.sh                          # Interactive installer
│
├── level-0/
│   ├── install-claude.sh             # Install Claude Code CLI
│   ├── install-ttyd.sh               # Install ttyd + LaunchAgent
│   ├── launchagent-ttyd.plist.tmpl   # LaunchAgent template
│   └── test-level-0.sh              # Verification tests
│
├── level-1/
│   ├── claude-md.tmpl                # Global CLAUDE.md template
│   ├── vault-claude-md.tmpl          # Vault CLAUDE.md template
│   ├── vault-ai-workflow.tmpl        # _SYSTEM/AI_WORKFLOW.md template
│   ├── vault-readme.tmpl             # _SYSTEM/README.md template
│   ├── settings.json                 # Claude Code settings
│   ├── statusline.sh                 # Status bar script
│   ├── mcp_servers.json.tmpl         # MCP server config template
│   ├── notify.sh                     # Notification helper
│   └── test-level-1.sh              # Verification tests
│
├── skills/
│   ├── paper/SKILL.md                # DOI/PDF to Zotero to vault
│   ├── pdf/SKILL.md                  # PDF to markdown
│   ├── youtube/SKILL.md              # YouTube transcript to vault
│   ├── website/SKILL.md              # Web page to vault
│   ├── process/SKILL.md              # Source material to connected notes
│   ├── export/SKILL.md               # Markdown to Word/LaTeX
│   ├── vault-sync/SKILL.md           # End-of-session vault flush
│   ├── handoff/SKILL.md              # Context window continuation
│   ├── ask/SKILL.md                  # Structured clarification
│   ├── git/SKILL.md                  # Clean git operations
│   └── daily/SKILL.md               # Interactive daily briefing
│
├── level-2/
│   ├── README.md                     # What are automations, when to add them
│   ├── patterns/
│   │   ├── on-wake.md                # Trigger on laptop open/unlock
│   │   ├── scheduled.md              # Trigger at specific times
│   │   ├── file-watch.md             # Trigger on file changes
│   │   ├── persistent-service.md     # Always-running background process
│   │   └── chained.md               # One automation calls another
│   ├── recipes/
│   │   ├── morning-briefing.md       # Wake > scan vault > journal entry
│   │   ├── deadline-scanner.md       # 3x/day > grep tags > notify
│   │   ├── inbox-processor.md        # Weekly > classify > file notes
│   │   ├── review-cycle.md           # Weekly/monthly retrospective
│   │   └── notification-helper.md    # macOS/Windows notifications + email
│   └── templates/
│       ├── launchagent.plist.tmpl    # Generic macOS LaunchAgent skeleton
│       ├── task-scheduler.xml.tmpl   # Generic Windows Task Scheduler skeleton
│       └── automation-script.sh.tmpl # Skeleton bash script with logging
│
└── vault-template/
    ├── _SYSTEM/
    │   └── .gitkeep
    ├── _RESEARCH/
    │   └── .gitkeep
    ├── _CREATIVE/
    │   └── .gitkeep
    ├── _PERSONAL/
    │   └── Journal/
    │       └── .gitkeep
    └── _INBOX/
        └── .gitkeep
```

---

## Requirements

- macOS (primary target) or Windows with WSL
- Homebrew (macOS)
- Node.js (for Claude Code)
- Obsidian (with Local REST API plugin enabled)
- Git

---

## Updating

After pulling updates to this repo:

```bash
./setup.sh --level 1    # re-run just level 1 to update skills/settings
```

The setup script is idempotent. Running it again will not duplicate anything.
