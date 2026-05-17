#!/bin/zsh
# Shared notification helper for automations.
# Usage: source notify.sh; notify "Title" "Subtitle" "Message" ["sound"] ["email_html"]
#
# Sends both:
#   1. macOS notification via terminal-notifier (short message)
#   2. Email via Resend API (HTML if provided, otherwise wraps message in minimal HTML)

NOTIFY_EMAIL="__EMAIL__"
NOTIFIER="/opt/homebrew/bin/terminal-notifier"
RESEND_KEY=$(/bin/cat "$HOME/.claude/.resend-key" 2>/dev/null)

_email_wrap() {
    local subtitle="$1"
    local body="$2"
    /bin/cat <<HTMLEOF
<!DOCTYPE html>
<html><head><meta charset="utf-8"></head>
<body style="margin:0;padding:40px 20px;background:#f5f5f5;font-family:-apple-system,Helvetica,Arial,sans-serif;">
<div style="max-width:480px;margin:0 auto;background:#fff;border-radius:12px;padding:32px;box-shadow:0 1px 3px rgba(0,0,0,0.08);">
<h2 style="margin:0 0 16px 0;font-size:18px;font-weight:600;color:#1a1a1a;">$subtitle</h2>
$body
<div style="margin-top:24px;padding-top:16px;border-top:1px solid #eee;font-size:11px;color:#999;">SecondBrain</div>
</div></body></html>
HTMLEOF
}

notify() {
    local title="${1:-SecondBrain}"
    local subtitle="${2:-}"
    local message="${3:-}"
    local sound="${4:-default}"
    local email_html="${5:-}"

    # macOS notification
    if [ -x "$NOTIFIER" ]; then
        "$NOTIFIER" -title "$title" -subtitle "$subtitle" -message "$message" -sound "$sound" 2>/dev/null || true
    fi

    # Email via Resend (HTML) -- disabled by default, uncomment to activate
    # if [ -n "$RESEND_KEY" ] && [ -n "$NOTIFY_EMAIL" ]; then
    #     local subject="$title: $subtitle"
    #     if [ -z "$email_html" ]; then
    #         email_html=$(_email_wrap "$subtitle" "<p style=\"margin:0;font-size:15px;color:#333;line-height:1.5;\">$message</p>")
    #     fi
    #     local json_html=$(/usr/bin/python3 -c "import json,sys; print(json.dumps(sys.argv[1]))" "$email_html")
    #     /usr/bin/curl -s -X POST https://api.resend.com/emails \
    #         -H "Authorization: Bearer $RESEND_KEY" \
    #         -H "Content-Type: application/json" \
    #         -d "{
    #             \"from\": \"SecondBrain <onboarding@resend.dev>\",
    #             \"to\": \"$NOTIFY_EMAIL\",
    #             \"subject\": \"$subject\",
    #             \"html\": $json_html
    #         }" > /dev/null 2>&1 || true
    # fi
}
