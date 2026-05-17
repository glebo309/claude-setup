# Pattern: Chained

One automation calls another. The first script finishes its main work, then launches a second script.

---

## When to Use

- A morning briefing that also runs a "daily lesson" step
- A weekly processor that triggers a notification after filing
- Any workflow where Step B only makes sense after Step A completes

## How It Works

This is not a special mechanism. It is just one script calling another.

```bash
#!/bin/zsh
# main-automation.sh

# Phase 1: Do the main work
echo "[$(date)] Starting main work..."
# ... your main logic ...

# Phase 2: Chain to the next script
echo "[$(date)] Chaining to secondary task..."
/bin/zsh "$HOME/.claude/scripts/secondary-task.sh" &

echo "[$(date)] Done."
```

**Key points:**

- Use `&` (background) if the chained script is independent and the main script should not wait
- Omit `&` if the main script needs the chained script to finish first
- Pass context via arguments or environment variables:

```bash
# Pass today's date and a file path to the chained script
RESULT_FILE="/tmp/main-result.md"
/bin/zsh "$HOME/.claude/scripts/secondary-task.sh" "$TODAY" "$RESULT_FILE" &
```

## Guards

The chained script should check whether it actually needs to run:

```bash
#!/bin/zsh
# secondary-task.sh

# Only run if the main work produced output
RESULT_FILE="${2:-}"
if [[ ! -f "$RESULT_FILE" ]]; then
    echo "[$(date)] No result file found, skipping."
    exit 0
fi

# Do the work
```

## Error Handling

If the chained script fails, it should not bring down the main automation:

```bash
# Fire and forget (errors logged but don't affect main)
/bin/zsh "$HOME/.claude/scripts/secondary-task.sh" >> "$LOG" 2>&1 &

# Or: run but catch failure
if ! /bin/zsh "$HOME/.claude/scripts/secondary-task.sh" 2>&1; then
    echo "[$(date)] WARNING: secondary task failed" >> "$LOG"
fi
```

---

## Tips

- Keep chains shallow. A calls B is fine. A calls B calls C calls D is a debugging nightmare.
- Each script in the chain should be independently runnable and testable.
- Log from every script in the chain so you can trace execution across scripts.
