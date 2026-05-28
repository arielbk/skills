#!/usr/bin/env bash
# Ralph loop: spawn a fresh `claude -p` per iteration until the feature's task
# DAG is complete (sentinel emitted) or the iteration cap is hit.
#
# Usage: ralph.sh <feature> [max-iterations]
#
# Sandboxing: each iteration runs under Anthropic's sandbox runtime
# (`@anthropic-ai/sandbox-runtime`), which wraps the whole `claude` process in
# macOS Seatbelt / Linux bubblewrap isolation — no Docker, no per-workspace VM,
# no in-sandbox `/login`. Auth comes from the host's existing Claude Code
# credentials (~/.claude.json), which we grant the sandbox write access to so
# token refresh works. The runtime denies all writes + network by default; the
# generated settings file below opens exactly what an iteration needs.
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

if ! command -v jq >/dev/null 2>&1; then
  echo "ralph: jq not found on PATH; required to parse claude's stream-json output" >&2
  exit 69
fi

# Resolve the sandbox-runtime launcher. Prefer a globally-installed `srt`
# binary; fall back to `npx`, which caches the package after the first fetch.
if command -v srt >/dev/null 2>&1; then
  SRT_BIN=(srt)
elif command -v npx >/dev/null 2>&1; then
  SRT_BIN=(npx -y @anthropic-ai/sandbox-runtime)
else
  echo "ralph: neither 'srt' nor 'npx' found on PATH." >&2
  echo "       Install the sandbox runtime: npm i -g @anthropic-ai/sandbox-runtime" >&2
  exit 69
fi

if ! command -v claude >/dev/null 2>&1; then
  echo "ralph: claude CLI not found on PATH" >&2
  exit 69
fi

# Sandbox settings. A user-supplied file (RALPH_SRT_SETTINGS) wins; otherwise we
# generate a minimal one scoped to THIS repo, so there is nothing to set up per
# project. Widen allowNetwork/allowWrite via your own file if a slice's feedback
# loop needs to reach a package registry or write outside the repo.
if [ -n "${RALPH_SRT_SETTINGS:-}" ]; then
  if [ ! -f "$RALPH_SRT_SETTINGS" ]; then
    echo "ralph: RALPH_SRT_SETTINGS points at a missing file: $RALPH_SRT_SETTINGS" >&2
    exit 66
  fi
  SRT_SETTINGS="$RALPH_SRT_SETTINGS"
  CLEANUP_SETTINGS=0
  echo "ralph: using sandbox settings from \$RALPH_SRT_SETTINGS ($SRT_SETTINGS)" >&2
else
  SRT_SETTINGS="$(mktemp -t ralph-srt-settings.XXXXXX.json)"
  CLEANUP_SETTINGS=1
  TMP_ROOT="${TMPDIR:-/tmp}"
  cat > "$SRT_SETTINGS" <<JSON
{
  "allowWrite": [
    "$REPO_ROOT",
    "$HOME/.claude",
    "$HOME/.claude.json",
    "${TMP_ROOT%/}"
  ],
  "allowNetwork": [
    "*.anthropic.com"
  ]
}
JSON
  echo "ralph: generated sandbox settings at $SRT_SETTINGS (repo + ~/.claude writable; *.anthropic.com network)" >&2
fi

cleanup() { [ "${CLEANUP_SETTINGS:-0}" = "1" ] && rm -f "$SRT_SETTINGS"; }
trap cleanup EXIT

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

# Probe: validate the sandbox launches AND the host is authenticated, before
# burning iteration 1 on a setup failure. A logged-out host (or a wrong
# sandbox invocation) fails here with actionable instructions.
echo "ralph: probing sandbox + auth…" >&2
probe_out="$("${SRT_BIN[@]}" --settings "$SRT_SETTINGS" \
    claude -p --dangerously-skip-permissions \
    "Reply with the single word READY and nothing else." 2>&1 || true)"
if ! printf '%s' "$probe_out" | grep -q "READY"; then
  echo "ralph: sandbox probe failed (did not return READY)." >&2
  echo "       Most likely the host Claude Code is not logged in, or network is blocked." >&2
  echo "       Verify with:  claude -p 'say hi'" >&2
  echo "       Then re-invoke /ralph. Probe output tail:" >&2
  printf '%s\n' "$probe_out" | tail -c 1200 >&2
  exit 78
fi
echo "ralph: probe passed." >&2

for ((i = 1; i <= MAX_ITERATIONS; i++)); do
  echo "─── ralph iteration $i / $MAX_ITERATIONS ───"

  raw_file="$(mktemp)"
  result_file="$(mktemp)"

  # Stream pipeline. Because claude runs directly under the sandbox runtime
  # (no Docker, no pty), its stream-json output is clean line-delimited JSON on
  # stdout — no CR-stripping or pty allocation needed. We:
  #   1. tee the full stream to raw_file for diagnostics,
  #   2. keep only JSON-shaped lines (grep '^{'),
  #   3. echo live assistant text to the terminal (jq STREAM_TEXT),
  # then re-read raw_file once to extract the canonical result deterministically
  # (avoids two jq processes racing the same pipe).
  if ! "${SRT_BIN[@]}" --settings "$SRT_SETTINGS" \
        claude -p --dangerously-skip-permissions \
        --verbose --output-format stream-json \
        "$PROMPT" 2>&1 \
      | tee "$raw_file" \
      | grep --line-buffered '^{' \
      | jq -rj --unbuffered "$STREAM_TEXT" 2>/dev/null; then
    echo "ralph: iteration $i exited non-zero; continuing" >&2
  fi

  grep '^{' "$raw_file" | jq -rj "$FINAL_RESULT" 2>/dev/null > "$result_file" || true

  result="$(cat "$result_file")"

  echo
  echo "─── iteration $i summary ───"
  if [ -n "$result" ]; then
    printf '%s\n' "$result"
  else
    echo "(no result event captured — falling back to raw stream tail)"
    tail -c 4000 "$raw_file" | grep '^{' | jq -rj "$STREAM_TEXT" 2>/dev/null || true
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
