---
name: ask
description: Use when a request is ambiguous, complex, or could be interpreted multiple ways. Stops guessing by forcing structured clarifying questions before any action. Invoke before planning or implementation.
---

# /ask

Stop guessing. Ask until you know.

## When to Use

- User's request could be interpreted multiple ways
- You're about to make assumptions about scope, format, location, or intent
- Complex task where getting it wrong wastes significant tokens
- User invokes `/ask` explicitly

## When NOT to Use

- Request is unambiguous and specific ("rename X to Y", "fix the typo on line 30")
- You're mid-execution and the user gave clear follow-up instructions

## The Rules

**You are in question-only mode. No edits. No code. No file creation. No tool calls that change state. Only reading, searching, and asking.**

1. **Max 3 questions per round.** Never dump a wall of questions. Short rounds, fast feedback.
2. **Ask what you can't answer yourself.** Before asking, check if the codebase, vault, git history, or conversation already answers it. If it does, state what you found instead of asking.
3. **Prioritize in this order:**
   - **Why** (what's the goal behind the request?)
   - **What success looks like** (how will they know it's right?)
   - **Constraints** (what must it NOT do, where must it NOT go?)
   - **Specifics** (format, location, naming, scope)
4. **State assumptions explicitly.** Don't hide them in questions. Say "I'm assuming X, is that right?" so the user can correct you.
5. **After each round, summarize** what you now understand in 1-2 sentences before asking the next round.

## The Flow

```
User request arrives
       |
  Can I answer with zero ambiguity?
      / \
    yes   no
     |     |
  Just   Enter /ask mode
  do it    |
           |
     Round 1: Why + success criteria
           |
     Round 2: Constraints + specifics (if needed)
           |
     Round 3+: Edge cases (only if still unclear)
           |
     Output the brief
           |
     User confirms or corrects
           |
     Exit /ask mode, execute
```

## The Brief

When you have enough understanding, output a brief in this format:

```
WHAT: [one sentence, what you will do]
WHY: [one sentence, the goal behind it]
WHERE: [files/locations affected]
HOW: [approach in 2-3 bullets max]
NOT: [what you will explicitly avoid]
```

Then ask: "Good to go, or anything to change?"

Only proceed after explicit confirmation.

## Red Flags (you're doing it wrong)

- Asking more than 3 questions at once
- Asking something you could find by reading a file
- Asking about implementation details before understanding intent
- Skipping the brief and jumping to execution
- Producing any code or edits while still in /ask mode

## Examples

**Bad (guessing):**
User: "Add a tracker for my experiments"
Claude: *immediately creates a markdown file with a table and YAML frontmatter*

**Good (/ask mode):**
User: "/ask add a tracker for my projects"
Claude: "A few things before I build this:
1. Which projects: all active ones, or specific ones?
2. What do you want to track per project: dates, milestones, status, notes?
3. Should this live as a note in the project folder, or as a new dashboard view?"
