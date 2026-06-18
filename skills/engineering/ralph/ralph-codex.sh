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

# Optional model override (same knob as ralph.sh). Each runtime interprets the
# value itself — here it's passed to `codex exec --model`, so use a Codex model
# name (e.g. `gpt-5-codex`). Built as an array so an unset knob expands to
# nothing; the guarded expansion below handles bash 3.2's empty-array-under-set-u.
MODEL_ARGS=()
if [ -n "${RALPH_MODEL:-}" ]; then
  MODEL_ARGS=(--model "$RALPH_MODEL")
fi

# Spawned-child attribution (mirrors ralph.sh; see its comment). Each
# `codex exec` child this loop spawns is attributed to the orchestrator session
# that launched ralph (CLAUDE_CODE_SESSION_ID). The loop stays Trace-blind: per
# child it captures the child's Codex thread id from the stream and hands the
# (parent, child) pair to TRACE_SPAWN_HOOK — a command template with {parent}
# and {child} placeholders, e.g.
#   trace session set-parent {child} --parent {parent} --origin spawned
# Unset hook → no-op; bare terminal (no parent session) → attribution skipped.
# Every captured pair is also appended to a sink file as a robust
# `<parent>\t<child>` source of truth.
PARENT_SESSION="${CLAUDE_CODE_SESSION_ID:-}"
SPAWN_SINK=""
if [ -n "$PARENT_SESSION" ]; then
  SPAWN_SINK="$(mktemp -t ralph-spawn-sink.XXXXXX)"
  echo "ralph-codex: attributing spawned children to parent session $PARENT_SESSION" >&2
  echo "ralph-codex: spawn sink → $SPAWN_SINK" >&2
fi

# Record one spawned child and fire the per-child hook. No-ops without a parent
# session, without a child id, or when child == parent (defensive).
emit_spawn() {
  local child="$1"
  [ -n "$child" ] || return 0
  [ -n "$PARENT_SESSION" ] || return 0
  [ "$child" != "$PARENT_SESSION" ] || return 0
  printf '%s\t%s\n' "$PARENT_SESSION" "$child" >> "$SPAWN_SINK"
  [ -n "${TRACE_SPAWN_HOOK:-}" ] || return 0
  local cmd="${TRACE_SPAWN_HOOK//\{child\}/$child}"
  cmd="${cmd//\{parent\}/$PARENT_SESSION}"
  echo "ralph-codex: spawn hook → $cmd" >&2
  if ! eval "$cmd"; then
    echo "ralph-codex: warning — spawn hook exited non-zero for child $child" >&2
  fi
}

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROMPT_TEMPLATE="$SKILL_DIR/resources/iteration-prompt.md"

REPO_ROOT="$(pwd)"
# The feature's docs dir defaults to the in-repo convention; the orchestrator
# overrides it (RALPH_DOCS_DIR) when the feature's artifacts live elsewhere.
# Tasks/log paths always derive from it.
DOCS_DIR="${RALPH_DOCS_DIR:-$REPO_ROOT/docs/$FEATURE}"
TASKS_FILE="$DOCS_DIR/$FEATURE.tasks.md"
LOG_FILE="$DOCS_DIR/$FEATURE.log.md"

if [ ! -f "$TASKS_FILE" ]; then
  echo "ralph-codex: tasks file not found at $TASKS_FILE" >&2
  exit 66
fi

# Extra writable sandbox roots. The docs dir is granted automatically — the
# iterations must write the tasks/log files wherever they live (a harmless
# duplicate when it's the in-repo default). The orchestrator passes
# RALPH_EXTRA_DIRS (colon-separated absolute paths) only for genuinely
# additional dirs, e.g. reference projects. A writable root is also readable.
# Empty-array expansion is guarded for bash 3.2 (macOS default).
EXTRA_DIRS=("$DOCS_DIR")
if [ -n "${RALPH_EXTRA_DIRS:-}" ]; then
  IFS=':' read -r -a USER_DIRS <<< "$RALPH_EXTRA_DIRS"
  for d in ${USER_DIRS[@]+"${USER_DIRS[@]}"}; do
    case "$d" in
      /*) ;;
      *)
        echo "ralph-codex: RALPH_EXTRA_DIRS entries must be absolute paths: $d" >&2
        exit 64
        ;;
    esac
    if [ ! -d "$d" ]; then
      echo "ralph-codex: RALPH_EXTRA_DIRS entry is not a directory: $d" >&2
      exit 66
    fi
    EXTRA_DIRS+=("$d")
  done
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

# writable_roots re-adds .git (workspace-write hardcodes it read-only — see the
# pipeline comment below) plus the docs dir and every RALPH_EXTRA_DIRS entry.
WRITABLE_ROOTS="[\"$REPO_ROOT/.git\""
for d in ${EXTRA_DIRS[@]+"${EXTRA_DIRS[@]}"}; do
  WRITABLE_ROOTS="$WRITABLE_ROOTS,\"$d\""
done
WRITABLE_ROOTS="$WRITABLE_ROOTS]"

if [ -n "${RALPH_MODEL:-}" ]; then
  echo "ralph-codex: iterations will run with --model $RALPH_MODEL" >&2
fi

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
  # writable_roots re-adds .git, which workspace-write hardcodes as read-only
  # (Codex 0.129 has no toggle for it) — without this, `git add` fails with
  # `Unable to create '.git/index.lock': Operation not permitted` and every
  # iteration STUCKs on commit.
  # </dev/null prevents codex's stdin-readback from blocking.
  if ! codex exec --json --skip-git-repo-check -s workspace-write \
        ${MODEL_ARGS[@]+"${MODEL_ARGS[@]}"} \
        -c "sandbox_workspace_write.writable_roots=$WRITABLE_ROOTS" \
        "$PROMPT" </dev/null 2>&1 \
      | tee "$raw_file" \
      | grep --line-buffered '^{' \
      | jq -rj --unbuffered "$STREAM_TEXT" 2>/dev/null; then
    echo "ralph-codex: iteration $i exited non-zero; continuing" >&2
  fi

  grep '^{' "$raw_file" | jq -rj "$AGENT_TEXT" 2>/dev/null > "$result_file" || true

  result="$(cat "$result_file")"

  # Attribute this child to the parent session. Codex emits its thread id once,
  # in the first `thread.started` event. Captured before raw_file is removed.
  child_session="$(grep '^{' "$raw_file" 2>/dev/null | jq -r 'select(.type == "thread.started").thread_id // empty' 2>/dev/null | head -n1 || true)"
  emit_spawn "$child_session"

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
