# Recipe: Review Cycle

**Pattern:** scheduled (weekly + monthly) | **Tokens:** HIGH

Periodic retrospectives that look back at what was done, what moved, what's stuck, and what to focus on next.

---

## Concept

Two scripts, two cadences:

| Review | Schedule | Scope | Output |
|---|---|---|---|
| **Weekly** | Sunday evening | Last 7 days | Shipped list, thread movement, priorities for next week |
| **Monthly** | 1st of month | Last 4 weeks | Trends, velocity, strategic direction |

The monthly review reads the weekly reviews, so they build on each other.

---

## Weekly Review -- What It Does

1. **Gather** (zero tokens):
   - All `#done/` tags from the past 7 days (shipped items)
   - Active threads with `status: active` and days since last edit
   - Git log grouped by project
   - Inbox count and age of oldest file
   - Deadlines within the next 14 days
   - Previous 3-4 weekly reviews for velocity comparison

2. **Analyze** (spends tokens):
   - Per-project digest: what moved, what's stuck, what's new
   - Cross-project connections
   - Blind spots: things that should have moved but didn't

3. **Output**:
   - `_PERSONAL/Journal/YYYY/Weekly/YYYY-Www.md`
   - Shipped table, thread movement, progression chart
   - Top 3 priorities for next week

---

## Weekly Review Skeleton

```bash
#!/bin/zsh
set -euo pipefail

VAULT="$HOME/Documents/SecondBrain"
TODAY=$(date +%Y-%m-%d)
YEAR=$(date +%Y)
WEEK=$(date +%V)
OUTPUT="$VAULT/_PERSONAL/Journal/$YEAR/Weekly/${YEAR}-W${WEEK}.md"
LOG="$HOME/.claude/logs/weekly-review-$TODAY.log"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG"; }
log "Starting weekly review"

mkdir -p "$(dirname "$OUTPUT")"

# Shipped items (last 7 days)
SHIPPED=$(grep -rn '#done/' "$VAULT" --include="*.md" 2>/dev/null | \
    while IFS= read -r line; do
        DONE_DATE=$(echo "$line" | grep -oE '#done/[0-9]{4}-[0-9]{2}-[0-9]{2}' | sed 's/#done\///')
        CUTOFF=$(date -v-7d +%Y-%m-%d 2>/dev/null || date -d "7 days ago" +%Y-%m-%d)
        if [[ "$DONE_DATE" > "$CUTOFF" ]]; then echo "$line"; fi
    done)

# Active threads
ACTIVE=$(grep -rl 'status: active' "$VAULT" --include="*.md" 2>/dev/null)

# Git activity
GIT_LOG=$(cd "$VAULT" && git log --oneline --since="7 days ago" 2>/dev/null || echo "No git history")

# Build prompt
PROMPT="Write a weekly review for week $WEEK of $YEAR.

SHIPPED THIS WEEK:
$SHIPPED

ACTIVE THREADS:
$ACTIVE

GIT ACTIVITY:
$GIT_LOG

Write:
1. A 'Shipped' table (file, what was done, date)
2. Thread movement (what advanced, what's stale)
3. Top 3 priorities for next week
Keep it concise."

REVIEW=$(echo "$PROMPT" | claude --print 2>/dev/null)

cat > "$OUTPUT" << EOF
---
created: $TODAY
tags:
  - journal
  - review
type: weekly-review
---

# Week $WEEK Review

$REVIEW

*Notes:*

EOF

cd "$VAULT"
git add "$OUTPUT" 2>/dev/null
git commit -m "Weekly review W$WEEK" 2>/dev/null || true

log "Done"
```

---

## Monthly Review

The monthly review is similar but reads all weekly reviews from the past month and looks for trends:

- Velocity: are you shipping more or less?
- Recurring blockers: same thread stuck for 3+ weeks?
- Balance: which domains got attention, which were neglected?
- Strategic: are you working on the right things?

**Output:** `_PERSONAL/Journal/YYYY/Monthly/YYYY-MM.md`

**Trigger:** 1st of the month at 9 PM. See [scheduled.md](../patterns/scheduled.md).

---

## Long-Term Memory

Consider maintaining a `TRAJECTORY.md` file that the weekly review updates. It contains:

- **Project Arcs:** Where each major project was, is, and is heading
- **Behavioral Patterns:** Observed work habits (e.g. "tends to neglect inbox for 2+ weeks")
- **Velocity Trends:** 4-week rolling average of shipped items

The daily briefing and weekly review both read this file for context, creating a feedback loop.
