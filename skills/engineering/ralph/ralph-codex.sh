#!/usr/bin/env bash
# Ralph (Codex variant): spawn a fresh `codex exec --json` per iteration until
# the feature's task DAG is complete (sentinel emitted) or the iteration cap is
# hit.
#
# Usage: ralph-codex.sh <feature> [max-iterations]
#
# Mirrors ralph.sh but runs the Codex CLI instead of Claude. Codex sandboxes
# itself (-s workspace-write), so there is no Docker sandbox lookup. Each
# iteration receives the same rendered iteration-prompt.md the Claude path
# uses.

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
  echo "ralph-codex: tasks file not found at $TASKS_FILE" >&2
  exit 66
fi

if [ ! -f "$PROMPT_TEMPLATE" ]; then
  echo "ralph-codex: prompt template missing at $PROMPT_TEMPLATE" >&2
  exit 70
fi

if ! command -v codex >/dev/null 2>&1; then
  echo "ralph-codex: codex CLI not found on PATH" >&2
  exit 69
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "ralph-codex: jq not found on PATH; required to parse codex exec --json output" >&2
  exit 69
fi

# jq filters applied to codex's --json (JSONL) stream.
#   STREAM_TEXT  — emits agent message text as it completes, plus a short
#                  "$ <cmd>" line for each tool/command_execution start, so the
#                  orchestrator's terminal shows live progress.
#   AGENT_TEXT   — emits ONLY agent_message text, concatenated across the
#                  iteration. The final accumulated value is sentinel-checked.
STREAM_TEXT='
  if .type == "item.completed" and .item.type == "agent_message" then
    .item.text + "\n"
  elif .type == "item.started" and .item.type == "command_execution" then
    "$ " + (.item.command // "") + "\n"
  else empty end
'
AGENT_TEXT='
  select(.type == "item.completed" and .item.type == "agent_message").item.text // empty
'

render_prompt() {
  sed \
    -e "s|{{FEATURE}}|$FEATURE|g" \
    -e "s|{{TASKS_FILE}}|$TASKS_FILE|g" \
    -e "s|{{LOG_FILE}}|$LOG_FILE|g" \
    "$PROMPT_TEMPLATE"
}

PROMPT="$(render_prompt)"

for ((i = 1; i <= MAX_ITERATIONS; i++)); do
  echo "─── ralph-codex iteration $i / $MAX_ITERATIONS ───"

  raw_file="$(mktemp)"
  result_file="$(mktemp)"

  # Stream pipeline (mirrors ralph.sh but for codex's event schema):
  #   Stage 1: codex → tee live JSON lines to terminal-friendly jq AND raw_file
  #   Stage 2: re-read raw_file with jq AGENT_TEXT to capture sentinel target
  #
  # We avoided `tee >(jq AGENT_TEXT) | jq STREAM_TEXT` because the two jq
  # processes racing the same pipe produced nondeterministic truncation of the
  # captured result. Writing the JSONL to raw_file first and re-jq'ing it is
  # deterministic and trivially cheap (raw_file is small).
  #
  # Sandbox: workspace-write keeps codex confined to the repo, no network or
  # outside-workspace writes, while still letting it commit + run tests.
  # </dev/null prevents codex's stdin-readback from blocking.
  if ! codex exec --json --skip-git-repo-check -s workspace-write \
        "$PROMPT" </dev/null 2>&1 \
      | tee "$raw_file" \
      | grep --line-buffered '^{' \
      | jq -rj --unbuffered "$STREAM_TEXT" 2>/dev/null; then
    echo "ralph-codex: iteration $i exited non-zero; continuing" >&2
  fi

  grep '^{' "$raw_file" | jq -rj "$AGENT_TEXT" 2>/dev/null > "$result_file" || true

  result="$(cat "$result_file")"

  echo
  echo "─── iteration $i summary ───"
  if [ -n "$result" ]; then
    # Print the tail — sentinel + reasoning live at the end of the final
    # agent_message. Full text already streamed live above.
    printf '%s\n' "$result" | tail -c 4000
  else
    echo "(no agent_message captured — falling back to raw stream tail)"
    tail -c 4000 "$raw_file" || true
  fi
  echo "─── /iteration $i summary ───"

  rm -f "$raw_file" "$result_file"

  if [[ "$result" == *"<promise>COMPLETE</promise>"* ]]; then
    echo "─── ralph-codex: COMPLETE sentinel detected after $i iteration(s) ───"
    exit 0
  fi

  if [[ "$result" == *"<promise>STUCK"* ]]; then
    echo "─── ralph-codex: STUCK sentinel detected after $i iteration(s); halting ───" >&2
    exit 76
  fi
done

echo "─── ralph-codex: iteration cap ($MAX_ITERATIONS) reached without sentinel ───" >&2
exit 75
