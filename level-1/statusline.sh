#!/bin/bash
input=$(cat)

MODEL=$(echo "$input" | jq -r '.model.display_name')
PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
COST=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
DURATION_MS=$(echo "$input" | jq -r '.cost.total_duration_ms // 0')
SESSION_NAME=$(echo "$input" | jq -r '.session_name // empty')
DIR=$(echo "$input" | jq -r '.workspace.current_dir')
RATE_5H=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
RATE_7D=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')

CYAN='\033[36m'; GREEN='\033[32m'; YELLOW='\033[33m'; RED='\033[31m'; DIM='\033[2m'; RESET='\033[0m'

if [ "$PCT" -ge 90 ]; then BAR_COLOR="$RED"
elif [ "$PCT" -ge 70 ]; then BAR_COLOR="$YELLOW"
else BAR_COLOR="$GREEN"; fi

FILLED=$((PCT / 10)); EMPTY=$((10 - FILLED))
printf -v FILL "%${FILLED}s"; printf -v PAD "%${EMPTY}s"
BAR="${FILL// /█}${PAD// /░}"

COST_FMT=$(printf '$%.2f' "$COST")
MINS=$((DURATION_MS / 60000)); SECS=$(((DURATION_MS % 60000) / 1000))

RATE_INFO=""
if [ -n "$RATE_5H" ]; then
    R5=$(printf '%.0f' "$RATE_5H")
    if [ "$R5" -ge 80 ]; then RATE_COLOR="$RED"
    elif [ "$R5" -ge 50 ]; then RATE_COLOR="$YELLOW"
    else RATE_COLOR="$GREEN"; fi
    RATE_INFO=" | ${DIM}5h:${RESET}${RATE_COLOR}${R5}%${RESET}"
fi
if [ -n "$RATE_7D" ]; then
    R7=$(printf '%.0f' "$RATE_7D")
    if [ "$R7" -ge 80 ]; then RATE_COLOR="$RED"
    elif [ "$R7" -ge 50 ]; then RATE_COLOR="$YELLOW"
    else RATE_COLOR="$GREEN"; fi
    RATE_INFO="${RATE_INFO} ${DIM}7d:${RESET}${RATE_COLOR}${R7}%${RESET}"
fi

LINE1="${CYAN}[$MODEL]${RESET} ${BAR_COLOR}${BAR}${RESET} ${PCT}% | ${YELLOW}${COST_FMT}${RESET} | ⏱️ ${MINS}m ${SECS}s${RATE_INFO}"
[ -n "$SESSION_NAME" ] && LINE1="${LINE1} | ${DIM}${SESSION_NAME}${RESET}"

echo -e "$LINE1"

if git rev-parse --git-dir > /dev/null 2>&1; then
    BRANCH=$(git branch --show-current 2>/dev/null)
    STAGED=$(git diff --cached --numstat 2>/dev/null | wc -l | tr -d ' ')
    MODIFIED=$(git diff --numstat 2>/dev/null | wc -l | tr -d ' ')
    UNTRACKED=$(git ls-files --others --exclude-standard 2>/dev/null | wc -l | tr -d ' ')

    GIT_STATUS=""
    [ "$STAGED" -gt 0 ] && GIT_STATUS="${GREEN}+${STAGED}${RESET}"
    [ "$MODIFIED" -gt 0 ] && GIT_STATUS="${GIT_STATUS} ${YELLOW}~${MODIFIED}${RESET}"
    [ "$UNTRACKED" -gt 0 ] && GIT_STATUS="${GIT_STATUS} ${RED}?${UNTRACKED}${RESET}"

    echo -e "📁 ${DIR##*/} | 🌿 ${BRANCH} ${GIT_STATUS}"
else
    echo -e "📁 ${DIR##*/}"
fi
