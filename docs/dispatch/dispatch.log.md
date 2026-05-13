# Dispatch — implementation log

## `free-form-rule` — 2026-05-08

**Status:** done
**Summary:** Added a "free-form questions only, no AskUserQuestion multi-choice UI" rule near the top of both `skills/engineering/slice/SKILL.md` and `~/.agents/skills/grill-me/SKILL.md`. Updated slice step 7's stop message to mention `/dispatch {feature}` alongside `/implement {feature}` as next-step options.
**Deviations:** none
**Notes:** grill-me lives at `~/.agents/skills/grill-me/SKILL.md` (outside this repo); future edits to that skill must be applied there. The slice rule is placed as a blockquote directly under the opening paragraphs so it appears before any process step, with explicit emphasis on step 5 grilling.

## `dispatch-resources` — 2026-05-08

**Status:** done
**Summary:** Created `skills/engineering/dispatch/resources/` with byte-identical copies of `tdd-loop.md`, `log-format.md`, and `qa-template.md` from `implement/resources/`, plus a new `slice-prompt.md` defining the slice-agent role (required reads, `<status>` output contract with required `reason` on `needs-review`/`blocked`, and the only-touch-your-own-row constraint).
**Deviations:** none
**Notes:** The three copied files are intentionally duplicated rather than symlinked — per PRD, `dispatch` and `implement` are expected to diverge over time. `slice-prompt.md` references `tdd-loop.md` and `log-format.md` as siblings in the same `resources/` directory; the orchestrator should pass the absolute path to `slice-prompt.md` so sibling-relative reads resolve correctly.

## `dispatch-skill` — 2026-05-08

**Status:** done
**Summary:** Created `skills/engineering/dispatch/SKILL.md` implementing the single-slice path: always-delegate orchestrator that builds a minimal handoff brief (slug + absolute paths to tasks file, log file, and `slice-prompt.md`), spawns one sub-agent on `sonnet`, regex-parses the last `<status>` tag, re-reads the tasks file after each `done`, and loops. Stub sections mark where parallel/worktree (`parallel-worktrees`), human checkpoints (`human-checkpoint`), merge handling (`merge-flow`), and QA generation (`qa-generation`) will be added by later slices. Created `docs/fixture-single/fixture-single.tasks.md` with one trivial placeholder-file slice for empirical feedback-loop runs.
**Deviations:** none
**Notes:** The spawn-message template in step 4 is given verbatim — the orchestrator must not paraphrase or augment it with slice content. A "Constraints" section at the bottom hardens the no-read-slice-code, no-inline-spec, and re-read-tasks-file rules. The fixture is designed to be run by the user (not this agent) since `/dispatch` is the artifact under test.

## `parallel-worktrees` — 2026-05-08

**Status:** done
**Summary:** Replaced the step 4a stub in `skills/engineering/dispatch/SKILL.md` with the full parallel-execution flow: human-checkpoint and file-collision gates, single-message multi-`Agent` spawn with `isolation: "worktree"` and `model: "sonnet"`, per-slice `<status>` parsing, and `git merge --no-ff <branch>` on each `done`. Updated step 6a stub to point at the conflict path deferred to `merge-flow` and to surface conflicting branch + `git diff --name-only --diff-filter=U` in the interim. Created `docs/fixture-parallel/fixture-parallel.tasks.md` with two independent slices (`write-alpha` writing `output-a.txt`, `write-bravo` writing `output-b.txt`) for empirical validation.
**Deviations:** none
**Notes:** Branch names come from the `Agent` tool's worktree result — orchestrator does not invent them. Single-slice runs deliberately retain the no-worktree path per PRD ("Single spawns may run in-place"), so worktree isolation is gated specifically on parallelism. The file-collision gate mirrors `implement` and is intentionally heuristic (slice headers / file mentions) — the orchestrator must not read slice bodies to decide.

## `merge-flow` — 2026-05-08

**Status:** done
**Summary:** Replaced the step 6a stub in `skills/engineering/dispatch/SKILL.md` with the full merge-fix flow: capture conflicted-file list via `git diff --name-only --diff-filter=U`, spawn a merge-fix sub-agent with a minimal brief (two slugs + conflicted paths + tasks/log paths + pointer to `merge-fix-prompt.md`), parse the same `<status>` contract, finalise with `git commit --no-edit` on `done`, surface only reason + slugs + log path + paths-only file list on `needs-review`/`blocked`. Created `skills/engineering/dispatch/resources/merge-fix-prompt.md` defining the merge-fix-agent role (synthesise both intents where possible, stage files, do not commit, do not log, do not touch tasks file). Created `docs/fixture-conflict/fixture-conflict.tasks.md` with `write-shared-alpha` and `write-shared-bravo` — both `Depends on: none`, both rewrite line 1 of `docs/fixture-conflict/shared.txt` so the second merge guarantees a conflict.
**Deviations:** none
**Notes:** The merge-fix agent is the **only** agent in the dispatch loop allowed to read conflict-marker contents — this asymmetry is what keeps the orchestrator's context bounded even when conflicts arrive. The agent runs in the main working tree (no `isolation: "worktree"`) because the in-progress merge state lives there; spawning it in a fresh worktree would orphan the staged resolutions. Orchestrator runs `git commit --no-edit` itself rather than letting the merge-fix agent commit, to preserve the agent-stages / orchestrator-finalises boundary mirroring how slice agents update only their own row and the orchestrator handles transitions. Surfacing on `needs-review` deliberately omits the conflicted file *contents* — only paths — so the user opens the files themselves; this matches the human-checkpoint surface convention even though `merge-flow` slices have `Human checkpoint: no` (the checkpoint here is implicit, gated on the agent's escalation, not on slice metadata).

## `human-checkpoint` — 2026-05-08

**Status:** done
**Summary:** Replaced the step 6 stub in `skills/engineering/dispatch/SKILL.md` with the full human-checkpoint flow: on `needs-review`, capture changed files via `git diff --name-only` (worktree branch or HEAD), surface a four-element message (slug + reason verbatim + LOG_PATH + paths-only file list) and stop. On approval, mark the slice `done` and route through merge-flow if applicable. On change request, set the row back to `in-progress` and spawn a **fresh** sub-agent with the user's feedback inlined verbatim into a templated brief (no inline fixes). Documented the ambiguous-reply rule (single plain-text clarifying question) and recapped the no-Read-changed-files / no-paraphrase constraints. Created `docs/fixture-checkpoint/fixture-checkpoint.tasks.md` with one trivial `placeholder-checkpoint` slice (writes `placeholder.txt`, expected to emit `needs-review`) for empirical validation.
**Deviations:** none
**Notes:** The flow applies on every `needs-review` regardless of the slice's `Human checkpoint:` field — `Human checkpoint: yes` is the *expected* path, and `Human checkpoint: no` slices that emit `needs-review` are agent-self-flagged uncertainty surfaced the same minimal way. The change-request spawn brief carries the user's feedback verbatim plus the slug; it deliberately does not include any code or paraphrase, mirroring the no-bytes-into-orchestrator invariant from the original spawn template. Approval routing reuses step 6a's merge-flow rules unchanged for worktree-branch slices, so a checkpoint approval that hits a conflict still lands in the merge-fix path without special casing.
## `qa-generation` — 2026-05-08

**Status:** done
**Summary:** Replaced the step 7 stub in `skills/engineering/dispatch/SKILL.md` with the full QA-plan flow: trigger only when every slice is `done` (any `blocked`/`needs-review` short-circuits to a state-report stop), open `TASKS_PATH`, `LOG_PATH`, and `resources/qa-template.md` (the only point in the run the orchestrator opens the log file or the template), compose `docs/{feature}/{feature}.qa.md` weighted toward `Human checkpoint: yes` slices and log entries with non-empty `Deviations:` or unusual `Notes:`, output a single one-line "QA plan written: {path}" message, and stop completely (no next-step offers, no walk-through, no follow-up prompts).
**Deviations:** none
**Notes:** Step 3's existing "None unblocked, all done → step 7" / "None unblocked, some not-done → report and stop" branches already handle the `blocked`/`needs-review` short-circuit at the loop level; the explicit guard at the top of step 7 is redundant defence-in-depth so a future refactor of step 3 can't accidentally generate QA against a half-finished run. The end-to-end main loop now reads: identify feature (1) → parse DAG (2) → identify unblocked (3) → dispatch single (4) or parallel (4a) → parse `<status>` (5) → on `done` merge if worktree (4a/6a) → on `needs-review` surface (6) → on conflict spawn merge-fix (6a) → re-read tasks and loop (3) → when all `done`, generate QA (7) → stop. No fixture added — prior fixtures plus completing this slice itself give a real DAG to dogfood `/dispatch dispatch` against.
