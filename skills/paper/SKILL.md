---
name: paper
description: Full academic paper pipeline — DOI or PDF path → Zotero import → markdown conversion → vault processing with cross-links
trigger: /paper
---

# /paper

One command to go from a DOI or PDF to a fully connected vault note with Zotero metadata.

## Usage

```
/paper 10.1039/D5SC01234A              # import by DOI
/paper ~/Downloads/halogenase_2026.pdf  # import from PDF
/paper                                  # pick from recent PDFs in ~/Downloads/
```

## What You Must Do When Invoked

Follow these steps in order. Do not skip steps.

### Step 1 — Determine the input type

Check what the user provided:

- **Looks like a DOI** (contains `10.` prefix, e.g. `10.1039/...`, `10.1021/...`): → DOI path
- **Looks like a file path** (ends in `.pdf` or is a path): → PDF path
- **Nothing provided**: list recent PDFs in ~/Downloads and ask the user to pick, or ask for a DOI

### Step 2A — DOI path: Import to Zotero first

```bash
zotero-cli import doi "<DOI>" --tag "from-paper-skill" --json 2>&1
```

This imports the paper with full metadata and triggers Zotero's "Find Available PDF" automatically.

Wait a moment for Zotero to fetch the PDF, then check:

```bash
ITEM_KEY=$(zotero-cli item find "<first few words of title>" --limit 1 --json 2>&1 | python3 -c "import sys,json; d=json.loads(sys.stdin.read()); print(d[0]['key'] if d else '')" 2>/dev/null)
echo "Item key: $ITEM_KEY"
```

Then check for attachments:

```bash
zotero-cli item attachments "$ITEM_KEY" --json 2>&1
```

If a PDF attachment exists, extract its path for Step 3. If no PDF was auto-fetched, note this and continue without PDF conversion — the Zotero entry still has full metadata.

### Step 2B — PDF path: Find or resolve the PDF

If a path was given, verify it exists. If no path was given, list recent PDFs:

```bash
ls -t ~/Downloads/*.pdf 2>/dev/null | head -10
```

Show them numbered and ask the user to pick.

Try to extract a DOI from the PDF content:

```bash
VAULT="__VAULT__"
TMPOUT=$(mktemp -d)
marker_single "<PDF_PATH>" --output_format markdown --disable_image_extraction --disable_multiprocessing --output_dir "$TMPOUT" 2>&1
```

Search the markdown output for a DOI pattern:

```bash
find "$TMPOUT" -name "*.md" -exec grep -oiE '10\.[0-9]{4,}/[^\s]+' {} \; | head -1
```

**If a DOI is found**, import to Zotero by DOI (which gets clean metadata):

```bash
zotero-cli import doi "<DOI>" --tag "from-paper-skill" --json 2>&1
```

Then attach the local PDF to the Zotero item:

```bash
ITEM_KEY=$(zotero-cli item find "<title>" --limit 1 --json 2>&1 | python3 -c "import sys,json; d=json.loads(sys.stdin.read()); print(d[0]['key'] if d else '')" 2>/dev/null)
if [ -n "$ITEM_KEY" ]; then
    zotero-cli item attach "$ITEM_KEY" "<PDF_PATH>" 2>&1
fi
```

**If no DOI found**, skip Zotero import for now but note it in the report.

### Step 3 — Convert PDF to markdown

If we have a PDF (from Step 2A's Zotero attachment or Step 2B's input):

```bash
VAULT="__VAULT__"
TMPOUT=$(mktemp -d)  # skip if already created in Step 2B
marker_single "<PDF_PATH>" --output_format markdown --disable_image_extraction --disable_multiprocessing --output_dir "$TMPOUT" 2>&1
```

Find and read the markdown output:

```bash
find "$TMPOUT" -name "*.md" -type f
```

### Step 4 — Extract metadata

From the markdown content and/or Zotero metadata, extract:
- **Title**
- **Authors**
- **Year**
- **Journal**
- **DOI**

If the item is in Zotero, prefer Zotero's metadata (it's cleaner):

```bash
zotero-cli item get "$ITEM_KEY" --json 2>&1
```

### Step 5 — Write to _INBOX/

Sanitize the title for a filename. Write to `$VAULT/_INBOX/<sanitized title>.md`:

```markdown
---
created: YYYY-MM-DD
tags:
  - source
  - paper
  - <topic-tags if obvious>
type: source
source_type: paper
status: unprocessed
authors: "<authors>"
journal: "<journal>"
year: <year>
doi: "<doi>"
zotero_key: "<ITEM_KEY>"
---

# <Paper Title>

**Authors:** <authors>
**Journal:** <journal> (<year>)
**DOI:** <doi>
**Original PDF:** [[<pdf filename>]]

---

<marker markdown output>
```

### Step 6 — Copy the PDF to vault

```bash
cp "<PDF_PATH>" "$VAULT/_INBOX/<sanitized title>.pdf"
```

### Step 7 — Clean up temp files

```bash
rm -rf "$TMPOUT"
```

### Step 8 — Report

Print:

```
Paper imported!
Title: <paper title>
Authors: <authors>
Zotero: <added by DOI / attached PDF / skipped (no DOI) / skipped (not running)>
Saved: _INBOX/<filename>.md + .pdf
Status: unprocessed — run /process to extract connections
```

Then ask: "Want me to run `/process` on this now?"

If the user says yes, invoke the `/process` skill on the file just created.

---

## Rules

- **Zotero is the source of truth for metadata** — if the paper is in Zotero, use Zotero's title/authors/year over anything extracted from the PDF
- **Don't block on Zotero** — if Zotero is not running or a command fails, continue the pipeline without it. Note what was skipped.
- **DOI import is preferred** — it gives the cleanest metadata. Always try to find a DOI even from PDFs.
- **Zero AI tokens for conversion** — marker runs locally
- **YAML frontmatter is required** — follow vault conventions
- **Don't summarize or analyze** — just import and convert. Analysis is /process's job
- **Copy the PDF, don't move it** — the user might want the original in Downloads
- **Check for duplicates** — before importing to Zotero, search for the title to avoid duplicates:
  ```bash
  zotero-cli item find "<title>" --limit 3 --json 2>&1
  ```
  If it already exists, skip the import and use the existing item key.
- **No em dashes or double-hyphen substitutes in output files.** Rewrite sentences to avoid them. Use colons, commas, periods, or parentheses instead.
