# Recipe: Inbox Processor

**Pattern:** scheduled (weekly) | **Tokens:** HIGH (calls Claude Code)

A weekly script that processes files in `_INBOX/`: converts PDFs to markdown, classifies notes by domain, optionally creates `NOTES_` analysis files, and moves everything to the right folder.

---

## What It Does

1. **Convert** any PDFs in `_INBOX/` to markdown (zero tokens, uses pymupdf or marker)
2. **Collect** all markdown files in `_INBOX/` (excluding system files)
3. **Classify** each file using Claude: determine domain (_RESEARCH, _CREATIVE, _PERSONAL) and destination folder
4. **Search** the vault for connections (grep + existing knowledge)
5. **Create** a `NOTES_` analysis file for substantial sources
6. **Move** files to their destination (only when confident)
7. **Report** what was processed, what was left, and interesting connections found
8. **Commit** all changes to git

---

## Skeleton Script

```bash
#!/bin/zsh
set -euo pipefail

VAULT="$HOME/Documents/SecondBrain"
TODAY=$(date +%Y-%m-%d)
REPORT="$VAULT/_SYSTEM/WEEKLY_INBOX_REPORT.md"
LOG="$HOME/.claude/logs/monday-inbox-$TODAY.log"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG"; }
log "Starting inbox processor"

source "$HOME/.claude/scripts/notify.sh"

# --- Phase 1: Convert PDFs ---
PDF_COUNT=0
for pdf in "$VAULT/_INBOX"/*.pdf; do
    [[ -f "$pdf" ]] || continue
    BASENAME=$(basename "$pdf" .pdf)
    if [[ ! -f "$VAULT/_INBOX/$BASENAME.md" ]]; then
        log "Converting: $BASENAME.pdf"
        python3 -c "
import pymupdf
doc = pymupdf.open('$pdf')
pages = [page.get_text() for page in doc if page.get_text().strip()]
with open('$VAULT/_INBOX/$BASENAME.md', 'w') as f:
    f.write('\n\n---\n\n'.join(pages))
" 2>/dev/null && ((PDF_COUNT++)) || log "WARN: Failed to convert $BASENAME.pdf"
    fi
done
log "Converted $PDF_COUNT PDFs"

# --- Phase 2: Collect inbox files ---
INBOX_FILES=()
for f in "$VAULT/_INBOX"/*.md; do
    [[ -f "$f" ]] || continue
    BASENAME=$(basename "$f")
    # Skip system files
    [[ "$BASENAME" == "NOTES_"* ]] && continue
    [[ "$BASENAME" == "CLAUDE.md" ]] && continue
    INBOX_FILES+=("$f")
done

if [[ ${#INBOX_FILES[@]} -eq 0 ]]; then
    log "No files to process"
    echo "# Inbox Report $TODAY\n\nInbox empty. Nothing to process." > "$REPORT"
    exit 0
fi

log "Found ${#INBOX_FILES[@]} files to process"

# --- Phase 3: Claude classification ---
# Build a prompt with all file contents and let Claude classify

FILE_CONTENTS=""
for f in "${INBOX_FILES[@]}"; do
    BASENAME=$(basename "$f")
    CONTENT=$(head -100 "$f")
    FILE_CONTENTS="$FILE_CONTENTS\n\n=== FILE: $BASENAME ===\n$CONTENT"
done

PROMPT="You are processing the inbox of an Obsidian vault.

The vault has three domains:
- _RESEARCH/: science, academic work, papers
- _CREATIVE/: creative output, writing, projects
- _PERSONAL/: life management, hobbies, personal development

For each file below, determine:
1. Which domain it belongs to
2. The specific subfolder (e.g. _RESEARCH/Literature/, _PERSONAL/Sources/articles/)
3. Your confidence (high/medium/low)

Only suggest moves for high-confidence classifications.

FILES:
$FILE_CONTENTS

Output as a simple list:
FILENAME -> DESTINATION (confidence)"

CLASSIFICATION=$(echo "$PROMPT" | claude --print 2>/dev/null)

# --- Phase 4: Move files (high confidence only) ---
# Parse Claude's output and move files
# (Implementation depends on the output format)

# --- Phase 5: Write report ---
cat > "$REPORT" << EOF
---
updated: $TODAY
type: system
---
# Inbox Report $TODAY

PDFs converted: $PDF_COUNT
Files processed: ${#INBOX_FILES[@]}

## Classification Results
$CLASSIFICATION

EOF

# --- Phase 6: Git commit ---
cd "$VAULT"
git add -A 2>/dev/null
git commit -m "Inbox processed $TODAY" 2>/dev/null || true

notify "Inbox" "Processed ${#INBOX_FILES[@]} files" "Check WEEKLY_INBOX_REPORT" "default"
log "Done"
```

---

## Trigger Setup

**Monday 10:00 AM:** Use the scheduled pattern. See [scheduled.md](../patterns/scheduled.md).

---

## Customization Ideas

- Skip the Claude call for files with obvious domains (filename contains "paper", "recipe", etc.)
- Run the `/process` skill on substantial sources after filing
- Add a "leave in inbox" category for ambiguous files
- Send an email summary with the report highlights
