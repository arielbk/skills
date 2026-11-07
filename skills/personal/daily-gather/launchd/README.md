# daily-gather launchd job

Runs the read-only `daily-gather` skill at **08:45 local** so the morning
`/daily-start` reads a pre-built briefing instead of doing ~5 min of MCP calls.
If the Mac is asleep at 08:45, launchd runs it once on the next wake.

## Files
- `daily-gather.sh` — wrapper. Sets a launchd-safe PATH (claude, uv, node), cds
  to the vault, runs `claude -p` headless with `bypassPermissions`, logs output.
- `com.arielbk.daily-gather.plist` — LaunchAgent (source copy; the live copy is
  in `~/Library/LaunchAgents/`).

## Install / update
```sh
cp com.arielbk.daily-gather.plist ~/Library/LaunchAgents/
launchctl bootout   gui/$(id -u)/com.arielbk.daily-gather 2>/dev/null || true
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.arielbk.daily-gather.plist
```

## Test now (fires immediately)
```sh
launchctl kickstart -k gui/$(id -u)/com.arielbk.daily-gather
```
Note: it will **bail** if today's `Dailies/{date}.md` already exists — that's
correct behaviour. The real gather only happens before the day is planned.

## Logs
- `~/.local/state/daily-gather/gather.log` — skill output (auto-trimmed to 500 lines)
- `~/.local/state/daily-gather/launchd.{out,err}.log` — launchd-level output

## Uninstall
```sh
launchctl bootout gui/$(id -u)/com.arielbk.daily-gather
rm ~/Library/LaunchAgents/com.arielbk.daily-gather.plist
```

## Auth note
`claude -p` gets its credentials from the macOS **login keychain** (item
"Claude Code-credentials"), which is available because this is a LaunchAgent
running in the logged-in user session. A bare `env -i` run will fail with
"Not logged in" — that is expected and not a launchd problem. If a real run
ever logs "Not logged in", re-auth with `claude` interactively.
