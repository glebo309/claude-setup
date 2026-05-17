# Recipe: Deadline Scanner

**Pattern:** scheduled (3x/day) | **Tokens:** ZERO

A script that scans your vault for `#due/YYYY-MM-DD` tags, groups them by urgency, writes a briefing file, and sends a notification.

---

## What It Does

1. **Scan** all markdown files for `#due/YYYY-MM-DD` tags
2. **Group** by urgency: OVERDUE, DUE TODAY, NEXT 3 DAYS, LATER
3. **Write** a briefing file to `_SYSTEM/DEADLINE_BRIEFING.md`
4. **Notify** via macOS notification with urgency-appropriate sound
5. **Propagate** checked-off items back to source files (optional)

---

## Skeleton Script

```bash
#!/bin/zsh
set -euo pipefail

VAULT="$HOME/Documents/SecondBrain"
TODAY=$(date +%Y-%m-%d)
OUTPUT="$VAULT/_SYSTEM/DEADLINE_BRIEFING.md"
LOG="$HOME/.claude/logs/deadline-check-$TODAY.log"
QUIET="${1:-}"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG"; }
log "Starting deadline check"

source "$HOME/.claude/scripts/notify.sh"

# Scan for all #due/ tags
RESULTS=$(grep -rn '#due/[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}' \
    "$VAULT/_RESEARCH" "$VAULT/_CREATIVE" "$VAULT/_PERSONAL" \
    --include="*.md" 2>/dev/null || true)

if [[ -z "$RESULTS" ]]; then
    log "No deadlines found"
    echo "No active deadlines." > "$OUTPUT"
    exit 0
fi

# Parse and categorize
OVERDUE=""
DUE_TODAY=""
NEXT_3=""
LATER=""
COUNT_URGENT=0

while IFS= read -r line; do
    # Extract the date from the #due/ tag
    DUE_DATE=$(echo "$line" | grep -oE '#due/[0-9]{4}-[0-9]{2}-[0-9]{2}' | sed 's/#due\///')
    FILE=$(echo "$line" | cut -d: -f1)
    FILENAME=$(basename "$FILE" .md)
    CONTENT=$(echo "$line" | cut -d: -f3-)

    if [[ "$DUE_DATE" < "$TODAY" ]]; then
        OVERDUE="$OVERDUE\n- **OVERDUE** ($DUE_DATE): [[$FILENAME]] $CONTENT"
        ((COUNT_URGENT++))
    elif [[ "$DUE_DATE" == "$TODAY" ]]; then
        DUE_TODAY="$DUE_TODAY\n- **TODAY**: [[$FILENAME]] $CONTENT"
        ((COUNT_URGENT++))
    elif [[ "$DUE_DATE" < $(date -v+3d +%Y-%m-%d 2>/dev/null || date -d "+3 days" +%Y-%m-%d) ]]; then
        NEXT_3="$NEXT_3\n- $DUE_DATE: [[$FILENAME]] $CONTENT"
    else
        LATER="$LATER\n- $DUE_DATE: [[$FILENAME]] $CONTENT"
    fi
done <<< "$RESULTS"

# Write briefing file
cat > "$OUTPUT" << EOF
---
updated: $TODAY $(date +%H:%M)
type: system
---
# Deadline Briefing

Last scanned: $TODAY $(date +%H:%M)

## Overdue
$(echo -e "${OVERDUE:-\nNone}")

## Due Today
$(echo -e "${DUE_TODAY:-\nNone}")

## Next 3 Days
$(echo -e "${NEXT_3:-\nNone}")

## Later
$(echo -e "${LATER:-\nNone}")
EOF

log "Found $COUNT_URGENT urgent deadlines"

# Notify (unless --quiet flag)
if [[ "$QUIET" != "--quiet" ]] && [[ "$COUNT_URGENT" -gt 0 ]]; then
    if [[ -n "$OVERDUE" ]]; then
        notify "Deadlines" "$COUNT_URGENT urgent" "Check DEADLINE_BRIEFING" "Sosumi"
    else
        notify "Deadlines" "$COUNT_URGENT due today/soon" "Check DEADLINE_BRIEFING" "Glass"
    fi
fi

log "Done"
```

---

## Trigger Setup

**Scheduled 3x/day (macOS):**

Use the scheduled pattern with multiple `StartCalendarInterval` entries for 7am, 12pm, 5pm. See [scheduled.md](../patterns/scheduled.md).

**File-watch variant:**

Also trigger silently on vault changes so the briefing file stays current. Create a second LaunchAgent using the file-watch pattern with `--quiet` flag. See [file-watch.md](../patterns/file-watch.md).

---

## Notification Sounds

| Urgency | Sound | When |
|---|---|---|
| Overdue items exist | Sosumi | Something slipped |
| Due today only | Glass | Heads up |
| Nothing urgent | (none) | File updated silently |
