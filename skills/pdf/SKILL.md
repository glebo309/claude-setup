---
name: pdf
description: Convert any PDF to markdown and drop it in _INBOX/ ready for processing — zero tokens, uses pymupdf locally
trigger: /pdf
---

# /pdf

Convert a PDF to clean markdown and save it in the SecondBrain vault inbox.

## Usage

```
/pdf                                  # pick from recent PDFs in ~/Downloads/
/pdf <path-to-pdf>                    # convert a specific PDF
/pdf <path-to-pdf> --pages 1-10       # convert only specific pages
/pdf <path-to-pdf> --ocr              # force OCR (for scanned documents only)
```

## What You Must Do When Invoked

### Step 1 — Find the PDF

If a path was given, use it.

If no path was given, list the 10 most recent PDFs in `~/Downloads/`:

```bash
ls -t ~/Downloads/*.pdf 2>/dev/null | head -10
```

Show them numbered and ask the user to pick one. If no PDFs found, ask for a path.

### Step 2 — Convert with pymupdf (default) or marker (OCR fallback)

**Default: text-layer extraction (fast, seconds not minutes)**

```python
python3 << 'EOF'
import pymupdf
import sys

pdf_path = "<PDF_PATH>"
doc = pymupdf.open(pdf_path)

pages = []
for i, page in enumerate(doc):
    text = page.get_text()
    if text.strip():
        pages.append(text)

# Check if extraction yielded meaningful text
if len(pages) < len(doc) * 0.5 or sum(len(p) for p in pages) < 1000:
    print("WARNING: PDF appears to be scanned/image-based. Re-run with --ocr flag.")
    sys.exit(1)

full_text = "\n\n---\n\n".join(pages)
with open('/tmp/pdf_skill_output.md', 'w') as f:
    f.write(full_text)
print(f"Done: {len(doc)} pages, {len(full_text)} characters")
EOF
```

If `--pages` was given, filter the page range in the loop (e.g., `for i in range(start, end)`).

**OCR fallback (only if --ocr flag given OR text extraction fails):**

```bash
VAULT="__VAULT__"
TMPOUT=$(mktemp -d)
marker_single "<PDF_PATH>" --output_format markdown --disable_image_extraction --disable_multiprocessing --output_dir "$TMPOUT" 2>&1
find "$TMPOUT" -name "*.md" -type f
```

If marker is too slow (large documents), suggest the user try `pdftotext` as a last resort.

### Step 3 — Read the output

Read `/tmp/pdf_skill_output.md` (or the marker output if OCR was used).

### Step 4 — Extract metadata

Try to extract from the markdown content:
- **Title** — usually the first heading or large text
- **Authors** — look near the top, after title
- **Year** — look for publication date, or fall back to the PDF filename
- **Journal** — if visible in header/footer

If metadata is unclear, use the PDF filename as the title and ask the user to fill in details later.

### Step 5 — Write to _INBOX/

Sanitize the title for a filename. Write to `$VAULT/_INBOX/<sanitized title>.md`:

```markdown
---
created: YYYY-MM-DD
tags:
  - source
  - paper
  - <topic-tags if obvious from title>
type: source
source_type: paper
status: unprocessed
authors: "<authors>"
journal: "<journal>"
year: <year>
---

# <Paper Title>

**Authors:** <authors>
**Journal:** <journal> (<year>)
**Original PDF:** [[<pdf filename>]]

---

<marker markdown output>
```

### Step 6 — Add to Zotero (if academic paper)

If the extracted metadata suggests an academic paper (has authors AND either a DOI, journal, or looks like a research article), add it to Zotero:

**If a DOI was found in the PDF content or metadata:**

```bash
zotero-cli import doi "<DOI>" --tag "from-pdf-skill" 2>&1
```

Then attach the PDF to the newly created item:

```bash
# Find the item we just imported
ITEM_KEY=$(zotero-cli item find "<paper title>" --limit 1 --json 2>&1 | python3 -c "import sys,json; print(json.loads(sys.stdin.read())[0]['key'])" 2>/dev/null)
if [ -n "$ITEM_KEY" ]; then
    zotero-cli item attach "$ITEM_KEY" "<PDF_PATH>" 2>&1
fi
```

**If no DOI was found**, still try to search Zotero for the title to avoid duplicates. If not already in Zotero, note this in the report so the user can add it manually.

If Zotero is not running or the command fails, skip silently — don't block the main workflow. Just note "Zotero: skipped (not running)" in the report.

### Step 7 — Copy the original PDF

Copy (not move) the PDF to the vault so it lives next to the markdown:

```bash
cp "<PDF_PATH>" "$VAULT/_INBOX/<sanitized title>.pdf"
```

### Step 8 — Clean up and report

```bash
rm -rf "$TMPOUT"
```

Print:

```
Saved: _INBOX/<filename>.md + .pdf
Title: <paper title>
Authors: <authors>
Zotero: <added by DOI / already exists / skipped (no DOI) / skipped (not running)>
Status: unprocessed — run /process to extract connections
```

Then ask: "Want me to run `/process` on this now?"

---

## Rules

- **Zero AI tokens for conversion** — pymupdf/marker run locally
- **pymupdf is the default** — it extracts the text layer directly (instant). Only use marker (OCR) for scanned documents or when pymupdf yields empty/garbled output
- **YAML frontmatter is required** — follow vault conventions
- **status: unprocessed** — marks it as ready for /process
- **Don't summarize or analyze** — just convert cleanly. Analysis is /process's job
- **Copy the PDF, don't move it** — the user might want the original in Downloads too
- **If pymupdf yields little text**, warn the user and suggest `--ocr` flag
- **No em dashes or double-hyphen substitutes in output files.** Rewrite sentences to avoid them. Use colons, commas, periods, or parentheses instead.
