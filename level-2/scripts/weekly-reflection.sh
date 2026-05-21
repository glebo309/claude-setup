#!/bin/zsh
# Weekly Reflection
#
# Reads the past week's daily journal entries, collects completed
# and remaining tasks, and asks Claude to write a short retrospective.
#
# Trigger: scheduled (Sunday 20:00 or Monday 07:00)
# Output: _PERSONAL/Journal/YYYY/Week-YYYY-MM-DD.md

set -euo pipefail
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$HOME/.local/bin"

CAT=/bin/cat
GIT=/usr/bin/git
PYTHON=/usr/bin/python3
CLAUDE="$HOME/.local/bin/claude"

source "$HOME/.claude/scripts/notify.sh"

VAULT="__VAULT__"
LOGDIR="$HOME/.claude/logs"
TODAY=$(/bin/date +%Y-%m-%d)
YEAR=$(/bin/date +%Y)
LOG="$LOGDIR/weekly-reflection-$TODAY.log"
JOURNAL_DIR="$VAULT/_PERSONAL/Journal/$YEAR"
OUTPUT="$JOURNAL_DIR/Week-$TODAY.md"

mkdir -p "$LOGDIR" "$JOURNAL_DIR"

log() { echo "[$(/bin/date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG"; }

# --- Idempotency ---
if [ -f "$OUTPUT" ]; then
    log "Weekly reflection already exists for this week, exiting"
    exit 0
fi

# --- Wait for network ---
NETWORK_TRIES=0
while [ $NETWORK_TRIES -lt 6 ]; do
    if /usr/bin/curl -s --max-time 5 -o /dev/null https://api.anthropic.com 2>/dev/null; then
        break
    fi
    NETWORK_TRIES=$((NETWORK_TRIES + 1))
    sleep 5
done
if [ $NETWORK_TRIES -eq 6 ]; then
    log "No network after 30s, aborting"
    exit 1
fi

TMPDIR_WORK=$(/usr/bin/mktemp -d /tmp/weekly-reflection.XXXXXX)
trap '/bin/rm -rf "$TMPDIR_WORK"' EXIT

log "Weekly reflection starting"

# ============================================================
# DATA GATHERING
# ============================================================

$PYTHON - "$VAULT" "$TODAY" "$TMPDIR_WORK" << 'PYEOF'
import os, re, sys, glob
from datetime import datetime, timedelta
from pathlib import Path

vault = sys.argv[1]
today = datetime.strptime(sys.argv[2], "%Y-%m-%d").date()
tmpdir = sys.argv[3]

# Collect daily entries from the past 7 days
journal_entries = []
for i in range(7):
    d = today - timedelta(days=i)
    year_str = str(d.year)
    journal_path = os.path.join(vault, "_PERSONAL/Journal", year_str, f"{d.isoformat()}.md")
    if os.path.isfile(journal_path):
        try:
            with open(journal_path) as f:
                journal_entries.append((d.isoformat(), f.read()))
        except Exception:
            pass

# Collect #done/ tags from the past 7 days (by git history)
import subprocess
done_items = []
result = subprocess.run(
    ["grep", "-rn", r"#done/", "--include=*.md",
     os.path.join(vault, "_PERSONAL"),
     os.path.join(vault, "_INBOX")] +
    [d for d in glob.glob(os.path.join(vault, "_*/"))
     if os.path.basename(d.rstrip("/")) not in ("_SYSTEM", "_INBOX", "_PERSONAL")],
    capture_output=True, text=True
)
cutoff = today - timedelta(days=7)
for line in result.stdout.strip().split("\n"):
    if not line.strip(): continue
    for ds in re.findall(r"#done/(\d{4}-\d{2}-\d{2})", line):
        try:
            d = datetime.strptime(ds, "%Y-%m-%d").date()
            if d >= cutoff:
                parts = line.split(":", 2)
                if len(parts) >= 3:
                    note = Path(parts[0]).stem
                    task = re.sub(r"\s*#done/\d{4}-\d{2}-\d{2}", "", parts[2].strip()).strip()
                    task = re.sub(r"^[-*]\s*\[[ x]\]\s*|^[-*]\s*", "", task).strip()
                    done_items.append(f"- {task} (from [[{note}]], done {ds})")
        except ValueError:
            continue

# Collect remaining #due/ tags (what carried over)
remaining = []
result2 = subprocess.run(
    ["grep", "-rn", r"#due/", "--include=*.md", "--exclude-dir=Journal",
     os.path.join(vault, "_PERSONAL"),
     os.path.join(vault, "_INBOX")] +
    [d for d in glob.glob(os.path.join(vault, "_*/"))
     if os.path.basename(d.rstrip("/")) not in ("_SYSTEM", "_INBOX", "_PERSONAL")],
    capture_output=True, text=True
)
for line in result2.stdout.strip().split("\n"):
    if not line.strip() or "#done/" in line: continue
    for ds in re.findall(r"#due/(\d{4}-\d{2}-\d{2})", line):
        parts = line.split(":", 2)
        if len(parts) >= 3:
            note = Path(parts[0]).stem
            task = re.sub(r"\s*#due/\d{4}-\d{2}-\d{2}", "", parts[2].strip()).strip()
            task = re.sub(r"^[-*]\s*\[[ x]\]\s*|^[-*]\s*", "", task).strip()
            remaining.append(f"- {task} (from [[{note}]], due {ds})")

# Write data files
with open(os.path.join(tmpdir, "journal_entries.md"), "w") as f:
    for date_str, content in sorted(journal_entries, key=lambda x: x[0]):
        f.write(f"## {date_str}\n\n{content}\n\n---\n\n")

with open(os.path.join(tmpdir, "done_items.md"), "w") as f:
    f.write("\n".join(done_items) if done_items else "(nothing completed this week)")

with open(os.path.join(tmpdir, "remaining.md"), "w") as f:
    f.write("\n".join(remaining) if remaining else "(no open tasks)")

print(f"Gathered: {len(journal_entries)} daily entries, {len(done_items)} done, {len(remaining)} remaining")
PYEOF

log "Data gathered"

# ============================================================
# CLAUDE CALL
# ============================================================
log "Calling Claude for reflection"

PROMPT_FILE="$TMPDIR_WORK/prompt.md"
RESPONSE_FILE="$TMPDIR_WORK/response.md"

$CAT > "$PROMPT_FILE" << PROMPTEOF
Today is $TODAY. Write a weekly reflection covering the past 7 days for __USER_NAME__.

FORMAT:
- 3-5 paragraphs, plain prose, no headers or bullets in the narrative
- Start with what actually moved forward this week (based on DONE items and journal notes)
- Then what carried over or stalled (based on REMAINING items)
- End with one observation about the week's pattern: was it a building week, a shipping week, a scattered week? One sentence, honest.

RULES:
- Only state facts from the data below. Do not fabricate.
- Do not lecture or suggest. Observe.
- No em dashes or double hyphens. Rewrite instead.
- Use plain [[wikilinks]] with no backticks when referencing vault files.
- If it was a quiet week, say so. Do not pad.

DONE THIS WEEK:
$($CAT "$TMPDIR_WORK/done_items.md")

REMAINING (carried over):
$($CAT "$TMPDIR_WORK/remaining.md")

DAILY JOURNAL ENTRIES:
$($CAT "$TMPDIR_WORK/journal_entries.md")
PROMPTEOF

/bin/zsh -c '
    export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$HOME/.local/bin"
    "$1" --print --dangerously-skip-permissions --model sonnet "$(/bin/cat "$2")" > "$3" 2>>"$4"
' -- "$CLAUDE" "$PROMPT_FILE" "$RESPONSE_FILE" "$LOG" || {
    log "Claude call failed"
    notify "Vault" "Weekly Reflection" "Claude call failed. Check logs." "Basso"
    exit 1
}

REFLECTION=$($CAT "$RESPONSE_FILE")
log "Response: $(/usr/bin/wc -c < "$RESPONSE_FILE" | /usr/bin/tr -d ' ') bytes"

# ============================================================
# OUTPUT
# ============================================================

WEEK_START=$(/bin/date -v-6d -j -f '%Y-%m-%d' "$TODAY" '+%Y-%m-%d')
WEEK_END="$TODAY"
DOW=$(/bin/date -j -f '%Y-%m-%d' "$TODAY" '+%A')

$CAT > "$OUTPUT" << EOF
---
created: $TODAY
tags:
  - journal
  - weekly
type: weekly
---

# Week of $WEEK_START to $WEEK_END

$REFLECTION

---

## Completed

$($CAT "$TMPDIR_WORK/done_items.md")

## Carrying Forward

$($CAT "$TMPDIR_WORK/remaining.md")
EOF

log "Weekly reflection written to $OUTPUT"

# Git commit
cd "$VAULT" && $GIT add "_PERSONAL/Journal/" && \
    $GIT commit -m "vault backup: weekly reflection $TODAY" 2>>"$LOG" || true

notify "Vault" "Weekly Reflection" "Your weekly reflection is ready"
log "Done"
