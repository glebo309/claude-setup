---
name: handoff
description: Use when the context window is full or the user wants to continue work in a fresh session. Generates a compact continuation prompt.
---

# /handoff

Generate a compact continuation prompt so a fresh context window can pick up exactly where this one left off.

## When Invoked

Review the full conversation and produce a handoff block. Print it inside a fenced code block (```markdown) so the user can copy-paste it into a new session.

## Output Format

The handoff prompt MUST follow this structure and MUST stay under 300 words total. Brevity is the entire point. No filler, no pleasantries.

```
---
Handoff from previous session (YYYY-MM-DD)

## Goal
One sentence: what we set out to do.

## Done
- Bullet per completed item. File paths where relevant.

## Open
- Bullet per unfinished item or known issue.

## Key Decisions
- Only non-obvious decisions that a fresh Claude would get wrong without knowing.
  Include the WHY, not just the WHAT.

## State
- Working directory, branch, running processes, dirty files.
- Only if relevant.

## Where to Look
- Point to files that hold rules or context (CLAUDE.md, memory files, config).
  NEVER repeat their content. Just name the file.

## Next Step
One sentence: the single most important thing to do next.
---
```

## Rules

1. **Under 300 words.** If you are over, cut. The user explicitly does not want a 20-page handoff.
2. **No repeating file contents.** Point to the file. A fresh session has access to the same filesystem and memory.
3. **No conversation replay.** Summarize outcomes, not the back-and-forth.
4. **Key Decisions only for surprising choices.** If a fresh Claude would naturally do the same thing, skip it.
5. **Omit empty sections.** If there is nothing open, drop "Open" entirely.
6. **Print as a copyable code block.** The user will paste this into a new `/chat` or session start.
7. **After printing the handoff, ask whether anything should be saved to memory.** Decisions, preferences, or project state that will matter beyond the next session belong in memory, not in the handoff. Offer to save them.
