# Dispatch — DAG-orchestrating implementation skill

Builds a new `dispatch` skill that orchestrates `{feature}.tasks.md` DAGs without bloating its own context, and tightens questioning behaviour in `grill-me` and `slice`. See `docs/dispatch/dispatch.prd.md` for the full design.

## Slices

### `free-form-rule` — Free-form-questions rule for grill-me and slice

**Status:** done

**Outside-in:** A user typing `/grill-me` or `/slice` (and reaching its grilling step) sees only plain-text questions in the chat — never the `AskUserQuestion` multi-choice UI.

**Feedback loop:** In a fresh session, run `/grill-me` against any small plan and `/slice` against a brief that triggers step 5 grilling. Confirm both ask in plain text only. Also confirm `slice/SKILL.md` step 7 mentions `/dispatch` alongside `/implement`.

**Human checkpoint:** no

**Depends on:** none

---

### `dispatch-resources` — Resource files for the dispatch skill

**Status:** done

**Outside-in:** A slice sub-agent spawned by `dispatch` can load `tdd-loop.md`, `log-format.md`, `qa-template.md`, and `slice-prompt.md` from `skills/engineering/dispatch/resources/`.

**Feedback loop:** `diff` the three copied files against `skills/engineering/implement/resources/` originals — must be byte-identical at copy time. Read `slice-prompt.md` and confirm it specifies: required reads (tasks file by slug, log file, tdd-loop.md, log-format.md), the `<status>` output contract with `reason` attribute on `needs-review`/`blocked`, and the rule that the agent updates only its own slice's row.

**Human checkpoint:** no

**Depends on:** none

---

### `dispatch-skill` — Dispatch SKILL.md (single-slice path)

**Status:** done

**Outside-in:** A user typing `/dispatch {feature}` triggers an orchestrator that finds an unblocked slice in `docs/{feature}/{feature}.tasks.md`, spawns one sub-agent with minimal handoff (slug + paths to tasks file, log file, slice-prompt.md), parses the agent's `<status>` tag, updates the tasks file, and continues.

**Feedback loop:** Construct a fixture `docs/fixture-single/fixture-single.tasks.md` with one slice. Run `/dispatch fixture-single`. Confirm: orchestrator's spawn message contains slug + paths only (not slice content); sub-agent emits `<status>done</status>`; tasks file row flips to `done`; orchestrator's context stayed small (no slice code visible in its history).

**Human checkpoint:** no

**Depends on:** dispatch-resources

---

### `parallel-worktrees` — Parallel sub-agent spawns with worktree isolation

**Status:** done

**Outside-in:** When multiple slices in `{feature}.tasks.md` are unblocked at the same time, `dispatch` spawns them in parallel using `Agent` with `isolation: "worktree"`, then merges each branch with `git merge --no-ff` once that agent reports `done`.

**Feedback loop:** Construct `docs/fixture-parallel/fixture-parallel.tasks.md` with two independent slices touching different files. Run `/dispatch fixture-parallel`. Confirm: two worktrees created, both sub-agents run concurrently, each branch merges cleanly into the working tree on `done`, tasks file reflects both as `done`.

**Human checkpoint:** no

**Depends on:** dispatch-skill

---

### `merge-flow` — Merge-conflict handling via merge-fix sub-agent

**Status:** done

**Outside-in:** When `git merge --no-ff` of a sub-agent's branch returns a conflict, `dispatch` spawns a merge-fix sub-agent briefed with the conflict markers, both log entries, and both slice specs. The merge-fix agent emits the same `<status>` tags; `done` commits the resolved merge, `needs-review` surfaces to the user.

**Feedback loop:** Construct `docs/fixture-conflict/fixture-conflict.tasks.md` with two independent slices that deliberately edit the same line of the same file. Run `/dispatch fixture-conflict`. Confirm: first branch merges clean; second branch conflicts; merge-fix sub-agent spawns with the right brief; on `done` the merge commit lands; on `needs-review` the orchestrator surfaces the reason without reading the conflicted code itself.

**Human checkpoint:** no

**Depends on:** parallel-worktrees

---

### `human-checkpoint` — Needs-review surface and feedback dispatch

**Status:** done

**Outside-in:** When a sub-agent emits `<status reason="...">needs-review</status>` for a slice marked `Human checkpoint: yes`, the orchestrator surfaces only the reason, the path to the relevant log entry, and the output of `git diff --name-only` for the worktree branch — no slice code. On user feedback, it spawns a fresh sub-agent with the feedback inlined into the brief; on approval, it marks the slice `done`.

**Feedback loop:** Construct `docs/fixture-checkpoint/fixture-checkpoint.tasks.md` with one slice marked `Human checkpoint: yes`. Run `/dispatch fixture-checkpoint`. Confirm: the orchestrator's pause message contains the reason + log path + changed-file list and nothing else (no code). Reply with a change request; confirm a new sub-agent spawns with the feedback in its brief and the orchestrator's own context did not grow with code reads.

**Human checkpoint:** no

**Depends on:** merge-flow

---

### `qa-generation` — End-of-run QA plan and stop

**Status:** done

**Outside-in:** When no unblocked slices remain and all are `done`, the orchestrator reads `{feature}.tasks.md` and `{feature}.log.md`, writes `docs/{feature}/{feature}.qa.md` using `qa-template.md`, tells the user the path, and stops completely.

**Feedback loop:** Run `/dispatch` against a small completed fixture DAG. Confirm `qa.md` is written, weighted toward log entries with deviations or `Human checkpoint: yes` slices, and the orchestrator outputs no further suggestions or next-step offers after pointing at the file.

**Human checkpoint:** no

**Depends on:** human-checkpoint
