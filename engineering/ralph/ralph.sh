#!/usr/bin/env bash
# Ralph loop: spawn a fresh sandboxed `claude -p` per iteration until the
# feature's task DAG is complete (sentinel emitted) or the iteration cap is hit.
#
# Usage: ralph.sh <feature> [max-iterations]
#
# Each iteration receives the rendered iteration-prompt.md with {feature} and
# absolute paths substituted in. Stops early on `<promise>COMPLETE</promise>`.

set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: $0 <feature> [max-iterations]" >&2
  exit 64
fi

FEATURE="$1"
MAX_ITERATIONS="${2:-30}"

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROMPT_TEMPLATE="$SKILL_DIR/resources/iteration-prompt.md"

REPO_ROOT="$(pwd)"
TASKS_FILE="$REPO_ROOT/docs/$FEATURE/$FEATURE.tasks.md"
LOG_FILE="$REPO_ROOT/docs/$FEATURE/$FEATURE.log.md"

if [ ! -f "$TASKS_FILE" ]; then
  echo "ralph: tasks file not found at $TASKS_FILE" >&2
  exit 66
fi

if [ ! -f "$PROMPT_TEMPLATE" ]; then
  echo "ralph: prompt template missing at $PROMPT_TEMPLATE" >&2
  exit 70
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "ralph: docker not found on PATH" >&2
  exit 69
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "ralph: jq not found on PATH; required to parse claude's stream-json output" >&2
  exit 69
fi

# jq filters applied to claude's --output-format stream-json stream.
#   STREAM_TEXT  — extracts each assistant text chunk as it arrives, for live
#                  echo to the orchestrator's terminal.
#   FINAL_RESULT — extracts the single `result` event emitted at iteration end;
#                  this is the canonical iteration outcome and the only thing
#                  we sentinel-check.
STREAM_TEXT='select(.type == "assistant").message.content[]? | select(.type == "text").text // empty'
FINAL_RESULT='select(.type == "result").result // empty'

render_prompt() {
  sed \
    -e "s|{{FEATURE}}|$FEATURE|g" \
    -e "s|{{TASKS_FILE}}|$TASKS_FILE|g" \
    -e "s|{{LOG_FILE}}|$LOG_FILE|g" \
    "$PROMPT_TEMPLATE"
}

PROMPT="$(render_prompt)"

# `docker sandbox run` requires a TTY on stdin, which we won't have when
# ralph.sh is invoked from a non-interactive parent (e.g. another claude
# session whose Bash tool pipes a socket as stdin). We use Python's `pty.spawn`
# to allocate a fresh pty and re-exec the command under it — unlike `script -q
# /dev/null`, this does not call tcgetattr on its own stdin and therefore works
# even when stdin is a socket.
if ! command -v python3 >/dev/null 2>&1; then
  echo "ralph: 'python3' not found on PATH; required to allocate a pty for docker sandbox" >&2
  exit 69
fi

# Auth strategy: reuse the user's already-logged-in workspace sandbox.
# OAuth state lives inside the sandbox VM, not on the host proxy as of plugin
# v0.12 — a freshly-created sandbox has no login. So we look up an existing
# sandbox bound to this workspace and reuse it. If none exists, we ask the
# user to log in once interactively before invoking /ralph.
find_workspace_sandbox() {
  # Prefer a sandbox whose workspace list contains $REPO_ROOT and whose name
  # does NOT start with "ralph-" (those are leftovers from older ralph.sh
  # builds and may not be logged in).
  docker sandbox ls --json 2>/dev/null | python3 -c "
import json, sys
repo = '$REPO_ROOT'
try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)
candidates = [vm['name'] for vm in data.get('vms', [])
              if repo in vm.get('workspaces', [])]
non_ralph = [n for n in candidates if not n.startswith('ralph-')]
print((non_ralph or candidates or [''])[0])
" 2>/dev/null
}

SANDBOX_NAME="$(find_workspace_sandbox || true)"
if [ -z "$SANDBOX_NAME" ]; then
  echo "ralph: no docker sandbox found for workspace $REPO_ROOT." >&2
  echo "       Run this once interactively to create + log in:" >&2
  echo "         docker sandbox run claude" >&2
  echo "         # inside: /login → complete OAuth → /quit" >&2
  echo "       Then re-invoke /ralph." >&2
  exit 78
fi

echo "ralph: reusing sandbox '${SANDBOX_NAME}' (workspace ${REPO_ROOT})" >&2

# Login probe: a workspace sandbox existing does not mean it's logged in (OAuth
# state lives inside the VM as of plugin v0.12, and a freshly-created sandbox has
# none). Rather than inspect credential files, run a minimal sandboxed `claude -p`
# and require it to actually answer. A logged-out sandbox errors out here, so we
# abort during preflight with the login instructions instead of burning
# iteration 1 on an auth failure.
echo "ralph: probing sandbox '${SANDBOX_NAME}' login state…" >&2
probe_out="$(python3 -c 'import pty,sys; sys.exit(pty.spawn(sys.argv[1:]) >> 8)' \
    docker sandbox run "$SANDBOX_NAME" -- \
    --dangerously-skip-permissions -p "Reply with the single word READY and nothing else." 2>&1 || true)"
if ! printf '%s' "$probe_out" | grep -q "READY"; then
  echo "ralph: sandbox '${SANDBOX_NAME}' is not logged in (auth probe did not return READY)." >&2
  echo "       Run this once interactively to log in:" >&2
  echo "         docker sandbox run claude" >&2
  echo "         # inside: /login → complete OAuth → /quit" >&2
  echo "       Then re-invoke /ralph." >&2
  exit 78
fi
echo "ralph: login probe passed." >&2

for ((i = 1; i <= MAX_ITERATIONS; i++)); do
  echo "─── ralph iteration $i / $MAX_ITERATIONS ───"

  raw_file="$(mktemp)"
  result_file="$(mktemp)"

  # Reuse the workspace sandbox across iterations. Workspace state (commits)
  # persists naturally because it's bind-mounted from the host. Each call is
  # still a fresh `claude -p` session, so context resets per iteration.
  #
  # Stream pipeline:
  #   docker … --output-format stream-json
  #     │
  #     ├─ tee raw_file        ← full JSON stream saved for diagnostics
  #     │
  #     ├─ awk strip-CR        ← pty.spawn's terminal inserts CRs; strip them
  #     │                        so jq sees clean line-delimited JSON. Must use
  #     │                        awk with fflush() (not `tr -d '\r'`), because
  #     │                        tr block-buffers when its stdout is a pipe,
  #     │                        which causes the live stream to bunch up and
  #     │                        only emit at iteration end.
  #     │
  #     ├─ tee >(jq STREAM_TEXT) ← live text echoed to terminal as it arrives
  #     │
  #     └─ jq FINAL_RESULT > result_file
  #                              ← the single structured per-iteration outcome
  #                                the orchestrating agent reacts to
  # `docker sandbox run` prints a non-JSON preamble ("Starting claude agent…",
  # "Workspace: …") before the stream-json output begins; grep '^{' keeps only
  # JSON-shaped lines so jq doesn't choke. set -o pipefail is in effect, so any
  # silent jq parse error would otherwise abort the iteration with no captured
  # output.
  if ! python3 -c 'import pty,sys; sys.exit(pty.spawn(sys.argv[1:]) >> 8)' \
        docker sandbox run "$SANDBOX_NAME" -- \
        --dangerously-skip-permissions \
        --verbose -p --output-format stream-json \
        "$PROMPT" 2>&1 \
      | tee "$raw_file" \
      | awk '{ sub(/\r$/, ""); print; fflush() }' \
      | grep --line-buffered '^{' \
      | tee >(jq -rj --unbuffered "$STREAM_TEXT" 2>/dev/null) \
      | jq -rj --unbuffered "$FINAL_RESULT" 2>/dev/null > "$result_file"; then
    echo "ralph: iteration $i exited non-zero; continuing" >&2
  fi

  result="$(cat "$result_file")"

  echo
  echo "─── iteration $i summary ───"
  if [ -n "$result" ]; then
    printf '%s\n' "$result"
  else
    echo "(no result event captured — falling back to raw stream tail)"
    tail -c 4000 "$raw_file" | awk '{ sub(/\r$/, ""); print }' | jq -rj --unbuffered "$STREAM_TEXT" 2>/dev/null || true
  fi
  echo "─── /iteration $i summary ───"

  rm -f "$raw_file" "$result_file"

  if [[ "$result" == *"<promise>COMPLETE</promise>"* ]]; then
    echo "─── ralph: COMPLETE sentinel detected after $i iteration(s) ───"
    exit 0
  fi

  if [[ "$result" == *"<promise>STUCK"* ]]; then
    echo "─── ralph: STUCK sentinel detected after $i iteration(s); halting ───" >&2
    exit 76
  fi
done

echo "─── ralph: iteration cap ($MAX_ITERATIONS) reached without sentinel ───" >&2
exit 75
