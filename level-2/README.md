# Level 2: Automations

**Do not start here.** Get comfortable with Level 0 (terminal in browser) and Level 1 (skills, vault, CLAUDE.md) first. Automations build on top of a working harness.

---

## Why Automations?

Without automations, the AI harness only works when you are sitting at the keyboard typing commands. That is already powerful, but it means:
- You have to remember to check your deadlines
- You have to remember to review what happened this week
- You have to ask Claude to scan your vault every time you want a summary
- Nothing happens while you sleep, commute, or step away

Automations remove the "you have to remember" part. They turn the harness from a tool you use into a system that works alongside you.

## What Are Automations For?

Think of automations as habits you give to your AI system:

**Daily briefing** (the big one): Every morning when you open your laptop, a script scans your vault for deadlines, overdue items, and commitments. It sends all that data to Claude, which writes a 5-7 line morning orientation into your journal. By the time you have coffee, you know what needs attention today. You respond via `/daily` in the terminal: "report is done, skip the review, idea: try X instead." Claude updates the source files, ticks off tasks, and logs your notes.

**Weekly reflection**: Every Sunday evening, a script reads your week of journal entries and completed tasks, then asks Claude to write a short retrospective. What moved forward? What stalled? Was this a building week or a scattered one?

**Monthly reflection**: On the 1st of each month, a script reads all weekly reflections and writes a higher-level summary. Patterns across weeks, progress on larger goals, things that keep getting deferred.

**Deadline scanner** (zero tokens): Three times a day, a script greps for `#due/` tags and sends you a notification if anything is overdue or due today. No AI call, just pattern matching and a notification.

**Inbox processor** (weekly): Every Monday, Claude reads unprocessed notes in `_INBOX/` and suggests where to file them.

The first three (daily, weekly, monthly) are installed by the setup script. The rest are guides you can build yourself.

---

## What Is an Automation?

An automation has four parts:

1. **Trigger**: what starts it (time of day, laptop wake, file change)
2. **Script**: what it does (a bash script that may call Claude)
3. **Output**: where the result goes (vault file, notification, git commit)
4. **Log**: proof it ran (timestamped log file in `~/.claude/logs/`)

Some automations cost zero tokens (they just grep files and send notifications). Others spend tokens by calling Claude to synthesize or analyze.

---

## The Five Patterns

Each automation uses one of these trigger patterns. Read the pattern guides in `patterns/` for full details with templates.

| Pattern | Trigger | Example | Guide |
|---|---|---|---|
| **On wake** | Laptop opens / screen unlocks | Morning briefing | [on-wake.md](patterns/on-wake.md) |
| **Scheduled** | Specific time (daily, weekly, monthly) | Deadline check at noon | [scheduled.md](patterns/scheduled.md) |
| **File watch** | A file in a watched directory changes | Regenerate summary on edit | [file-watch.md](patterns/file-watch.md) |
| **Persistent service** | Always running in background | ttyd terminal server | [persistent-service.md](patterns/persistent-service.md) |
| **Chained** | One automation triggers another | Briefing calls daily lesson | [chained.md](patterns/chained.md) |

---

## Token Cost Awareness

Before building an automation, decide: does it need AI or not?

**Zero-token automations** (grep, scan, format, notify):
- Deadline scanner: grep for `#due/` tags, group by urgency, send notification
- Shipping report: grep for `#done/` tags, format a list
- File watcher: copy a file when it changes
- Website publish: git add, commit, push

**Token-spending automations** (call Claude API or Claude Code):
- Morning briefing: Claude reads your vault and writes a synthesis
- Inbox processor: Claude classifies and files notes
- Weekly review: Claude reads changes and writes a retrospective

Token-spending automations are powerful but cost money. Start with zero-token automations, add AI ones when you see the value.

---

## How to Build Your Own

1. Pick a pattern from `patterns/`
2. Pick a recipe from `recipes/` that is closest to what you want (or start from the skeleton in `templates/`)
3. Write the script
4. Create the trigger (LaunchAgent on macOS, Task Scheduler on Windows)
5. Test it manually: `bash your-script.sh`
6. Check the log
7. Let it run for a week, tune as needed

---

## Recipe Index

| Recipe | Pattern | Tokens | Guide |
|---|---|---|---|
| Morning briefing | on-wake | HIGH | [morning-briefing.md](recipes/morning-briefing.md) |
| Deadline scanner | scheduled | ZERO | [deadline-scanner.md](recipes/deadline-scanner.md) |
| Inbox processor | scheduled | HIGH | [inbox-processor.md](recipes/inbox-processor.md) |
| Review cycle | scheduled | HIGH | [review-cycle.md](recipes/review-cycle.md) |
| Notification helper | (utility) | ZERO | [notification-helper.md](recipes/notification-helper.md) |

---

## Cross-Platform Reference

| Concept | macOS | Windows |
|---|---|---|
| Background task manager | launchd (LaunchAgents) | Task Scheduler |
| Config file | .plist (XML) | .xml |
| Location | `~/Library/LaunchAgents/` | Task Scheduler Library |
| Load/unload | `launchctl load/unload` | `schtasks /create /delete` |
| Wake trigger | sleepwatcher + `~/.wakeup` | Task Scheduler "on workstation unlock" |
| File watcher | launchd `WatchPaths` | `FileSystemWatcher` (PowerShell) |
| Persistent service | launchd `KeepAlive` | nssm / Windows Service |
| Notifications | terminal-notifier | BurntToast (PowerShell) |
| Log viewer | Console.app or `tail -f` | Event Viewer or `Get-Content -Wait` |
