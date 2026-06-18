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

# Optional model override. Bare `claude -p` inherits the host default (Opus);
# set RALPH_MODEL to drive a well-defined DAG with a cheaper/faster model
# (e.g. `claude-sonnet-4-6`). Built as an array so an unset knob expands to
# nothing — no empty `--model ""` that claude would reject. The guarded
# expansion below handles bash 3.2 (macOS default), where `${arr[@]}` on an
# empty array under `set -u` is an unbound-variable error.
MODEL_ARGS=()
if [ -n "${RALPH_MODEL:-}" ]; then
  MODEL_ARGS=(--model "$RALPH_MODEL")
fi

# Spawned-child attribution. Each `claude -p` child this loop spawns is a fresh
# Trace session; we attribute it to the orchestrator session that launched
# ralph. Claude Code exposes that live session UUID to Bash tool calls (and so
# to this script) as CLAUDE_CODE_SESSION_ID. The loop stays Trace-blind: per
# child it captures the child's own session id from the stream and hands the
# (parent, child) pair to TRACE_SPAWN_HOOK — a command template with {parent}
# and {child} placeholders, e.g.
#   trace session set-parent {child} --parent {parent} --origin spawned
# Unset hook → no-op; bare terminal (no parent session) → attribution skipped.
# Every captured pair is also appended to a sink file as a robust
# `<parent>\t<child>` source of truth, independent of whether the hook fires.
PARENT_SESSION="${CLAUDE_CODE_SESSION_ID:-}"
SPAWN_SINK=""
if [ -n "$PARENT_SESSION" ]; then
  SPAWN_SINK="$(mktemp -t ralph-spawn-sink.XXXXXX)"
  echo "ralph: attributing spawned children to parent session $PARENT_SESSION" >&2
  echo "ralph: spawn sink → $SPAWN_SINK" >&2
fi

# Record one spawned child and fire the per-child hook. No-ops without a parent
# session, without a child id, or when child == parent (defensive — a fresh
# `claude -p` always gets a new id, but never self-parent).
emit_spawn() {
  local child="$1"
  [ -n "$child" ] || return 0
  [ -n "$PARENT_SESSION" ] || return 0
  [ "$child" != "$PARENT_SESSION" ] || return 0
  printf '%s\t%s\n' "$PARENT_SESSION" "$child" >> "$SPAWN_SINK"
  [ -n "${TRACE_SPAWN_HOOK:-}" ] || return 0
  local cmd="${TRACE_SPAWN_HOOK//\{child\}/$child}"
  cmd="${cmd//\{parent\}/$PARENT_SESSION}"
  echo "ralph: spawn hook → $cmd" >&2
  if ! eval "$cmd"; then
    echo "ralph: warning — spawn hook exited non-zero for child $child" >&2
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
  echo "ralph: tasks file not found at $TASKS_FILE" >&2
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
        echo "ralph: RALPH_EXTRA_DIRS entries must be absolute paths: $d" >&2
        exit 64
        ;;
    esac
    if [ ! -d "$d" ]; then
      echo "ralph: RALPH_EXTRA_DIRS entry is not a directory: $d" >&2
      exit 66
    fi
    EXTRA_DIRS+=("$d")
  done
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
# binary (user-managed, version-agnostic); fall back to `npx` pinned to a
# known-good version — the settings schema below is what 0.0.52 validates, and
# an unpinned fetch could silently break every run on a future schema change.
if command -v srt >/dev/null 2>&1; then
  SRT_BIN=(srt)
elif command -v npx >/dev/null 2>&1; then
  SRT_BIN=(npx -y @anthropic-ai/sandbox-runtime@0.0.52)
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
  if [ -n "${RALPH_DOCS_DIR:-}" ] || [ -n "${RALPH_EXTRA_DIRS:-}" ]; then
    echo "ralph: warning — RALPH_SRT_SETTINGS replaces the whole settings file; the docs dir and RALPH_EXTRA_DIRS are NOT auto-granted. Your settings file's allowWrite must include them." >&2
  fi
else
  SRT_SETTINGS="$(mktemp -t ralph-srt-settings.XXXXXX.json)"
  CLEANUP_SETTINGS=1
  # Honor a host-set CLAUDE_CONFIG_DIR (e.g. ~/.claude-infinum); the inner claude
  # writes session state (session-env/<uuid>, etc.) there, not under ~/.claude.
  CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
  # sandbox-runtime v0.0.52 validates a nested filesystem/network schema and
  # requires every key present; the obsolete flat shape is rejected, which
  # collapses to deny-all and kills the probe. The temp-dir entries cover temp
  # writes on both Linux and macOS (where TMPDIR lives under /var/folders), and
  # macOS Seatbelt evaluates RESOLVED paths — /tmp and /var/folders are symlinks
  # into /private, so the /private/* twins must be listed too or claude's Bash
  # mkdirs under /private/tmp/claude-<uid>/… get EPERM. We also list both
  # CLAUDE_DIR and ~/.claude (harmless duplicate when CLAUDE_CONFIG_DIR is unset;
  # the CLI still reads ~/.claude.json for creds per the header comment).
  # RALPH_EXTRA_DIRS entries are spliced in as additional allowWrite roots.
  EXTRA_WRITE_JSON=""
  for d in ${EXTRA_DIRS[@]+"${EXTRA_DIRS[@]}"}; do
    EXTRA_WRITE_JSON="$EXTRA_WRITE_JSON,
      \"$d\""
  done
  cat > "$SRT_SETTINGS" <<JSON
{
  "filesystem": {
    "denyRead": [],
    "allowRead": [],
    "allowWrite": [
      "$REPO_ROOT",
      "$CLAUDE_DIR",
      "$CLAUDE_DIR.json",
      "$HOME/.claude",
      "$HOME/.claude.json",
      "/tmp",
      "/private/tmp",
      "/var/folders",
      "/private/var/folders"$EXTRA_WRITE_JSON
    ],
    "denyWrite": []
  },
  "network": {
    "allowedDomains": [
      "*.anthropic.com",
      "anthropic.com"
    ],
    "deniedDomains": [],
    "allowUnixSockets": [],
    "allowLocalBinding": false
  }
}
JSON
  extra_note=""
  if [ ${#EXTRA_DIRS[@]} -gt 1 ]; then
    extra_note=" + $((${#EXTRA_DIRS[@]} - 1)) extra dir(s)"
  fi
  echo "ralph: generated sandbox settings at $SRT_SETTINGS (repo + claude config + docs dir$extra_note writable; *.anthropic.com network)" >&2
fi

# An `if` block, not `[ … ] && rm`: the && form returns 1 when the condition
# is false (the RALPH_SRT_SETTINGS path), and an EXIT trap's status replaces
# the script's real exit code — masking a successful COMPLETE's exit 0.
cleanup() {
  if [ "${CLEANUP_SETTINGS:-0}" = "1" ]; then
    rm -f "$SRT_SETTINGS"
  fi
}
trap cleanup EXIT

# jq filters applied to claude's --output-format stream-json stream.
#   STREAM_TEXT  — extracts each assistant text chunk as it arrives, for live
#                  echo to the orchestrator's terminal. Applied with `jq -R`
#                  via a `fromjson?` prefix so a malformed line can't kill the
#                  live jq — a dead jq SIGPIPEs grep and then tee, truncating
#                  the raw file before the result event is flushed.
#   FINAL_RESULT — extracts the single `result` event emitted at iteration end;
#                  this is the canonical iteration outcome and the only thing
#                  we sentinel-check. Applied with `jq -rR` over the raw file:
#                  each line parses independently via `fromjson?`, so a
#                  malformed line (stderr bytes splicing into the stream) is
#                  skipped instead of aborting extraction and losing a result
#                  event that is physically present later in the file.
STREAM_TEXT='select(.type == "assistant").message.content[]? | select(.type == "text").text // empty'
FINAL_RESULT='fromjson? | select(.type == "result").result // empty'

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
if [ -n "${RALPH_MODEL:-}" ]; then
  echo "ralph: iterations will run with --model $RALPH_MODEL" >&2
fi
echo "ralph: probing sandbox + auth…" >&2
probe_out="$("${SRT_BIN[@]}" --settings "$SRT_SETTINGS" \
    claude -p --dangerously-skip-permissions \
    ${MODEL_ARGS[@]+"${MODEL_ARGS[@]}"} \
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

  raw_file="$(mktemp -t "ralph-iter-$i.raw")"
  stderr_file="$(mktemp -t "ralph-iter-$i.stderr")"
  result_file="$(mktemp)"

  # Stream pipeline. Because claude runs directly under the sandbox runtime
  # (no Docker, no pty), its stream-json output is clean line-delimited JSON on
  # stdout — no CR-stripping or pty allocation needed. Only stdout feeds the
  # pipeline: stderr goes to its own per-iteration diagnostics file, because a
  # stderr byte landing mid-line in the JSON stream produces a malformed
  # `{`-prefixed line that can cost us the result event. We:
  #   1. tee the full stdout stream to raw_file for diagnostics,
  #   2. keep only JSON-shaped lines (grep '^{'),
  #   3. echo live assistant text to the terminal (jq STREAM_TEXT),
  # then re-read raw_file once to extract the canonical result deterministically
  # (avoids two jq processes racing the same pipe).
  if ! "${SRT_BIN[@]}" --settings "$SRT_SETTINGS" \
        claude -p --dangerously-skip-permissions \
        ${MODEL_ARGS[@]+"${MODEL_ARGS[@]}"} \
        --verbose --output-format stream-json \
        "$PROMPT" 2>"$stderr_file" \
      | tee "$raw_file" \
      | grep --line-buffered '^{' \
      | jq -Rrj --unbuffered "fromjson? | $STREAM_TEXT" 2>/dev/null; then
    echo "ralph: iteration $i exited non-zero; continuing" >&2
  fi

  jq -rR "$FINAL_RESULT" "$raw_file" > "$result_file"

  result="$(cat "$result_file")"

  # Attribute this child to the parent session. Its own session id is present on
  # every stream event from the first line — with hooks installed the first
  # lines are hook_started events, which also carry session_id — so take the
  # first one seen. Captured before raw_file is removed in the summary block.
  child_session="$(jq -rR 'fromjson? | .session_id // empty' "$raw_file" 2>/dev/null | head -n1 || true)"
  emit_spawn "$child_session"

  echo
  echo "─── iteration $i summary ───"
  if [ -n "$result" ]; then
    printf '%s\n' "$result"
    rm -f "$raw_file"
  else
    # A result event should exist even on agent failure; its absence means the
    # stream was truncated or claude died early. Keep the diagnostics files
    # and say so — never silently show an empty summary.
    echo "ralph: no result event recovered from iteration $i" >&2
    echo "ralph: raw stream kept at    $raw_file" >&2
    echo "ralph: claude stderr kept at $stderr_file" >&2
    echo "(no result event captured — falling back to raw stream tail)"
    tail -c 4000 "$raw_file" | grep '^{' | jq -Rrj "fromjson? | $STREAM_TEXT" 2>/dev/null || true
  fi
  echo "─── /iteration $i summary ───"

  rm -f "$result_file"

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
