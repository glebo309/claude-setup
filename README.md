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

### Level 2: Automations

Installs the daily/weekly/monthly automation loop, plus guides for building your own.

**What it installs (each optional):**
- **Daily briefing**: fires on laptop wake, scans vault for `#due/` deadlines and commitments, calls Claude to write a morning orientation into your journal
- **Weekly reflection**: runs Sunday evening, reads the week's journal entries and `#done/` items, writes a retrospective
- **Monthly reflection**: runs 1st of each month, reads all weekly reflections, writes a higher-level summary

**What it contains (guides):**
- Pattern guides: on-wake, scheduled, file-watch, persistent service, chained
- Recipe examples with templates for LaunchAgents and scripts
- Cross-platform notes (macOS LaunchAgents vs Windows Task Scheduler)

**Result:** The agent scans your vault daily, writes briefings, tracks what you finish, and reflects on your progress weekly and monthly. All in your journal folder.

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
│   ├── README.md                     # What are automations, why, and how
│   ├── scripts/
│   │   ├── daily-briefing.sh         # Morning orientation (on wake)
│   │   ├── weekly-reflection.sh      # Week retrospective (Sunday)
│   │   ├── monthly-reflection.sh     # Month summary (1st of month)
│   │   ├── wakeup.sh                 # Sleepwatcher trigger for briefing
│   │   ├── launchagent-briefing.plist.tmpl
│   │   ├── launchagent-weekly.plist.tmpl
│   │   └── launchagent-monthly.plist.tmpl
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

## Platform

**This is a macOS setup.** The scripts use `launchd`, `sleepwatcher`, `terminal-notifier`, Homebrew, and BSD `date` flags. None of this runs on Windows or Linux as-is.

If you want to run this on Windows or Linux, the concepts transfer but the plumbing does not. You will need to replace:
- LaunchAgents with Task Scheduler (Windows) or systemd timers (Linux)
- `sleepwatcher` with Task Scheduler "on workstation unlock" (Windows) or `systemd-logind` (Linux)
- `terminal-notifier` with BurntToast (Windows PowerShell) or `notify-send` (Linux)
- Homebrew with your platform's package manager
- BSD `date -v` flags with GNU `date -d`

The `level-2/templates/` folder has a Windows Task Scheduler XML skeleton to get started.

## Requirements

- macOS (Ventura or later recommended)
- Homebrew
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
