# Recipe: Notification Helper

**Tokens:** ZERO (utility script, no AI)

A shared script that other automations source to send notifications. Supports macOS notifications and optional email via Resend API.

---

## What It Does

Provides a single `notify()` function that sends:
1. A macOS notification via `terminal-notifier` (short, immediate)
2. An email via Resend API (optional, for when you're away from the laptop)

---

## The Script

See `level-1/notify.sh` in this repo. It's installed to `~/.claude/scripts/notify.sh` during Level 1 setup.

**Usage from other scripts:**
```bash
source "$HOME/.claude/scripts/notify.sh"

# Basic notification
notify "Title" "Subtitle" "Message body"

# With custom sound
notify "Deadlines" "3 overdue" "Check DEADLINE_BRIEFING" "Sosumi"

# With custom HTML email
notify "Weekly Review" "Week 20" "Summary here" "default" "<html>...</html>"
```

---

## macOS Notification Sounds

| Sound | Use for |
|---|---|
| `default` | General notifications |
| `Glass` | Gentle reminders |
| `Sosumi` | Critical / overdue |
| `Tink` | Soft reminder (evening) |
| `Basso` | Error / failure |

---

## Email Setup (Optional)

To enable email notifications:

1. **Get a Resend API key** at [resend.com](https://resend.com) (free tier: 100 emails/day)
2. **Save the key:**
   ```bash
   echo "re_your_api_key_here" > ~/.claude/.resend-key
   chmod 600 ~/.claude/.resend-key
   ```
3. **Set your email** in `notify.sh`: edit `NOTIFY_EMAIL`
4. **Uncomment** the email section in `notify.sh`

---

## Windows Equivalent

On Windows, replace `terminal-notifier` with BurntToast:

```powershell
# Install
Install-Module -Name BurntToast

# Usage
New-BurntToastNotification -Text "Title", "Message body" -Sound "Alarm"
```

For email, the Resend API call works the same via PowerShell's `Invoke-RestMethod`.

---

## Tips

- Always make notifications optional. Use a `--quiet` flag in your automation scripts to suppress notifications during file-watch triggers.
- Keep notification messages short. The detail should be in the vault file, not the notification.
- Sound selection matters. If every notification uses "Sosumi", you'll learn to ignore the critical ones.
