# Recipe: Morning Briefing

**Pattern:** on-wake | **Tokens:** HIGH (one Opus call per day)

A script that fires when you open your laptop, scans your vault for deadlines and commitments, then uses Claude to write a concise morning orientation into today's journal note.

---

## How It Works

### Phase 0: Data Gathering (zero tokens)

The script scans your vault with `grep` and `git log`. No API calls.

1. **Deadlines**: finds all `#due/YYYY-MM-DD` tags, groups by urgency
   - **[LOUD]**: within 3 days AND no recent git activity on the file (you haven't touched it)
   - **[RECURRING]**: appeared as overdue in 3+ consecutive briefings (stuck item)
   - **[DEADLINE]**: normal upcoming deadline
2. **Commitments**: scans recent journal entries and _INBOX for orphaned action items ("need to", "TODO", "will", etc.)
3. **Recent notes**: reads the `*Notes:*` sections from the last 5 days of journal entries (your own words, authoritative over everything else)
4. **Deduplication**: removes duplicate deadlines, upgrades LOUD to RECURRING when appropriate

### Phase 1: Claude Call (spends tokens)

All gathered data is sent to Claude in a single prompt. Claude writes a 5-7 line morning orientation:
- [LOUD] items first, in imperative tone ("what is blocking this?")
- [RECURRING] items get one concrete suggestion or get parked
- Normal deadlines with "so what" for today
- Quiet days get "nothing pressing" plus one low-stakes suggestion

### Output

- Creates `_PERSONAL/Journal/YYYY/YYYY-MM-DD.md` with YAML frontmatter, briefing narrative, and deadlines section
- Copies to `Daily Briefing.md` at vault root for quick access
- Git commits the journal entry
- Sends a macOS notification

---

## The #due/#done Tag System

This is how tasks flow through the vault:

```
Write a task anywhere:     - [ ] Submit report #due/2026-06-15
Briefing picks it up:      [DEADLINE] IN 3d: Submit report (from [[ProjectPlan]])
User says it's done:       /daily report is submitted
Claude updates the source: - [x] Submit report #done/2026-06-15
Tomorrow ignores it:       (lines with #done/ are filtered out)
```

No special file format. No project management tool. Write `#due/YYYY-MM-DD` on any line in any `.md` file and the briefing finds it.

---

## Installation

The setup script installs this automatically when you choose Level 2:

```bash
./setup.sh --level 2
```

This installs:
- `~/.claude/scripts/daily-briefing.sh` (the main script)
- `~/.wakeup` (sleepwatcher trigger)
- A LaunchAgent as boot fallback

### Manual trigger

```bash
bash ~/.claude/scripts/daily-briefing.sh
```

The script is idempotent. Running it twice on the same day does nothing.

---

## Responding to the Briefing

Use the `/daily` skill in Claude Code:

```
/daily                              # show briefing summary, ask for input
/daily report done, finished it     # tick off a task
/daily idea: try the new approach   # log a thought
/daily skip the review for now      # defer something
```

Claude finds the matching `#due/` tag in the source file, changes it to `#done/`, ticks the checkbox, and logs it in the journal.

---

## Customization

The script at `~/.claude/scripts/daily-briefing.sh` is plain bash + python. Modify freely:

- **Change wake-up time**: edit the hour guard at the top (default: 06:30)
- **Change Claude model**: replace `--model opus` with `--model sonnet` to save tokens
- **Add weekend mode**: the script already detects weekends and sends a different prompt
- **Chain another script**: add a call after the briefing (e.g., daily quote, RSS digest)
- **Adjust lookahead**: deadlines scan 14 days ahead by default; change in the Python section
