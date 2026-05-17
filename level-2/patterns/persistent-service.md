# Pattern: Persistent Service

Keep a process running in the background at all times. If it crashes, restart it automatically.

---

## When to Use

- The ttyd terminal server (browser sidebar)
- A local API server
- Any daemon that should always be available

## How It Works

### macOS: launchd KeepAlive

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.you.your-service</string>
    <key>ProgramArguments</key>
    <array>
        <string>/path/to/binary</string>
        <string>--flag</string>
        <string>value</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/your-service.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/your-service.err</string>
</dict>
</plist>
```

**Key fields:**
- `RunAtLoad: true` -- start when the plist is loaded (login)
- `KeepAlive: true` -- restart if the process exits

**Manage:**
```bash
# Start
launchctl load ~/Library/LaunchAgents/com.you.your-service.plist

# Stop
launchctl unload ~/Library/LaunchAgents/com.you.your-service.plist

# Check if running
launchctl list | grep your-service

# View logs
tail -f /tmp/your-service.log
```

### Windows: nssm (Non-Sucking Service Manager)

nssm wraps any executable as a Windows Service.

```powershell
# Install nssm
scoop install nssm
# or: choco install nssm

# Register the service
nssm install YourService "C:\path\to\binary.exe" "--flag value"
nssm set YourService AppStdout "C:\tmp\your-service.log"
nssm set YourService AppStderr "C:\tmp\your-service.err"

# Start
nssm start YourService

# Stop
nssm stop YourService

# Remove
nssm remove YourService confirm
```

**Alternative:** Task Scheduler with "Run whether user is logged on or not" and "Restart if task fails" settings.

---

## Tips

- Always set log paths. Persistent services that fail silently are impossible to debug.
- KeepAlive restarts immediately on exit, which can cause tight crash loops. If your service is crashing, check the error log before reloading.
- For services that bind to a port, check if the port is already in use before starting: `lsof -i :PORT`
