# Pattern: Scheduled

Fire a script at specific times: daily, weekly, monthly, or multiple times per day.

---

## When to Use

- Deadline checks (3x/day)
- Weekly reports (Sunday evening)
- Monthly reviews (1st of the month)
- Any recurring task with a predictable cadence

## How It Works

### macOS: launchd with StartCalendarInterval

Create a `.plist` file in `~/Library/LaunchAgents/`:

**Daily at 10:00 AM:**
```xml
<key>StartCalendarInterval</key>
<dict>
    <key>Hour</key>
    <integer>10</integer>
    <key>Minute</key>
    <integer>0</integer>
</dict>
```

**Multiple times per day (7am, 12pm, 5pm):**
```xml
<key>StartCalendarInterval</key>
<array>
    <dict>
        <key>Hour</key>
        <integer>7</integer>
        <key>Minute</key>
        <integer>0</integer>
    </dict>
    <dict>
        <key>Hour</key>
        <integer>12</integer>
        <key>Minute</key>
        <integer>0</integer>
    </dict>
    <dict>
        <key>Hour</key>
        <integer>17</integer>
        <key>Minute</key>
        <integer>0</integer>
    </dict>
</array>
```

**Weekdays only (Monday=1 through Friday=5):**
```xml
<key>StartCalendarInterval</key>
<array>
    <dict>
        <key>Weekday</key>
        <integer>1</integer>
        <key>Hour</key>
        <integer>10</integer>
        <key>Minute</key>
        <integer>0</integer>
    </dict>
    <!-- repeat for days 2-5 -->
</array>
```

**Weekly (Sunday at 8 PM):**
```xml
<key>StartCalendarInterval</key>
<dict>
    <key>Weekday</key>
    <integer>0</integer>
    <key>Hour</key>
    <integer>20</integer>
    <key>Minute</key>
    <integer>0</integer>
</dict>
```

**Monthly (1st at 9 PM):**
```xml
<key>StartCalendarInterval</key>
<dict>
    <key>Day</key>
    <integer>1</integer>
    <key>Hour</key>
    <integer>21</integer>
    <key>Minute</key>
    <integer>0</integer>
</dict>
```

**Load and manage:**
```bash
# Load (activate)
launchctl load ~/Library/LaunchAgents/com.you.your-task.plist

# Unload (deactivate)
launchctl unload ~/Library/LaunchAgents/com.you.your-task.plist

# Check status
launchctl list | grep your-task

# Manual trigger (test)
launchctl start com.you.your-task
```

### Windows: Task Scheduler

```powershell
# Daily at 10:00 AM
$trigger = New-ScheduledTaskTrigger -Daily -At 10:00AM
$action = New-ScheduledTaskAction -Execute "wsl" -Argument "bash ~/.claude/scripts/your-script.sh"
Register-ScheduledTask -TaskName "DeadlineCheck" -Trigger $trigger -Action $action

# Weekly on Sunday at 8 PM
$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At 8:00PM
Register-ScheduledTask -TaskName "WeeklyReview" -Trigger $trigger -Action $action
```

---

## Important Notes

- **macOS sleep:** launchd will NOT fire if the laptop is asleep at the scheduled time. If the laptop wakes after the scheduled time, the job runs immediately (once). For critical jobs, combine with the on-wake pattern.
- **Weekday mapping (launchd):** 0=Sunday, 1=Monday, ..., 6=Saturday
- **Use the full template** from `templates/launchagent.plist.tmpl` as a starting point
