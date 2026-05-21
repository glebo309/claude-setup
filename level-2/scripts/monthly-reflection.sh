#!/bin/zsh
# Monthly Reflection
#
# Reads all weekly reflections and daily entries from the past month,
# asks Claude to write a higher-level summary: patterns, progress,
# course corrections.
#
# Trigger: scheduled (1st of the month, or manually)
# Output: _PERSONAL/Journal/YYYY/Month-YYYY-MM.md

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

# The reflection covers the PREVIOUS month
PREV_MONTH=$(/bin/date -v-1m +%Y-%m)
PREV_MONTH_NAME=$(/bin/date -v-1m '+%B %Y')
LOG="$LOGDIR/monthly-reflection-$PREV_MONTH.log"
JOURNAL_DIR="$VAULT/_PERSONAL/Journal/$YEAR"
OUTPUT="$JOURNAL_DIR/Month-$PREV_MONTH.md"

mkdir -p "$LOGDIR" "$JOURNAL_DIR"

log() { echo "[$(/bin/date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG"; }

# --- Idempotency ---
if [ -f "$OUTPUT" ]; then
    log "Monthly reflection already exists for $PREV_MONTH, exiting"
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

TMPDIR_WORK=$(/usr/bin/mktemp -d /tmp/monthly-reflection.XXXXXX)
trap '/bin/rm -rf "$TMPDIR_WORK"' EXIT

log "Monthly reflection starting for $PREV_MONTH"

# ============================================================
# DATA GATHERING
# ============================================================

$PYTHON - "$VAULT" "$PREV_MONTH" "$TMPDIR_WORK" << 'PYEOF'
import os, re, sys, glob
from datetime import datetime, timedelta
from pathlib import Path

vault = sys.argv[1]
month_str = sys.argv[2]  # YYYY-MM
tmpdir = sys.argv[3]

year, month = month_str.split("-")
year = int(year)
month = int(month)

# Determine date range for this month
from calendar import monthrange
_, last_day = monthrange(year, month)
month_start = f"{month_str}-01"
month_end = f"{month_str}-{last_day:02d}"

# Collect weekly reflections from this month
journal_dir = os.path.join(vault, "_PERSONAL/Journal", str(year))
weekly_files = sorted(glob.glob(os.path.join(journal_dir, f"Week-{month_str}-*.md")))
weeklies = []
for wf in weekly_files:
    try:
        with open(wf) as f:
            weeklies.append((Path(wf).stem, f.read()))
    except Exception:
        pass

# Collect daily entries from this month (just the *Notes:* sections for brevity)
daily_notes = []
for day in range(1, last_day + 1):
    date_str = f"{month_str}-{day:02d}"
    daily_path = os.path.join(journal_dir, f"{date_str}.md")
    if not os.path.isfile(daily_path): continue
    try:
        with open(daily_path) as f:
            content = f.read()
        marker = content.find("*Notes:*")
        if marker >= 0:
            notes = content[marker + len("*Notes:*"):].strip()
            if notes:
                daily_notes.append((date_str, notes))
        else:
            # No notes marker; include briefing narrative (first 500 chars after frontmatter)
            lines = content.split("\n")
            body_start = 0
            in_yaml = False
            for i, line in enumerate(lines):
                if line.strip() == "---":
                    if in_yaml:
                        body_start = i + 1
                        break
                    in_yaml = True
            body = "\n".join(lines[body_start:body_start+15])
            if body.strip():
                daily_notes.append((date_str, body[:500]))
    except Exception:
        pass

# Collect all #done/ tags from this month
import subprocess
done_items = []
result = subprocess.run(
    ["grep", "-rn", r"#done/", "--include=*.md"] +
    [d for d in glob.glob(os.path.join(vault, "_*/"))
     if os.path.basename(d.rstrip("/")) != "_SYSTEM"],
    capture_output=True, text=True
)
for line in result.stdout.strip().split("\n"):
    if not line.strip(): continue
    for ds in re.findall(r"#done/(\d{4}-\d{2}-\d{2})", line):
        if ds >= month_start and ds <= month_end:
            parts = line.split(":", 2)
            if len(parts) >= 3:
                note = Path(parts[0]).stem
                task = re.sub(r"\s*#done/\d{4}-\d{2}-\d{2}", "", parts[2].strip()).strip()
                task = re.sub(r"^[-*]\s*\[[ x]\]\s*|^[-*]\s*", "", task).strip()
                done_items.append(f"- {task} (from [[{note}]], done {ds})")

# Write data files
with open(os.path.join(tmpdir, "weeklies.md"), "w") as f:
    if weeklies:
        for stem, content in weeklies:
            f.write(f"## {stem}\n\n{content}\n\n---\n\n")
    else:
        f.write("(no weekly reflections found for this month)\n")

with open(os.path.join(tmpdir, "daily_notes.md"), "w") as f:
    for date_str, notes in sorted(daily_notes):
        f.write(f"### {date_str}\n{notes}\n\n")

with open(os.path.join(tmpdir, "done_items.md"), "w") as f:
    f.write("\n".join(sorted(done_items)) if done_items else "(nothing tagged as done this month)")

print(f"Gathered: {len(weeklies)} weekly reflections, {len(daily_notes)} daily notes, {len(done_items)} done items")
PYEOF

log "Data gathered"

# ============================================================
# CLAUDE CALL
# ============================================================
log "Calling Claude for monthly reflection"

PROMPT_FILE="$TMPDIR_WORK/prompt.md"
RESPONSE_FILE="$TMPDIR_WORK/response.md"

$CAT > "$PROMPT_FILE" << PROMPTEOF
Write a monthly reflection for __USER_NAME__ covering $PREV_MONTH_NAME.

FORMAT:
- 4-6 paragraphs, plain prose
- Start with what actually got done (the headline accomplishments, not a laundry list)
- Then what patterns emerged: was this a focused month or a scattered one? Did certain areas get all the attention while others went quiet?
- Note anything that was repeatedly deferred or stuck
- End with one honest line about where things stand heading into next month

RULES:
- Only state facts from the data below. Do not fabricate.
- Do not lecture, suggest, or motivate. Just observe clearly.
- No em dashes or double hyphens. Rewrite instead.
- Use plain [[wikilinks]] when referencing vault files.
- If the month was quiet, say so. Quiet months are fine.

WEEKLY REFLECTIONS:
$($CAT "$TMPDIR_WORK/weeklies.md")

DAILY NOTES (user's own words throughout the month):
$($CAT "$TMPDIR_WORK/daily_notes.md")

COMPLETED THIS MONTH:
$($CAT "$TMPDIR_WORK/done_items.md")
PROMPTEOF

/bin/zsh -c '
    export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$HOME/.local/bin"
    "$1" --print --dangerously-skip-permissions --model sonnet "$(/bin/cat "$2")" > "$3" 2>>"$4"
' -- "$CLAUDE" "$PROMPT_FILE" "$RESPONSE_FILE" "$LOG" || {
    log "Claude call failed"
    notify "Vault" "Monthly Reflection" "Claude call failed. Check logs." "Basso"
    exit 1
}

REFLECTION=$($CAT "$RESPONSE_FILE")
log "Response: $(/usr/bin/wc -c < "$RESPONSE_FILE" | /usr/bin/tr -d ' ') bytes"

# ============================================================
# OUTPUT
# ============================================================

$CAT > "$OUTPUT" << EOF
---
created: $TODAY
tags:
  - journal
  - monthly
type: monthly
---

# $PREV_MONTH_NAME

$REFLECTION

---

## Completed This Month

$($CAT "$TMPDIR_WORK/done_items.md")
EOF

log "Monthly reflection written to $OUTPUT"

# Git commit
cd "$VAULT" && $GIT add "_PERSONAL/Journal/" && \
    $GIT commit -m "vault backup: monthly reflection $PREV_MONTH" 2>>"$LOG" || true

notify "Vault" "Monthly Reflection" "Your $PREV_MONTH_NAME reflection is ready"
log "Done"
