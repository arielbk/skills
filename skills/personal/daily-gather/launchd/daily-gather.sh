#!/bin/zsh
# daily-gather launchd wrapper.
# Runs the read-only daily-gather skill headlessly so the morning /daily-start
# is instant. Invoked by com.arielbk.daily-gather.plist at 08:45 (and on wake
# if the machine was asleep then). Safe to run by hand to test.

set -u

# launchd starts with a bare environment. Rebuild a PATH that covers every
# launcher the MCP stdio servers need:
#   /Users/arielbk/.local/bin ............ claude (native install)
#   /opt/homebrew/bin .................... uv (Things MCP), brew
#   fnm node install (STABLE path, not the ephemeral multishell) ... node, npx
export PATH="/Users/arielbk/.local/bin:/opt/homebrew/bin:/Users/arielbk/.local/share/fnm/node-versions/v24.15.0/installation/bin:/usr/bin:/bin:/usr/sbin:/sbin"

VAULT="/Users/arielbk/Documents/notes"
LOG_DIR="/Users/arielbk/.local/state/daily-gather"
LOG="$LOG_DIR/gather.log"
mkdir -p "$LOG_DIR"

cd "$VAULT" || { echo "$(date '+%F %T') FATAL cannot cd to $VAULT" >>"$LOG"; exit 1; }

echo "===== $(date '+%F %T') daily-gather run =====" >>"$LOG"

claude -p "Run the daily-gather skill now to build today's briefing file. Follow the skill's steps exactly. This is an unattended scheduled run — do not ask questions, do not mutate Things/calendar/notes, only read and write the single briefing file." \
  --permission-mode bypassPermissions >>"$LOG" 2>&1

echo "----- $(date '+%F %T') exit $? -----" >>"$LOG"

# Keep the log bounded (last ~500 lines).
tail -n 500 "$LOG" >"$LOG.tmp" && mv "$LOG.tmp" "$LOG"
