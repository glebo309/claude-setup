---
name: website
description: Scrape a web page to clean markdown and drop it in _INBOX/ ready for processing, using webclaw CLI
trigger: /website
---

# /website

Scrape a web page into clean vault-ready markdown using the webclaw CLI tool.

## Usage

```
/website <url>                        # scrape to _INBOX/
/website <url> --domain research      # tag with domain (research/creative/personal)
```

## What You Must Do When Invoked

### Step 1 — Extract the URL

Get the URL from the user's message. Accept any format:
- Full URL with protocol: `https://example.com/page`
- Without protocol: `example.com/page` (prepend `https://`)
- URL in quotes or angle brackets

If no URL was given, ask: "Which URL should I scrape?"

### Step 2 — Scrape with webclaw CLI

Use webclaw via Bash to fetch the page as clean markdown:

```bash
webclaw "<URL>" -f markdown
```

To also extract image URLs from the page (for when the user wants images):

```bash
webclaw "<URL>" -f html | grep -oP '(?:src|data-src)="(https://[^"]+\.(?:jpg|jpeg|png|gif|webp|svg))"' | sort -u
```

Download images with curl into an `attachments/` subfolder next to the output file.

If webclaw returns an error (blocked, timeout, DNS failure), tell the user and suggest alternatives (try again, paste the content manually, or use a different URL).

### Step 3 — Extract metadata

From the webclaw output, extract:
- **Title** — the page's `<title>` or first `# heading` in the markdown
- **Site name** — extract domain from URL (e.g., `nature.com`, `arxiv.org`)
- **Date** — if visible in the page content (publication date, "posted on", etc.). Otherwise omit.
- **Author** — if visible. Otherwise omit.

If the title is unclear or missing, derive it from the URL path (e.g., `/blog/my-cool-post` becomes "My Cool Post").

### Step 4 — Determine domain tag

If `--domain` was given, use it. Otherwise infer:
- URLs from academic publishers (nature.com, sciencedirect.com, pubs.acs.org, arxiv.org, biorxiv.org, pubmed, wiley, springer, mdpi, rsc.org) → `research`
- Otherwise → leave the domain tag out and let the user decide during `/process`

### Step 5 — Determine source_type

Classify the page:
- Academic publisher or preprint server → `paper`
- Blog post, news article, magazine → `article`
- Documentation, wiki, reference page → `reference`
- Forum, discussion thread → `discussion`
- Default → `article`

### Step 6 — Write to _INBOX/

Sanitize the title for a filename: replace special characters with hyphens, trim, truncate to 80 characters.

Write to `$VAULT/_INBOX/<sanitized-title>.md`:

```markdown
---
created: YYYY-MM-DD
tags:
  - source
  - <source_type>
  - <domain-tag if determined>
type: source
source_type: <source_type>
status: unprocessed
url: "<original URL>"
site: "<domain>"
author: "<author if found>"
date: "<publication date if found>"
---

# <Page Title>

**Source:** <site name>
**URL:** <original URL>
**Author:** <author if found>
**Date:** <date if found>

---

<webclaw markdown output>
```

Omit the `author` and `date` fields entirely (from both frontmatter and header) if they were not found. Do not leave empty fields.

### Step 7 — Report

Print:

```
Saved: _INBOX/<filename>.md
Title: <page title>
Site: <domain>
Type: <source_type>
Status: unprocessed — run /process to extract connections
```

### Step 8 — Offer to process

Ask: "Want me to run `/process` on this now?"

If yes, invoke the process skill on the newly created file.

---

## Rules

- **YAML frontmatter is required** — follow vault conventions
- **status: unprocessed** — marks it as ready for /process
- **Don't summarize or analyze** — just capture the page cleanly. Analysis is /process's job.
- **Strip navigation, headers, footers, cookie banners** — webclaw handles most of this, but if obvious site chrome leaks through, remove it manually
- **No em dashes or double-hyphen substitutes in output files.** Rewrite sentences to avoid them. Use colons, commas, periods, or parentheses instead.
- **webclaw is a CLI tool** at `/opt/homebrew/bin/webclaw`. Run it via Bash, not as an MCP server.
- **If webclaw is not installed**, tell the user and suggest `brew install webclaw` or check the webclaw docs.
- **One page at a time** — this skill scrapes a single URL. For multi-page crawls, the user should run it multiple times or wait for a future `/crawl` skill.
