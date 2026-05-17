# Pattern: File Watch

Fire a script when files in a directory change.

---

## When to Use

- Regenerate a summary when vault notes are edited
- Recompile or rebuild when source files change
- Sync a surface file when its canonical source is updated
- Any reactive automation that should respond to edits

## How It Works

### macOS: launchd WatchPaths

launchd can watch directories and fire when any file inside changes.

```xml
<key>WatchPaths</key>
<array>
    <string>/Users/you/Documents/SecondBrain/_RESEARCH</string>
    <string>/Users/you/Documents/SecondBrain/_CREATIVE</string>
    <string>/Users/you/Documents/SecondBrain/_PERSONAL</string>
    <string>/Users/you/Documents/SecondBrain/_INBOX</string>
</array>
```

**Throttling:** launchd fires at most once per change, but rapid saves can trigger rapid fires. Add a throttle to your script:

```bash
#!/bin/zsh
LOCKFILE="/tmp/file-watch.lock"
THROTTLE=120  # seconds

if [[ -f "$LOCKFILE" ]]; then
    LAST=$(stat -f %m "$LOCKFILE")
    NOW=$(date +%s)
    if (( NOW - LAST < THROTTLE )); then
        exit 0
    fi
fi

touch "$LOCKFILE"

# Your actual work here
```

**Full plist example:**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.you.vault-watcher</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/zsh</string>
        <string>/Users/you/.claude/scripts/your-watcher.sh</string>
    </array>
    <key>WatchPaths</key>
    <array>
        <string>/Users/you/Documents/SecondBrain/_RESEARCH</string>
    </array>
    <key>ThrottleInterval</key>
    <integer>120</integer>
    <key>StandardOutPath</key>
    <string>/tmp/vault-watcher.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/vault-watcher.err</string>
</dict>
</plist>
```

### Windows: FileSystemWatcher (PowerShell)

```powershell
$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path = "C:\Users\you\Documents\SecondBrain\_RESEARCH"
$watcher.Filter = "*.md"
$watcher.IncludeSubdirectories = $true
$watcher.EnableRaisingEvents = $true

$action = {
    # Your work here
    & wsl bash ~/.claude/scripts/your-watcher.sh
}

Register-ObjectEvent $watcher "Changed" -Action $action
Register-ObjectEvent $watcher "Created" -Action $action

# Keep script running
while ($true) { Start-Sleep -Seconds 5 }
```

Save as a `.ps1` script and run it via Task Scheduler at logon with the "persistent service" pattern.

---

## Tips

- Always throttle. Obsidian saves often (auto-save, sync) and you don't want to fire 50 times a minute.
- Use `--quiet` flags for watcher-triggered runs (no notifications, just update files silently).
- WatchPaths watches the directory, not individual files. Any change in the directory (create, modify, delete) triggers the job.
- For watching a single file, put just that file's path in WatchPaths.
