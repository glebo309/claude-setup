---
name: export
description: Export vault markdown to Word (.docx) or LaTeX (.tex) using pandoc with preset templates
trigger: /export
---

# /export

Export markdown files to Word or LaTeX using pandoc with customizable reference templates.

## Usage

```
/export                                    # export the file currently being discussed
/export <path>                             # export a specific file
/export <path> --to docx                   # explicit Word output (default)
/export <path> --to tex                    # LaTeX output (for Overleaf)
/export <path> --template chemsci          # use ChemSci reference doc
/export <path> --template general          # use general reference doc
```

## What You Must Do When Invoked

### Step 0 — Resolve the source file

If a path was given, use it. If not, check whether a file was referenced earlier in the conversation. If still unclear, ask: "Which file should I export?"

Read the file. If it doesn't exist, stop.

### Step 1 — Determine output format

- Default: `.docx` (Word)
- If `--to tex` was given: `.tex` (LaTeX)
- If the user mentions "Overleaf", "LaTeX", or "philosophy": default to `.tex`
- If the user mentions "Word", "doc", "ChemSci", "RSC", "journal submission": default to `.docx`

### Step 2 — Select the template

Templates live in: `$VAULT/_SYSTEM/Templates/pandoc/`

Available reference documents:

| Template name | File | Best for |
|---|---|---|
| `chemsci` | `reference-chemsci.docx` | RSC journal submissions (Chemical Science, etc.) |
| `general` | `reference-general.docx` | General-purpose academic documents |
| `default` | `reference-default.docx` | Pandoc's default styling |

If `--template` was given, use that template. Otherwise:
- If the file path contains "ChemSci" or "RSC" → use `chemsci`
- Otherwise → use `general`

### Step 3 — Handle bibliography (if present)

Check if the markdown frontmatter has a `bibliography` field, or if there's a `.bib` file nearby:

```bash
VAULT="__VAULT__"
SOURCE_DIR=$(dirname "<SOURCE_PATH>")
# Check for bib files near the source
ls "$SOURCE_DIR"/*.bib 2>/dev/null
# Check vault-wide bib file
ls "$VAULT/_SYSTEM/Templates/pandoc"/*.bib 2>/dev/null
```

If a `.bib` file exists, add `--bibliography <bib_file>` and optionally `--csl <csl_file>` to the pandoc command.

### Step 4 — Export

```bash
VAULT="__VAULT__"
TEMPLATE_DIR="$VAULT/_SYSTEM/Templates/pandoc"
SOURCE="<SOURCE_PATH>"
BASENAME=$(basename "$SOURCE" .md)
OUTPUT_DIR=$(dirname "$SOURCE")
```

**For Word (.docx):**

```bash
pandoc "$SOURCE" \
  --reference-doc="$TEMPLATE_DIR/reference-<template>.docx" \
  --from markdown \
  --to docx \
  -o "$OUTPUT_DIR/$BASENAME.docx" \
  2>&1
```

**For LaTeX (.tex):**

```bash
pandoc "$SOURCE" \
  --from markdown \
  --to latex \
  --standalone \
  -o "$OUTPUT_DIR/$BASENAME.tex" \
  2>&1
```

If bibliography flags apply, add them to the command.

### Step 5 — Report

```
Exported: <output filename>
Location: <full path>
Template: <template name>
Format: <docx/tex>
```

If `.tex` was generated, add: "Ready to paste into Overleaf or compile locally."
If `.docx` was generated, add: "Open with Word or upload to Google Docs."

---

## Customizing templates

To customize a template, tell the user:

1. Open `_SYSTEM/Templates/pandoc/reference-<name>.docx` in Word
2. Modify the styles (Heading 1, Heading 2, Normal, etc.) — don't change the text content, just the styles
3. Save and close
4. Next `/export` will use the updated styles

To create a new template:

```bash
cp "$VAULT/_SYSTEM/Templates/pandoc/reference-default.docx" "$VAULT/_SYSTEM/Templates/pandoc/reference-<newname>.docx"
```

Then customize in Word.

## Rules

- **Template styles only** — pandoc uses the styles from the reference doc, not the content. The content comes from the markdown.
- **Don't modify the source** — export is read-only on the markdown.
- **Output goes next to the source** — unless the user specifies otherwise.
- **Bibliography is optional** — only add `--bibliography` if a `.bib` file actually exists.
- **If pandoc fails**, show the error and suggest fixes (usually missing YAML frontmatter or bad markdown syntax).
- **No em dashes or double-hyphen substitutes in output files.** Rewrite sentences to avoid them. Use colons, commas, periods, or parentheses instead.
