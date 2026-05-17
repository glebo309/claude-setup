# Recipe: Morning Briefing

**Pattern:** on-wake | **Tokens:** HIGH (calls Claude)

A script that fires when you open your laptop, scans your vault for deadlines, active threads, and recent journal entries, then uses Claude to write a concise morning briefing into today's journal note.

---

## What It Does

1. **Gather data** (zero tokens):
   - Scan vault for `#due/YYYY-MM-DD` tags, group by urgency (overdue, today, next 3 days)
   - Find active threads (`status: active` in frontmatter), flag stale ones (>10 days since edit)
   - Read the last 3 days of journal entries for context
   - Check for orphaned tasks (commitments mentioned but not tracked with `#due/`)

2. **Synthesize** (spends tokens):
   - Send all gathered data to Claude in a single prompt
   - Claude writes a 5-7 line narrative briefing: what's urgent, what's stale, what to focus on
   - On weekends: longer briefing with structural connections between recent work

3. **Output**:
   - Create today's journal note at `_PERSONAL/Journal/YYYY/YYYY-MM-DD.md`
   - Write the briefing into the YAML header or a Briefing section
   - Include a Threads table and Deadlines section
   - Copy to a surface file (e.g. `Daily Briefing.md` at vault root) for quick access

4. **Commit**: `git add` the journal note and commit

---

## Skeleton Script

```bash
#!/bin/zsh
set -euo pipefail

VAULT="$HOME/Documents/SecondBrain"
TODAY=$(date +%Y-%m-%d)
YEAR=${TODAY%%-*}
LOG="$HOME/.claude/logs/daily-briefing-$TODAY.log"
JOURNAL="$VAULT/_PERSONAL/Journal/$YEAR/$TODAY.md"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG"; }
log "Starting daily briefing"

# Guard: only run once per day
LOCKFILE="/tmp/briefing-$TODAY.lock"
if [[ -f "$LOCKFILE" ]]; then log "Already ran today"; exit 0; fi

# Guard: only run after 6:30 AM
HOUR=$(date +%H)
if [[ "$HOUR" -lt 7 ]]; then log "Too early ($HOUR)"; exit 0; fi

touch "$LOCKFILE"

# --- Phase 0: Gather data ---

# Deadlines
DEADLINES=$(grep -rn '#due/' "$VAULT/_RESEARCH" "$VAULT/_CREATIVE" "$VAULT/_PERSONAL" \
    --include="*.md" 2>/dev/null | head -50)

# Active threads
THREADS=$(grep -rl 'status: active' "$VAULT" --include="*.md" 2>/dev/null | head -20)

# Recent journal entries
RECENT_JOURNALS=""
for i in 1 2 3; do
    PAST=$(date -v-${i}d +%Y-%m-%d 2>/dev/null || date -d "$i days ago" +%Y-%m-%d)
    PAST_YEAR=${PAST%%-*}
    PAST_FILE="$VAULT/_PERSONAL/Journal/$PAST_YEAR/$PAST.md"
    if [[ -f "$PAST_FILE" ]]; then
        RECENT_JOURNALS="$RECENT_JOURNALS\n--- $PAST ---\n$(head -50 "$PAST_FILE")"
    fi
done

# --- Phase 1: Claude synthesis ---

mkdir -p "$(dirname "$JOURNAL")"

# Build the prompt with all gathered data
PROMPT="You are writing a morning briefing for $TODAY.

DEADLINES:
$DEADLINES

ACTIVE THREADS:
$THREADS

RECENT JOURNAL:
$RECENT_JOURNALS

Write a 5-7 line morning briefing. Be specific about what is urgent and what to focus on today."

# Call Claude (headless mode)
BRIEFING=$(echo "$PROMPT" | claude --print 2>/dev/null)

# --- Phase 2: Write journal note ---

cat > "$JOURNAL" << EOF
---
created: $TODAY
tags:
  - journal
type: journal
---

# $TODAY

$BRIEFING

## Threads

(active threads listed here)

## Deadlines

(deadlines listed here)

*Notes:*

EOF

# Copy to surface file
cp "$JOURNAL" "$VAULT/Daily Briefing.md"

# Git commit
cd "$VAULT"
git add "$JOURNAL" "Daily Briefing.md" 2>/dev/null
git commit -m "Daily briefing $TODAY" 2>/dev/null || true

log "Briefing complete"
```

---

## Trigger Setup

**macOS (~/.wakeup):**
```bash
#!/bin/zsh
/bin/zsh $HOME/.claude/scripts/daily-briefing.sh &
```

See [on-wake.md](../patterns/on-wake.md) for the full setup.

---

## Customization Ideas

- Add a "random old note" section: pick a random file >30 days old and include a snippet
- Add experimental results: scan for `EXP_*` files modified in the last 3 days
- Weekend mode: longer, more reflective briefing with cross-domain connections
- Chain to a daily lesson script (podcast excerpt, quote, etc.)
