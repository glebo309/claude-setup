#!/bin/zsh
# Trigger daily briefing on laptop wake (via sleepwatcher)
# This file is installed as ~/.wakeup by the setup script.
/bin/zsh "$HOME/.claude/scripts/daily-briefing.sh" &
