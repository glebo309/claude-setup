---
name: process
description: Process raw source material (transcripts, PDFs, articles) into a connected NOTES_ file with cross-links to existing vault notes
trigger: /process
---

# /process

Turn raw source material into a richly connected `NOTES_` file that links to existing vault knowledge, explains WHY each idea matters, and surfaces non-obvious connections.

## Usage

```
/process                           # process the file currently being discussed
/process <path>                    # process a specific file
/process <path> --for <project>    # process with a specific project lens
```

## What You Must Do When Invoked

Follow these steps in order. Do not skip steps.

### Step 0 — Resolve the source file

If a path was given, use it. If not, check whether a file was referenced earlier in the conversation. If still unclear, ask: "Which source file should I process?"

Read the source file. If it doesn't exist, stop.

Determine the domain:
- File is under `_RESEARCH/` or is about science/enzymes/lab work → **research**
- File is under `_CREATIVE/` or relates to a creative project → **creative**
- File is under `_PERSONAL/` or is about personal development/hobbies → **personal**
- File is in `_INBOX/` or unclear → infer from content, ask if ambiguous

If `--for <project>` was given, that's the primary lens for relevance (e.g. `--for MyProject`, `--for ThesisWork`).

### Step 1 — Extract key concepts from the source

Read the full source. Extract 5-15 **atomic key ideas** — not a summary, but distinct claims, insights, methods, or frameworks the source introduces. For each, write one sentence capturing the core idea.

Also extract a flat list of **entity terms** (people, methods, enzymes, concepts, frameworks, tools) mentioned. You'll use these to search for connections.

### Step 1.5 — Source Credibility Gate (external sources only)

**Skip this step if the source is self-authored** (the user's own notes, journal entries, project files, or drafts). Only apply to external material: videos, podcasts, articles, books, papers, transcripts from other people.

How to detect: if the file has `source_type` frontmatter (video, podcast, article, book, paper), it's external. If it's a transcript of someone else talking, it's external. If it's the user's own writing or notes, skip to Step 2.

#### A. Source assessment

Determine in 2-3 sentences:
- **Source type:** peer-reviewed / academic book / popular science / journalism / opinion / promotional / YouTube-podcast / social media
- **Agenda:** informing / persuading / selling / exploring / promoting a worldview / entertainment
- **Epistemic standard:** Does the source make falsifiable claims? Cite evidence? Acknowledge limitations? Distinguish speculation from established fact?

#### B. Claim-level triage

For each of the 5-15 extracted key ideas, classify:

- **Substantiated claim** — backed by evidence, specific, testable or at least falsifiable. KEEP.
- **Reasonable speculation** — goes beyond the evidence but is grounded, acknowledges uncertainty. KEEP, but flag as speculative.
- **Hype or sensationalism** — vague, unfalsifiable, fear-based, or dramatic framing without substance ("will destroy humanity", "changes everything", "the ancients knew"). DROP or QUARANTINE.
- **Common knowledge repackaged** — nothing new, just restating widely known ideas with dramatic framing. DROP.

**Red flags that downgrade a claim:**
- Unfalsifiable predictions presented as certainty
- Misuse of scientific terminology or name-dropping (invoking researchers without engaging their actual arguments)
- Conflation of metaphor with mechanism
- Appeals to authority or antiquity as evidence
- "Quantum" invoked to explain anything outside actual physics
- Conspiracy framing or persecution narratives

#### C. Gate verdict

Based on the triage, assign an overall **source confidence**:

- **High** — peer-reviewed, evidence-based, engages counterarguments, acknowledges limitations
- **Medium** — has genuine insights but mixed with speculation or hype; worth extracting selectively
- **Low** — mostly hype, sensationalism, or unsupported claims; extract only the few grounded ideas (if any)
- **Reject** — no substantive content worth putting in the vault. Stop processing. Report: "Source rejected: [1-sentence reason]. No NOTES_ file created."

For **High** sources: proceed normally with all kept ideas.
For **Medium** sources: proceed only with ideas classified as "substantiated" or "reasonable speculation." Drop the rest.
For **Low** sources: proceed only with "substantiated" claims. If fewer than 2 survive, treat as Reject.

The surviving ideas carry forward into Steps 2-5. Dropped ideas do not appear in the NOTES_ file at all.

### Step 2 — Query the knowledge graph

Check if the vault knowledge graph exists:

```bash
VAULT="__VAULT__"
if [ -f "$VAULT/_INBOX/graphify-out/graph.json" ]; then
    echo "GRAPH_EXISTS=true"
else
    echo "GRAPH_EXISTS=false"
fi
```

**If the graph exists**, query it for each entity term to find connected nodes:

```bash
VAULT="__VAULT__"
python3 -c "
import json, sys
from pathlib import Path

data = json.loads(Path('$VAULT/_INBOX/graphify-out/graph.json').read_text())

# Build node lookup
nodes = {}
for n in data.get('nodes', []):
    nid = n.get('id', '')
    label = n.get('label', '')
    nodes[nid] = n

# Build adjacency from links
adj = {}
for link in data.get('links', []):
    src = link.get('source', '')
    tgt = link.get('target', '')
    if src not in adj: adj[src] = []
    if tgt not in adj: adj[tgt] = []
    adj[src].append((tgt, link))
    adj[tgt].append((src, link))

# Search for entity terms
terms = ENTITY_TERMS  # replace with actual list
results = []
for term in terms:
    t = term.lower()
    for nid, n in nodes.items():
        label = n.get('label', '').lower()
        if t in label or t in nid:
            neighbors = []
            for neighbor_id, edge in adj.get(nid, [])[:5]:
                if neighbor_id in nodes:
                    neighbors.append({
                        'label': nodes[neighbor_id].get('label', ''),
                        'source_file': nodes[neighbor_id].get('source_file', ''),
                        'relation': edge.get('relation', ''),
                    })
            results.append({
                'term': term,
                'node': n.get('label', ''),
                'source_file': n.get('source_file', ''),
                'neighbors': neighbors,
            })
            break  # first match per term

print(json.dumps(results, indent=2))
"
```

Replace `ENTITY_TERMS` with the actual Python list of extracted terms (e.g. `['biocatalysis', 'directed evolution', 'active site']`).

Record the graph hits — these are confirmed connections to existing vault knowledge.

**If the graph doesn't exist**, skip this step and rely on Step 3 alone.

### Step 3 — Search the vault for related notes

Search for each entity term across the vault to find existing notes that connect:

```bash
VAULT="__VAULT__"
for term in SEARCH_TERMS; do
    echo "=== $term ==="
    grep -ril "$term" "$VAULT/_RESEARCH" "$VAULT/_CREATIVE" "$VAULT/_PERSONAL" --include="*.md" 2>/dev/null | grep -v "graphify-out" | grep -v ".smart-env" | head -8
done
```

Replace `SEARCH_TERMS` with the 5-10 most distinctive terms from the source (not generic words like "the" or "method" — use specific concepts, names, techniques).

For each hit, read the first 30-50 lines to understand what it's about. Prioritize:
1. Notes that appear for multiple search terms (hub notes)
2. Notes in the same domain as the source
3. Project dashboards or overview notes
4. Notes that would surprise the user as a connection (cross-domain links)

Select the **top 5-8 most relevant existing notes** to reference in the output.

### Step 4 — Read the relevant notes

Read each of the top 5-8 notes you identified. Understand what they contain so you can write meaningful connections, not just filename links.

If `--for <project>` was given, also read that project's main overview/dashboard note to understand what's currently relevant there.

### Step 5 — Write the NOTES_ file

Determine the output path:
- The `NOTES_` file goes **next to the source file**
- Naming: `NOTES_<SourceFileName>.md` (without the source's extension)
- Example: source is `agentic OS.md` → output is `NOTES_agentic OS.md`

Write the file with this structure:

```markdown
---
created: YYYY-MM-DD
tags:
  - source
  - <domain-tag>
  - <content-tags from extraction>
type: source-notes
source: "[[<SourceFileName>]]"
status: processed
---

# <Source Title> — Key Connections

**One-line verdict:** <What this source is and the single most important takeaway for your work>

**Source confidence:** <High / Medium / Low> — <one sentence justifying the rating, e.g. "peer-reviewed enzyme study with robust controls" or "promotional YouTube video mixing valid observations with unsupported doom predictions">

(Omit the source confidence line for self-authored content.)

## Why This Matters

<2-4 sentences on why this source is relevant — not what it says, but why the user should care given their current projects and interests. Reference specific projects/notes.>

## Key Ideas

### 1. <Atomic idea title>

<1-2 sentence explanation of the idea>

**Connects to:** [[ExistingNote1]] — <one sentence explaining HOW this connects and what's new/different>
**Connects to:** [[ExistingNote2]] — <one sentence on the connection>

### 2. <Atomic idea title>

...

(Repeat for 5-15 key ideas. Each MUST have at least one "Connects to" line. If an idea has no vault connection, say "**New territory** — no existing vault notes cover this. Consider starting a note in <suggested location>.")

## Connection Map

| This source says... | ...which links to | Because |
|---|---|---|
| <claim/idea> | [[Note]] | <why the connection matters> |
| <claim/idea> | [[Note]] | <why the connection matters> |
| ... | ... | ... |

## Cross-Domain Bridges

<List any surprising connections that cross domain boundaries — e.g., a personal development concept that maps to a research method, or a creative idea that connects to a work problem. These are the highest-value insights. If none exist, omit this section.>

## Open Questions

<1-3 questions this source raises that aren't answered in the vault. These are prompts for future exploration.>
```

### Step 6 — Move to the right location (if source is in _INBOX)

If the source file is currently in `_INBOX/`, **move it and its NOTES_ file** to the correct domain folder. Don't just suggest — actually move.

Determine destination using the vault's decision rule and the source's `source_type` frontmatter (if present):

| Content about... | source_type | Move to... |
|---|---|---|
| Work / research / professional | paper | `_WORK/Literature/` or `_RESEARCH/Literature/` |
| Work / research / professional | video/podcast/book | `_WORK/Sources/{type}/` or `_RESEARCH/Sources/{type}/` |
| Creative projects | any | The relevant project folder under `_CREATIVE/` |
| Personal dev, hobbies, life | video/podcast | `_PERSONAL/Sources/video_&_podcasts/` |
| Personal dev, hobbies, life | book | `_PERSONAL/Sources/books/` |
| Personal dev, hobbies, life | article | `_PERSONAL/Sources/articles_&_websites/` |
| Unclear / multi-domain | any | `_PERSONAL/Sources/{type}/` (safe default) |

Adapt folder names to the user's actual vault structure. Read the vault CLAUDE.md to learn the domain folders.

Create destination directory if it doesn't exist. Move both files:

```bash
VAULT="__VAULT__"
mkdir -p "$VAULT/<destination>"
mv "$VAULT/_INBOX/<source file>" "$VAULT/<destination>/<source file>"
mv "$VAULT/_INBOX/NOTES_<source file>" "$VAULT/<destination>/NOTES_<source file>"
```

Update the NOTES_ file's `source` frontmatter field to use the new filename (wikilink stays the same since Obsidian resolves by filename, not path).

### Step 7 — Report

Print a concise summary:

```
Processed: <source name>
Source confidence: <High / Medium / Low / Reject> (omit for self-authored)
Ideas extracted: N total, M kept, K dropped (omit for self-authored)
Output: <NOTES_ file path> (or "None — source rejected" if Reject)
Moved to: <destination folder> (if was in _INBOX/)
Connections found: N existing notes linked
Key bridge: <the single most interesting cross-connection>
```

---

## Rules

- **Never just summarize.** Every section must explain WHY something matters or HOW it connects. If you catch yourself writing a summary paragraph, stop and rewrite as connections.
- **Every key idea must link to something.** Either an existing note (with explanation) or flagged as new territory with a suggested home.
- **Use `[[wikilinks]]`** — Obsidian format, filename only (not `[[folder/file]]`).
- **YAML frontmatter is required** — follow the vault standard (created, tags, type).
- **`NOTES_` prefix** — always. This is how the vault distinguishes AI-generated analysis from source material.
- **Be specific in connections** — "relates to [[MyProject]]" is useless. "This approach parallels the strategy in [[MyProject]] but uses computational pre-filtering instead of manual selection" is useful.
- **Cross-domain connections are gold** — if a personal development concept maps to a research methodology, or a philosophy framework illuminates a scientific problem, always highlight it.
- **Don't invent connections** — if the link is tenuous, say so. "Weak connection:" is fine. Fake connections waste time.
- **Respect the source's actual content** — don't project ideas onto it. Extract what's there, then connect it.
- **No em dashes or double-hyphen substitutes in output files.** Rewrite sentences to avoid them. Use colons, commas, periods, or parentheses instead.
- **Never make bad sources look good.** The credibility gate exists to protect vault quality. If a source is mostly hype, the NOTES_ file should reflect that honestly. Do not spin low-quality claims into impressive-sounding connections. A short, honest NOTES_ file beats a long, flattering one.
- **Connections must survive the credibility gate.** Only ideas that passed the triage in Step 1.5 get "Connects to" lines. Do not connect dropped claims to vault notes just because a keyword matches.
- **Self-authored content is trusted.** The user's own notes, drafts, and project files skip the credibility gate entirely. The filter is for external material only.
