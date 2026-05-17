---
name: daily
description: Interactive response layer for the daily briefing. Talk back to the briefing to tick off tasks, answer questions, capture ideas, and plan the day.
trigger: /daily
---

# /daily

Your day dashboard. Respond to the morning briefing, tick things off, capture ideas, and come back anytime.

## Usage

```
/daily                             # open the briefing and wait for input
/daily dialysis is done, did it yesterday
/daily idea: maybe we should test carbamate at pH 7 too
/daily purification done, dialysis done, skipping synthese for now
```

Multiple invocations throughout the day are fine. Each one appends to the journal note.

## What You Must Do When Invoked

### Step 1 -- Load today's briefing

Read today's journal note. The path is always:

```
_PERSONAL/Journal/YYYY/YYYY-MM-DD.md
```

Use today's date. If the file does not exist, tell the user: "No briefing found for today. Run the briefing first or wait for tomorrow's."

Read the full note so you understand what was briefed (narrative, threads, deadlines).

### Step 2 -- Take free-form input

The user will speak naturally (often via voice transcription, so expect typos and messy input). They may say things like:

- "dialysis is done, did it yesterday"
- "purification also done"
- "skip the synthese question"
- "idea: what if we run the DMSO at lower concentration"
- "meeting with Fran at 2pm, she wants the HalB update by Friday"
- "I'll do the EP400 immobilization after lunch"

If the user invoked `/daily` with no arguments, read the briefing back to them as a short summary and ask: "What's the update?"

If arguments were provided, process them directly.

### Step 3 -- Parse intent and act

For each item the user mentions, determine the intent:

**Done items** (user says something is completed):
1. Find the matching `#due/YYYY-MM-DD` line in the SOURCE file (the thread file like `T_PAL_Amination.md`, not the briefing note)
2. Change `#due/YYYY-MM-DD` to `#done/YYYY-MM-DD` where the date is when it was actually done (use the date the user says, or today if not specified)
3. Tick the checkbox: `- [ ]` becomes `- [x]`
4. Log what you changed

**Skipped/deferred items** (user says to skip or carry forward):
- Do not change the source file
- Log that it was acknowledged but not acted on

**Ideas or notes** (user captures a thought):
- Log it in the journal note under Notes
- If the idea clearly belongs to a specific project, mention the relevant note in the log so links exist

**Plans or commitments** (user says they'll do something):
- Log what they committed to
- If it has a time, include it

**Answers to briefing questions** (the briefing asked "what is blocking X?"):
- Log the answer
- If the answer implies an action (e.g., "I'll email the editor today"), log that as a commitment

### Step 4 -- Suggest next steps

After processing all items, look at what remains undone from the briefing deadlines. Suggest what the natural next action is based on:
- What was just ticked off (what follows in the sequence?)
- What's due today or tomorrow
- What the user just said about their plans

Keep it to 1-2 sentences. Do not lecture or over-plan.

### Step 5 -- Append to journal note

Append a response block under the `*Notes:*` section in today's journal note (`_PERSONAL/Journal/YYYY/YYYY-MM-DD.md`).

**Important:** After writing to the journal note, copy the entire updated file to `Daily Briefing.md` in the vault root. The briefing routine places a copy there for quick access in Obsidian. Both files must stay in sync.

Format:

```markdown
Responded HH:MM

- Item description: what user said. #due/YYYY-MM-DD -> #done/YYYY-MM-DD in [[SourceFile]]
- Item description: skipped, carrying forward
- Idea: the idea as stated
- Plan: what user committed to

Next: one-line suggestion of the natural next action.
```

If this is not the first `/daily` invocation today, append a new `Responded HH:MM` block below the previous one. Do not overwrite earlier responses.

### Step 6 -- Report

Tell the user what was changed, briefly:

```
Ticked off 2 items in T_PAL_Amination. Logged 1 idea.
Next up: EP400 immobilization (due tomorrow).
```

Short. No summaries of what they just told you. They know what they said.

## Rules

- **Never edit the briefing narrative or deadlines section.** Only append under `*Notes:*`.
- **Always change #due to #done in the source file, not the briefing note.** The briefing note is a rendered view. The source files are the truth.
- **Use the date the task was actually done**, not today's date, when the user says "did it yesterday."
- **Handle messy voice input gracefully.** "purifcation done ysterday" means purification was done yesterday.
- **If you can't find the matching #due tag**, tell the user: "Could not find the #due tag for X in [[File]]. You may need to update it manually."
- **No em dashes or double-hyphen substitutes.**
- **No emojis.**
- **Multiple invocations per day are expected.** Each one appends, never overwrites.
- **If the user just says something like "all good" or "nothing to update"**, append a minimal note: `Responded HH:MM -- no updates` and move on.
- **Ideas go in the journal note only.** Do not create new files for spontaneous ideas. If the idea grows, the user will create a note later.
