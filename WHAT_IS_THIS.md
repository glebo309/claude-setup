# AI Chat vs AI Agent vs AI Harness

Three levels of AI integration, each building on the last.

---

## Level 0: AI Chat

**What it is:** You type, it replies. Conversation dies when you close the tab.

**Examples:** ChatGPT, Claude.ai, Gemini web

**What it can do:**
- Answer questions
- Write text
- Brainstorm

**What it cannot do:**
- Read your files
- Run code
- Remember anything between sessions
- Take actions on your behalf

**Mental model:** A very smart person on the other end of a text box.

---

## Level 1: AI Agent

**What it is:** An AI that can use tools. It reads files, runs code, searches the web, edits your projects, and executes multi-step tasks autonomously.

**Examples:** Claude Code, Cursor, Windsurf, GitHub Copilot agent mode

**What it can do:**
- Everything a chat can do, plus:
- Read and write files on your machine
- Run shell commands
- Use external tools (git, npm, python, etc.)
- Break complex tasks into steps and execute them
- Remember context within a session

**What it cannot do:**
- Act when you are not there
- Run scheduled tasks
- Maintain knowledge across sessions (without explicit memory)
- Integrate with your broader workflow

**Mental model:** A very capable intern sitting at your computer. They can do real work, but only when you are watching and telling them what to do.

---

## Level 2: AI Harness

**What it is:** An agent embedded into your complete system: persistent memory, scheduled automations, hooks that fire on events, a knowledge vault it reads and writes to, and tools that extend its reach. The agent does not just answer; it runs your workflow.

**What makes it different:**

| Capability | Chat | Agent | Harness |
|---|---|---|---|
| Answers questions | yes | yes | yes |
| Reads/writes files | no | yes | yes |
| Runs code | no | yes | yes |
| Remembers across sessions | no | limited | yes (memory system) |
| Custom skills/commands | no | no | yes (/paper, /process, etc.) |
| Fires on schedule | no | no | yes (morning briefing, weekly review) |
| Reacts to events | no | no | yes (file changes, screen wake) |
| Integrates with other tools | no | limited | yes (Obsidian, Zotero, git, notifications) |
| Works while you sleep | no | no | yes |

**The components:**

1. **The Agent** (Claude Code): reads files, runs commands, edits your work
2. **The Vault** (Obsidian): your knowledge base, organized by life domain, with conventions the agent understands
3. **Skills** (custom commands): one-word triggers for complex workflows (/paper, /process, /export)
4. **Memory** (persistent files): the agent remembers your preferences, your projects, your feedback across sessions
5. **Hooks** (event-driven): things that happen automatically when certain conditions are met (file saved, tool used)
6. **Automations** (scheduled): scripts that run on a timer or on events (laptop wake, Monday morning, file change)
7. **MCP Servers** (tool bridges): connectors that let the agent talk directly to Obsidian, web scrapers, and other tools

**Mental model:** Not an intern. A system. The agent is the brain, the vault is the memory, the automations are the habits, and the hooks are the reflexes. You configure it once, and it works with you continuously.

---

## What This Repo Sets Up

This repo takes you from zero to a full harness in three levels:

- **Level 0:** Install the agent (Claude Code) and wire it into your browser as a sidebar terminal. After this, you have a working AI agent accessible from any tab.

- **Level 1:** Configure the agent with your identity, your vault, your skills, and your tools. After this, the agent knows who you are, understands your file system, and can run custom commands.

- **Level 2:** Learn the automation patterns (scheduled tasks, wake triggers, file watchers) and build your own. After this, the agent works even when you are not at the keyboard.

Each level is self-contained. You can stop at any level and have a useful system.
