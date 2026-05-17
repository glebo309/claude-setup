---
name: vault-sync
description: End-of-conversation flush. Persist all decisions, results, and tasks from the current chat into the vault so nothing is lost when the window closes.
trigger: /vault-sync
---

# /update

Vault sync before closing the chat. Makes sure everything discussed is stored in the right files so the user can close the window without losing information.

## When to use

- End of a conversation
- After a block of work that touched multiple topics
- Whenever the user is unsure if things were saved

Takes no arguments. Reads the conversation itself.

## What You Must Do When Invoked

### Step 1 -- Audit the conversation

Review the ENTIRE conversation from the beginning. For every topic discussed, classify it:

**Done items**: things the user said they completed, or that you confirmed as done.
**New tasks**: commitments with dates that should become `- [ ] task #due/YYYY-MM-DD` lines.
**Decisions**: choices made (e.g. "we will use DMSO not 2-MeTHF", "Anthropic pitch paused").
**Results**: experimental data, analysis outcomes, findings worth recording.
**Ideas**: thoughts captured in passing that belong somewhere.
**Status changes**: threads that moved (e.g. active -> complete, someday -> active).

### Step 2 -- Check what is already persisted

For each item from Step 1, check whether it is ALREADY in the vault. Read the relevant files. Things that are already stored need no action.

This step is critical. The user often does persist things during the conversation, or `/daily` already handled some items. Do not duplicate work.

Build two lists:
- **Already stored**: items confirmed present in the vault (file + line if possible)
- **Needs action**: items not yet persisted

### Step 3 -- Persist what is missing

For each item in "Needs action":

**Done items**:
1. Find the matching `#due/YYYY-MM-DD` line in the source thread file
2. Change `#due/YYYY-MM-DD` to `#done/YYYY-MM-DD` (use the date the task was actually done)
3. Tick the checkbox: `- [ ]` becomes `- [x]`

**New tasks**:
1. Find the correct thread file (T_ file). If no thread exists and the task is substantial, ask the user before creating one.
2. Append `- [ ] task description #due/YYYY-MM-DD` under the Tasks section
3. If no date was discussed, do NOT invent one. Add the task without a #due tag.

**Decisions and results**:
1. Find the most relevant existing note for the topic
2. Append a dated section:
   ```
   ## YYYY-MM-DD
   
   The content here.
   ```
3. If appending to a thread file, put it under the Status section or a relevant subsection, not under Tasks.
4. Use wikilinks to connect to related notes where natural.

**Ideas**:
1. If today's journal note exists, append under `*Notes:*`
2. If no journal note, append to the most relevant project note with a dated section

**Status changes**:
1. Update the `status:` field in the thread file's frontmatter

### Step 4 -- Sync surface files

If any of these files were touched:
- Today's journal note (`_PERSONAL/Journal/YYYY/YYYY-MM-DD.md`): copy the updated file to `Daily Briefing.md` in the vault root

### Step 5 -- Report

Output a concise report in this format:

```
Already stored:
- [item]: in [[File]] (line N)
- [item]: in [[File]]

Updated:
- Ticked off [item] in [[File]]
- Added task [item] to [[File]]
- Appended [results/decision] to [[File]]
- Changed status to [X] in [[File]]

Nothing to do:
- (if everything was already persisted, say so)
```

If everything was already stored, say: "Everything from this conversation is already in the vault. Safe to close."

If there were updates, end with: "Vault is current. Safe to close."

## Rules

- **Never create new notes unless the user explicitly asks.** Always append to existing files.
- **Never duplicate what /daily already handled.** If `/daily` was invoked in this conversation and already persisted an item, skip it.
- **Use the actual completion date**, not today, when the user said "did it yesterday" or similar.
- **No emojis. No em dashes or double-hyphen substitutes.**
- **Vault conventions**: wikilinks (`[[NoteName]]`), ISO dates, YAML frontmatter on any new file.
- **Do not invent tags** that do not already exist in the vault.
- **Do not commit to git.** The user or an automation handles that.
- **If you cannot find the right file for an item**, tell the user: "Could not find the right home for [item]. Where should it go?"
- **Read before writing.** Always read a file before editing it.
- **Be thorough but not noisy.** Check every topic from the conversation, but only report items that matter. "We discussed the weather" is not an item.
