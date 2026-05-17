---
name: youtube
description: Pull a YouTube transcript and save it as a clean markdown file in the vault — zero AI tokens, just yt-dlp
trigger: /youtube
---

# /youtube

Grab a YouTube video's transcript and save it as a clean markdown file in the SecondBrain vault.

## Usage

```
/youtube <youtube-url>                          # save to _INBOX/
```

## What You Must Do When Invoked

### Step 1 — Extract the URL

Get the YouTube URL from the user's message. Accept any format:
- `https://www.youtube.com/watch?v=XXXXX`
- `https://youtu.be/XXXXX`
- Just the video ID

### Step 2 — Get video metadata

```bash
yt-dlp --print "%(title)s|||%(uploader)s|||%(upload_date)s|||%(duration_string)s|||%(description).200s" --no-download "URL"
```

Parse the output to get title, uploader, date, duration, and description snippet.

### Step 3 — Download transcript

Try auto-generated subtitles first, fall back to manual subs:

```bash
TMPDIR=$(mktemp -d)
yt-dlp --write-auto-sub --sub-lang "en.*" --skip-download --convert-subs srt -o "$TMPDIR/%(id)s" "URL" 2>&1
```

If that fails (no English subs), try without language filter:

```bash
yt-dlp --write-auto-sub --skip-download --convert-subs srt -o "$TMPDIR/%(id)s" "URL" 2>&1
```

If still no transcript available, tell the user and stop.

### Step 4 — Convert SRT to clean markdown

Read the .srt file and convert it to clean prose:

```bash
python3 -c "
import re, sys, glob

srt_files = glob.glob('$TMPDIR/*.srt')
if not srt_files:
    print('NO_SRT_FOUND')
    sys.exit(1)

with open(srt_files[0]) as f:
    content = f.read()

# Remove SRT formatting: sequence numbers, timestamps, positioning tags
lines = []
for line in content.split('\n'):
    line = line.strip()
    # Skip sequence numbers (just digits)
    if re.match(r'^\d+$', line):
        continue
    # Skip timestamp lines
    if re.match(r'\d{2}:\d{2}:\d{2}', line):
        continue
    # Remove HTML-like tags
    line = re.sub(r'<[^>]+>', '', line)
    # Skip empty lines
    if not line:
        continue
    lines.append(line)

# Deduplicate consecutive identical lines (SRT often repeats for overlap)
deduped = []
for line in lines:
    if not deduped or line != deduped[-1]:
        deduped.append(line)

# Join into paragraphs (break every ~5 sentences for readability)
text = ' '.join(deduped)
# Add paragraph breaks at natural points
text = re.sub(r'([.!?])\s+', r'\1\n\n', text)

print(text)
"
```

### Step 5 — Write the markdown file

Sanitize the video title for use as a filename (replace special characters with spaces, trim).

Always save to `_INBOX/` — filing to the correct domain folder is `/process`'s job (or the Monday automation).

Write to `VAULT/_INBOX/<sanitized title>.md`:

```markdown
---
created: YYYY-MM-DD
tags:
  - source
  - video
  - <domain-tag>
type: source
source_type: video
status: unprocessed
url: "<youtube-url>"
channel: "<uploader>"
duration: "<duration>"
---

# <Video Title>

**Channel:** <uploader>
**Date:** <upload date>
**Duration:** <duration>
**URL:** <youtube-url>

---

<transcript text>
```

### Step 7 — Clean up and report

```bash
rm -rf "$TMPDIR"
```

Print:

```
Saved: <destination>/<filename>.md
Duration: <duration> | Channel: <uploader>
Status: unprocessed — run /process to extract connections
```

### Step 8 — Offer to process

Ask: "Want me to run `/process` on this now?"

If yes, invoke the process-source skill on the newly created file.

---

## Rules

- **Zero AI tokens for the transcript itself** — yt-dlp pulls YouTube's existing captions
- **YAML frontmatter is required** — follow vault conventions
- **status: unprocessed** — marks it as ready for /process
- **Don't summarize or analyze** — just capture the raw transcript cleanly. Analysis is /process's job.
- **If no English transcript exists**, tell the user and suggest alternatives (manual paste, or whisper transcription if they want to spend tokens)
- **No em dashes or double-hyphen substitutes in output files.** Rewrite sentences to avoid them. Use colons, commas, periods, or parentheses instead.
