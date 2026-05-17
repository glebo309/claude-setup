# Level 2: Automations

Automations make the harness work while you are not at the keyboard. They scan your vault, generate briefings, send notifications, and file notes on a schedule.

**Do not start here.** Get comfortable with Level 0 (terminal in browser) and Level 1 (skills, vault, CLAUDE.md) first. Automations build on top of a working harness.

---

## What Is an Automation?

An automation has four parts:

1. **Trigger** -- what starts it (time, event, file change)
2. **Script** -- what it does (bash script, possibly calling Claude)
3. **Output** -- where the result goes (vault file, notification, email, git commit)
4. **Log** -- proof it ran (timestamped log file)

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
