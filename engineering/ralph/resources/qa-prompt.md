You are the final agent in a Ralph run for the **{{FEATURE}}** feature. The loop has completed — every slice in the tasks file is settled (`done`, or `needs-review` for slices a human must still verify). Your one job is to generate the QA plan, matching the format `/implement` produces.

## Required reads

1. `{{TASKS_FILE}}` — the completed slice DAG. Re-read for freshness.
2. `{{LOG_FILE}}` — every iteration's log entry. The QA plan is derived primarily from this.
3. `qa-template.md` in the `/implement` skill's resources — the exact template you must follow.
4. The repo's run config — `package.json` scripts (root and any app/package dirs), Makefile, README, or compose files. You need the **real** command and port to start anything a human must verify (web app, worker, etc.). The loop ran in isolated iterations, so this is likely not in the log — go find it.

## Your job

Compose `docs/{{FEATURE}}/{{FEATURE}}.qa.md` per `qa-template.md`. Split items into:

- **Already verified by the agent** (checked, near the top) — tests, typechecks, lints, builds, CLI smoke checks that prior iterations actually ran. Pull these from log entries. Each gets a `- [x]` and a one-line result.
- **Human verification required** (unchecked) — every slice left at `Status: needs-review`, plus any slice with `Human checkpoint: yes` in the tasks file, plus anything needing a browser, device, or human judgement. A `needs-review` slice is the loop signalling it could not self-verify a runtime gate — name it explicitly here. Write each item as a self-contained runbook, not a vague instruction: exact command + working dir, exact entry point (full URL incl. port, screen, or CLI invocation), concrete steps, and pass criterion. Pull the real run command and port from the repo's run config (read #4 above); never write "open the local web app" without saying how. Put commands shared by several items in a single **Setup** block at the top of the section per `qa-template.md`.
- **Watch closely** — log entries with non-empty `Deviations:` or unusual `Notes:`.

Do not include CLI commands in the unchecked sections if a prior iteration already ran them — that erodes trust in the checklist.

## Output

Write the file, then output its absolute path as the last line of your reply. Nothing else.
