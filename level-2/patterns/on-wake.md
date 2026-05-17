# Pattern: On Wake

Fire a script when the laptop opens or the screen unlocks.

---

## When to Use

- Morning briefings that should be ready when you sit down
- Syncing state that may have changed overnight
- Any "start of day" routine

## How It Works

### macOS: sleepwatcher

sleepwatcher is a daemon that runs scripts when the Mac sleeps or wakes.

**Install:**
```bash
brew install sleepwatcher
brew services start sleepwatcher
```

**Configure:** Create `~/.wakeup` (must be executable):
```bash
#!/bin/zsh
# Runs on every laptop wake
/bin/zsh ~/.claude/scripts/your-script.sh &
```

```bash
chmod +x ~/.wakeup
```

That's it. Every time the laptop lid opens or screen unlocks, `~/.wakeup` runs.

**Guard against running too early or too often:**
```bash
#!/bin/zsh
HOUR=$(date +%H)
TODAY=$(date +%Y-%m-%d)
LOCKFILE="/tmp/wakeup-$TODAY.lock"

# Only run after 6:30 AM
if [[ "$HOUR" -lt 7 ]]; then exit 0; fi

# Only run once per day
if [[ -f "$LOCKFILE" ]]; then exit 0; fi
touch "$LOCKFILE"

/bin/zsh ~/.claude/scripts/your-script.sh &
```

### Windows: Task Scheduler

Create a task triggered by "On workstation unlock":

1. Open Task Scheduler
2. Create Task (not Basic Task)
3. Trigger: "On workstation unlock"
4. Action: Start a program
5. Program: `wsl` or `powershell`
6. Arguments: path to your script

Or via PowerShell:
```powershell
$trigger = New-ScheduledTaskTrigger -AtLogOn
$action = New-ScheduledTaskAction -Execute "wsl" -Argument "bash ~/.claude/scripts/your-script.sh"
Register-ScheduledTask -TaskName "MorningBriefing" -Trigger $trigger -Action $action
```

Windows doesn't have a direct "on unlock" trigger in the GUI, but you can use the `SessionUnlock` event:
```powershell
$trigger = Get-CimClass -Namespace root/Microsoft/Windows/TaskScheduler -ClassName MSFT_TaskSessionStateChangeTrigger
```

---

## Tips

- Always run the actual work in the background (`&`) so the wakeup script returns immediately
- Add a lockfile to prevent multiple runs per day
- Time-gate with hour checks to avoid 3 AM wake-from-sleep runs
- Log to `~/.claude/logs/` with timestamps for debugging
