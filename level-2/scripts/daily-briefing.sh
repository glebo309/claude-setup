#!/bin/zsh
# Daily Briefing - Generalized version
#
# Phase 0: Data gathering with tagging (bash + python, no API tokens)
#   - Deadlines (#due/ tags, with LOUD/RECURRING detection)
#   - Commitments (orphaned action items from recent notes)
#   - Recent user notes (last 5 days of journal *Notes:* sections)
#
# Phase 1: Single Claude call
#   - Receives tagged data, surfaces in priority order
#   - LOUD first (imperative tone), rest calm
#   - Max 7 lines weekday, longer on weekends
#
# Trigger: sleepwatcher (~/.wakeup) on lid-open
# Setup: run setup.sh to install; see level-2/recipes/morning-briefing.md

set -euo pipefail
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$HOME/.local/bin"
CLEAN_PATH="$PATH"

CAT=/bin/cat
GIT=/usr/bin/git
PYTHON=/usr/bin/python3
CLAUDE="$HOME/.local/bin/claude"

source "$HOME/.claude/scripts/notify.sh"

VAULT="__VAULT__"
LOGDIR="$HOME/.claude/logs"
LOG="$LOGDIR/daily-briefing-$(/bin/date +%Y-%m-%d).log"
TODAY=$(/bin/date +%Y-%m-%d)
YEAR=$(/bin/date +%Y)
JOURNAL_DIR="$VAULT/_PERSONAL/Journal/$YEAR"
ARCHIVE_NOTE="$JOURNAL_DIR/$TODAY.md"
SURFACE_NOTE="$VAULT/Daily Briefing.md"
YESTERDAY=$(/bin/date -v-1d +%Y-%m-%d)
DOW=$(/bin/date -j -f '%Y-%m-%d' "$TODAY" '+%A')
IS_WEEKEND=false
if [ "$DOW" = "Saturday" ] || [ "$DOW" = "Sunday" ]; then
    IS_WEEKEND=true
fi

mkdir -p "$LOGDIR" "$JOURNAL_DIR"

log() { echo "[$(/bin/date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG"; }

# --- Only run after 06:30 ---
HOUR=$(/bin/date +%H)
MIN=$(/bin/date +%M)
if [ "$HOUR" -lt 6 ] || { [ "$HOUR" -eq 6 ] && [ "$MIN" -lt 30 ]; }; then
    exit 0
fi

TMPDIR_WORK=$(/usr/bin/mktemp -d /tmp/daily-briefing.XXXXXX)
trap '/bin/rm -rf "$TMPDIR_WORK"' EXIT

log "Daily briefing starting"

# --- Idempotency: one briefing per day ---
if [ -f "$ARCHIVE_NOTE" ]; then
    log "Daily note already exists, exiting"
    exit 0
fi

# --- Clean up previous surface note ---
if [ -f "$SURFACE_NOTE" ]; then
    PREV_DATE=$(grep -m1 '^created:' "$SURFACE_NOTE" 2>/dev/null | sed 's/created: *//' | /usr/bin/tr -d ' ')
    if [ -n "$PREV_DATE" ] && [ "$PREV_DATE" != "$TODAY" ]; then
        PREV_YEAR=${PREV_DATE%%-*}
        PREV_DIR="$VAULT/_PERSONAL/Journal/$PREV_YEAR"
        mkdir -p "$PREV_DIR"
        if [ ! -f "$PREV_DIR/$PREV_DATE.md" ]; then
            mv "$SURFACE_NOTE" "$PREV_DIR/$PREV_DATE.md"
            log "Archived previous briefing ($PREV_DATE)"
        else
            /bin/rm -f "$SURFACE_NOTE"
        fi
    fi
fi

# --- Wait for network ---
NETWORK_TRIES=0
while [ $NETWORK_TRIES -lt 12 ]; do
    if /usr/bin/curl -s --max-time 5 -o /dev/null https://api.anthropic.com 2>/dev/null; then
        break
    fi
    NETWORK_TRIES=$((NETWORK_TRIES + 1))
    sleep 5
done
if [ $NETWORK_TRIES -eq 12 ]; then
    log "No network after 60s, aborting"
    notify "Vault" "Daily Briefing" "No network. Will retry on next wake." "Basso"
    exit 1
fi

# ============================================================
# PHASE 0: DATA GATHERING WITH TAGS
# ============================================================
log "Phase 0: Data gathering"
cd "$VAULT"

TAGGED_DATA="$TMPDIR_WORK/tagged_data.md"

# Discover domain folders dynamically (everything starting with _ except _SYSTEM and _INBOX)
SCAN_DIRS=""
for dir in "$VAULT"/_*/; do
    dirname=$(basename "$dir")
    case "$dirname" in
        _SYSTEM|_INBOX) continue ;;
        *) SCAN_DIRS="$SCAN_DIRS $dir" ;;
    esac
done

$PYTHON - "$VAULT" "$TODAY" "$YESTERDAY" "$TAGGED_DATA" "$SCAN_DIRS" << 'PYEOF'
import os, re, sys, subprocess
from datetime import datetime, timedelta, date
from pathlib import Path

vault = sys.argv[1]
today = datetime.strptime(sys.argv[2], "%Y-%m-%d").date()
yesterday = sys.argv[3]
output_path = sys.argv[4]
scan_dirs = sys.argv[5].strip().split() if len(sys.argv) > 5 else []

lines = []

# --- DEADLINES ---
grep_args = ["grep", "-rn", r"#due/[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}",
             "--include=*.md", "--exclude-dir=Journal"]
grep_args.extend(scan_dirs)
grep_args.extend([os.path.join(vault, "_INBOX")])

result = subprocess.run(grep_args, capture_output=True, text=True)

for line in result.stdout.strip().split("\n"):
    if not line.strip(): continue
    parts = line.split(":", 2)
    if len(parts) < 3: continue
    filepath, content = parts[0], parts[2]
    if "#done/" in content:
        continue
    for ds in re.findall(r"#due/(\d{4}-\d{2}-\d{2})", content):
        try:
            d = datetime.strptime(ds, "%Y-%m-%d").date()
        except ValueError:
            continue
        days_until = (d - today).days
        if days_until > 14: continue

        note = Path(filepath).stem
        task = re.sub(r"\s*#due/\d{4}-\d{2}-\d{2}", "", content.strip()).strip()
        task = re.sub(r"^[-*]\s*\[[ x]\]\s*|^[-*]\s*", "", task).strip() or "(no description)"

        # LOUD: within 3 days AND no recent git activity on this file
        is_loud = False
        if days_until <= 3:
            git_check = subprocess.run(
                ["git", "-C", vault, "log", "--since=3 days ago", "--oneline", "--", filepath],
                capture_output=True, text=True
            )
            if not git_check.stdout.strip():
                is_loud = True

        tag = "[LOUD]" if is_loud else "[DEADLINE]"
        if days_until < 0:
            lines.append(f"{tag} OVERDUE {-days_until}d: {task} (from [[{note}]], due {ds})")
        elif days_until == 0:
            lines.append(f"{tag} TODAY: {task} (from [[{note}]])")
        elif days_until <= 3:
            lines.append(f"{tag} IN {days_until}d: {task} (from [[{note}]], due {ds})")
        else:
            lines.append(f"[DEADLINE] IN {days_until}d: {task} (from [[{note}]], due {ds})")

# --- COMMITMENTS (orphaned action items from last 7 days) ---
patterns = [
    r"(?:need to|should|will|must|have to|going to)\s+\w+",
    r"(?:ask|email|message|tell|remind|check with)\s+\w+",
    r"(?:TODO|FIXME)\b",
]
combined = re.compile("|".join(patterns), re.IGNORECASE)
cutoff = today - timedelta(days=7)

commit_scan_dirs = [
    os.path.join(vault, "_PERSONAL/Journal"),
    os.path.join(vault, "_INBOX"),
]

for scan_dir in commit_scan_dirs:
    if not os.path.isdir(scan_dir): continue
    for root, dirs, files in os.walk(scan_dir):
        for fn in files:
            if not fn.endswith(".md"): continue
            fp = os.path.join(root, fn)
            try:
                mtime = datetime.fromtimestamp(os.path.getmtime(fp)).date()
                if mtime < cutoff: continue
            except Exception: continue
            try:
                with open(fp) as f:
                    file_lines = f.readlines()
                is_journal = "/Journal/" in fp
                past_notes_marker = not is_journal
                for i, line in enumerate(file_lines, 1):
                    if is_journal and not past_notes_marker:
                        if line.strip() == "*Notes:*":
                            past_notes_marker = True
                        continue
                    if combined.search(line):
                        clean = line.strip()
                        if clean.startswith("#") or clean.startswith("---"): continue
                        if len(clean) < 10 or len(clean) > 200: continue
                        if "#done/" in clean: continue
                        future_dates = re.findall(r"\b(\d{4}-\d{2}-\d{2})\b", clean)
                        skip = False
                        for fd in future_dates:
                            try:
                                fd_date = datetime.strptime(fd, "%Y-%m-%d").date()
                                if (fd_date - today).days > 14:
                                    skip = True; break
                            except ValueError: pass
                        if skip: continue
                        lines.append(f"[COMMITMENT] {clean} (from {Path(fp).stem})")
            except Exception: continue

# --- RECURRENCE DETECTION ---
import glob
journal_dir = os.path.join(vault, "_PERSONAL/Journal", str(today.year))
recent_briefings = sorted(glob.glob(os.path.join(journal_dir, "????-??-??.md")), reverse=True)[:5]

recurring_notes = {}
for bp in recent_briefings:
    try:
        with open(bp) as f:
            for bline in f:
                if "overdue" in bline.lower() or "OVERDUE" in bline or "#due/" in bline:
                    for note_ref in re.findall(r'\[\[([^\]]+)\]\]', bline):
                        recurring_notes[note_ref] = recurring_notes.get(note_ref, 0) + 1
    except Exception: pass

upgraded = []
for line in lines:
    if "[LOUD]" in line:
        note_match = re.search(r'\[\[([^\]]+)\]\]', line)
        if note_match and recurring_notes.get(note_match.group(1), 0) >= 3:
            upgraded.append(line.replace("[LOUD]", "[RECURRING]"))
        else:
            upgraded.append(line)
    else:
        upgraded.append(line)
lines = upgraded

# --- DEADLINE DEDUPLICATION ---
from collections import defaultdict
deadline_tags = ('[LOUD]', '[DEADLINE]', '[RECURRING]')
deadline_lines = [l for l in lines if any(tag in l for tag in deadline_tags)]
non_deadline_lines = [l for l in lines if not any(tag in l for tag in deadline_tags)]

by_date = defaultdict(list)
for dl in deadline_lines:
    date_match = re.search(r'due (\d{4}-\d{2}-\d{2})', dl)
    key = date_match.group(1) if date_match else 'no_date'
    by_date[key].append(dl)

deduped = []
for date_key, items in by_date.items():
    if len(items) <= 1:
        deduped.extend(items)
        continue
    kept = []
    for item in items:
        task_match = re.search(r'\]\s*(?:OVERDUE \d+d:|TODAY:|IN \d+d:)\s*(.+?)\s*\(from', item)
        if not task_match:
            kept.append(item); continue
        task_words = set(re.findall(r'\w+', task_match.group(1).lower()))
        is_dup = False
        for ki, kept_item in enumerate(kept):
            kept_match = re.search(r'\]\s*(?:OVERDUE \d+d:|TODAY:|IN \d+d:)\s*(.+?)\s*\(from', kept_item)
            if not kept_match: continue
            kept_words = set(re.findall(r'\w+', kept_match.group(1).lower()))
            if not task_words or not kept_words: continue
            overlap = len(task_words & kept_words) / min(len(task_words), len(kept_words))
            if overlap >= 0.5:
                if '[[T_' in item and '[[T_' not in kept_item:
                    kept[ki] = item
                is_dup = True; break
        if not is_dup:
            kept.append(item)
    deduped.extend(kept)

lines = non_deadline_lines + deduped

# --- RECENT NOTES (last 5 days, *Notes:* sections only) ---
all_journals = []
for y in [str(today.year), str(today.year - 1)]:
    jdir = os.path.join(vault, "_PERSONAL/Journal", y)
    all_journals.extend(glob.glob(os.path.join(jdir, "????-??-??.md")))
all_journals = sorted(all_journals, reverse=True)
today_str = sys.argv[2]
recent_journals = [j for j in all_journals if Path(j).stem < today_str][:5]

recent_notes_out = output_path.replace("tagged_data.md", "recent_notes.md")
notes_sections = []
for jf in recent_journals:
    try:
        with open(jf) as f:
            content = f.read()
        marker_pos = content.find("*Notes:*")
        if marker_pos == -1: continue
        notes_text = content[marker_pos + len("*Notes:*"):].strip()
        if not notes_text: continue
        notes_sections.append(f"### {Path(jf).stem}\n{notes_text}")
    except Exception: continue

with open(recent_notes_out, "w") as f:
    f.write("\n\n".join(notes_sections) if notes_sections else "(no recent notes)")

# --- Write tagged output ---
with open(output_path, "w") as f:
    f.write("\n".join(lines))

print(f"Tagged: {len([l for l in lines if '[LOUD]' in l])} loud, "
      f"{len([l for l in lines if '[RECURRING]' in l])} recurring, "
      f"{len([l for l in lines if '[DEADLINE]' in l])} deadlines, "
      f"{len([l for l in lines if '[COMMITMENT]' in l])} commitments, "
      f"{len([l for l in lines if '[STALE]' in l])} stale")
PYEOF

log "  Phase 0 done: $($CAT "$TAGGED_DATA" | /usr/bin/wc -l | /usr/bin/tr -d ' ') tagged items"

# ============================================================
# PHASE 1: SINGLE CLAUDE CALL
# ============================================================
log "Phase 1: Claude call"

OPUS_INPUT="$TMPDIR_WORK/prompt.md"

$CAT > "$OPUS_INPUT" << PROMPTEOF
Today is $TODAY ($(/bin/date -j -f '%Y-%m-%d' "$TODAY" '+%A')).

You are writing a 30-second morning orientation for __USER_NAME__. Format: short paragraphs, not bullets or headers. 5-7 lines max. Blank line between items.

GROUNDING (absolute, never violate):
- You may ONLY state facts that appear verbatim in the TAGGED DATA below.
- NEVER invent details: no instrument readings, no timelines, no procedural steps that are not in the tagged data.
- When in doubt, say less. Silence is better than fabrication.

RULES:
1. For [LOUD] overdue items: do NOT command action. Ask what is blocking. If an item has been overdue for days with no movement, the question is "what is actually preventing this?" not "do it today."
2. For [RECURRING] items (appeared in 3+ consecutive briefings): do NOT ask the same question again. Either suggest one concrete mechanism (pair it with an external deadline, schedule a focused block) or say "this has rolled N weeks without movement; parking it until a weekly review decides." One sentence max.
3. For [DEADLINE] items beyond 7 days out: one calm line with context about lead time needed. Skip if >30 days out unless prep is needed now.
4. For [COMMITMENT]: only surface if it is something actionable today. Skip if clearly deprioritized.
5. Each item should carry a "so what" for today.
7. NEVER use em dashes, double hyphens (--), or any dash-substitute. Rewrite the sentence instead.
8. When referencing vault files in the narrative, use plain [[wikilinks]] with NO backticks.
9. On quiet days (nothing loud, nothing stale): say "Nothing pressing" and suggest one low-stakes thing worth starting. Do not force content.
10. RECENT NOTES below contain __USER_NAME__'s actual responses from the last few days. These are AUTHORITATIVE and override tagged data when they conflict. If a task was deferred, it is deferred. If something was flagged as done, do not raise it again. Read the notes carefully before writing anything.

FOCUS MODE: $(if [ "$IS_WEEKEND" = "true" ]; then echo "WEEKEND"; else echo "WEEKDAY"; fi)

$(if [ "$IS_WEEKEND" = "true" ]; then
$CAT << 'WEEKEND_RULES'
WEEKEND RULES:
- LENGTH: 3-5 paragraphs. Longer than weekday, shorter than an essay.
- Work tasks are deprioritized. Focus on personal/creative threads.
- Do NOT announce it is the weekend. Just write differently.
- End with one genuine question that requires self-knowledge, not vault knowledge.
WEEKEND_RULES
fi)

TAGGED DATA:
$($CAT "$TAGGED_DATA")

RECENT NOTES (__USER_NAME__'s own words from previous days, AUTHORITATIVE over tagged data):
$($CAT "$TMPDIR_WORK/recent_notes.md" 2>/dev/null || echo "(none)")
PROMPTEOF

# Run Claude in isolated process
OPUS_OUT="$TMPDIR_WORK/response.md"
/bin/zsh -c '
    export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$HOME/.local/bin"
    "$1" --print --dangerously-skip-permissions --model opus "$(/bin/cat "$2")" > "$3" 2>>"$4"
' -- "$CLAUDE" "$OPUS_INPUT" "$OPUS_OUT" "$LOG" || {
    log "Claude call failed, retrying"
    sleep 10
    /bin/zsh -c '
        export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$HOME/.local/bin"
        "$1" --print --dangerously-skip-permissions --model opus "$(/bin/cat "$2")" > "$3" 2>>"$4"
    ' -- "$CLAUDE" "$OPUS_INPUT" "$OPUS_OUT" "$LOG" || {
        log "Retry failed"
        notify "Vault" "Daily Briefing" "Claude call failed. Check logs." "Basso"
        exit 1
    }
}

export PATH="$CLEAN_PATH"
log "  Response: $(/usr/bin/wc -c < "$OPUS_OUT" | /usr/bin/tr -d ' ') bytes"

BRIEFING=$($CAT "$OPUS_OUT")

# ============================================================
# OUTPUT: Write daily note
# ============================================================
export PATH="$CLEAN_PATH"
log "Writing daily note"

$PYTHON - "$TODAY" "$ARCHIVE_NOTE" "$BRIEFING" "$TAGGED_DATA" << 'BUILDEOF'
import sys, re
from datetime import datetime

today_str = sys.argv[1]
output = sys.argv[2]
briefing = sys.argv[3]
tagged_file = sys.argv[4] if len(sys.argv) > 4 else ""

dt = datetime.strptime(today_str, "%Y-%m-%d")
dow = dt.strftime("%A")
pretty = dt.strftime("%-d %B %Y")

L = ["---", f"created: {today_str}", "tags:", "  - journal", "  - daily",
     "type: daily", "---", f"# {dow}, {pretty}", ""]

L += [briefing, ""]
L += ["---", ""]

# Deadlines
if tagged_file:
    try:
        with open(tagged_file) as f:
            tlines = [l.strip() for l in f if l.strip()]
    except Exception:
        tlines = []

    deadlines = [l for l in tlines if "[LOUD]" in l or "[DEADLINE]" in l or "[RECURRING]" in l]
    if deadlines:
        L += ["## Deadlines", ""]
        for d in deadlines:
            clean = re.sub(r'\[(LOUD|DEADLINE|RECURRING)\]\s*', '', d)
            L.append(f"- {clean}")
        L.append("")

L += ["---", "", "*Notes:*", "", ""]

with open(output, "w") as f: f.write("\n".join(L))
BUILDEOF

# Copy journal note to vault root for quick access in Obsidian
/bin/rm -f "$SURFACE_NOTE"
/bin/cp "$ARCHIVE_NOTE" "$SURFACE_NOTE"
log "Daily note written, surface file copied"

# --- Git commit ---
cd "$VAULT" && $GIT add "_PERSONAL/Journal/" && \
    $GIT commit -m "vault backup: daily briefing $(/bin/date '+%Y-%m-%d')" 2>>"$LOG" || true
log "Git commit done"

# --- Notify ---
notify "Vault" "Daily Briefing" "Your morning briefing is ready"
log "Done"
