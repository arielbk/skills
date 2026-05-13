# QA Plan: Dispatch

## What was built

A new `dispatch` skill that orchestrates a `{feature}.tasks.md` DAG by always delegating slice work to sub-agents (single in-place spawn, or parallel worktree-isolated spawns), parses `<status>` tags, handles merges (clean + merge-fix sub-agent on conflict), surfaces `needs-review` minimally, and writes an end-of-run QA plan. Also added a free-form-questions rule to `slice` and `grill-me` (forbidding the `AskUserQuestion` multi-choice UI).

## Human verification required

No slices were marked `Human checkpoint: yes`, but several behaviours are prose-only and only validate empirically. Run these in a fresh session:

- [ ] `/grill-me` against any small plan: confirm questions arrive as plain text, never the multi-choice UI.
- [ ] `/slice` reaching step 5 grilling: same — plain text only. Confirm step 7's stop message mentions both `/dispatch` and `/implement`.
- [ ] `/dispatch fixture-single`: orchestrator's spawn message contains slug + 3 absolute paths + pointer to `slice-prompt.md` only (no slice body). Sub-agent emits `<status>done</status>`. Tasks row flips to `done`.
- [ ] `/dispatch fixture-parallel`: two worktrees created concurrently, each branch merges cleanly via `git merge --no-ff`, both rows flip to `done`.
- [ ] `/dispatch fixture-conflict`: first branch merges clean; second hits a conflict in `shared.txt`; merge-fix sub-agent spawns with conflicted-file paths + both log entries + both slice specs; on `done`, orchestrator runs `git commit --no-edit`. Confirm orchestrator never reads conflict markers itself.
- [ ] `/dispatch fixture-checkpoint`: orchestrator's pause message contains exactly four elements (slug, reason verbatim, log path, `git diff --name-only` paths) — no code. Reply with a change request; confirm a fresh sub-agent spawns with the feedback inlined and the orchestrator's context did not grow with code reads.
- [ ] After a completed run: `qa.md` is written, weighted toward log entries with deviations / `Human checkpoint: yes` slices; orchestrator outputs a single "QA plan written: {path}" line and stops — no next-step offers.

## Watch closely

- [ ] **`merge-flow` boundary asymmetry.** The merge-fix agent is the *only* agent allowed to read conflict markers; it runs in the main working tree (no worktree isolation) because the in-progress merge state lives there. The orchestrator runs `git commit --no-edit` itself rather than letting the merge-fix agent commit. Verify both invariants on the conflict fixture — a regression here would either bloat orchestrator context or orphan staged resolutions.
- [ ] **Single-slice path stays in-place, parallel uses worktrees.** Per PRD, single spawns deliberately do not use `isolation: "worktree"`. Confirm the SKILL.md gates worktree isolation specifically on parallelism — not on every spawn.
- [ ] **`needs-review` surface convention.** The four-element minimal message (slug + reason + log path + paths-only file list) applies on every `needs-review` regardless of `Human checkpoint:` value. `Human checkpoint: no` slices that self-flag should surface the same minimal way.
- [ ] **Change-request spawn brief carries feedback verbatim.** No paraphrase, no code. Row resets to `in-progress`. Confirm via the checkpoint fixture.
- [ ] **File-collision gate is heuristic.** The orchestrator decides whether two unblocked slices touch the same file from slice headers / file mentions only — it must not read slice bodies. Worth a sanity check the prose enforces this.
- [ ] **`grill-me` lives outside this repo.** The free-form rule was applied at `~/.agents/skills/grill-me/SKILL.md` (symlinked into `~/.claude/skills/` and `~/.claude-infinum/skills/`). Future edits to `grill-me` must be made there, not in this repo.
- [ ] **Resources are intentionally duplicated.** `tdd-loop.md`, `log-format.md`, `qa-template.md` were copied byte-identical from `implement/resources/` rather than symlinked. Don't "DRY this up" — divergence is expected.
- [ ] **`slice-prompt.md` sibling-relative reads.** `slice-prompt.md` references `tdd-loop.md` and `log-format.md` as siblings; the orchestrator must pass the absolute path to `slice-prompt.md` so the sub-agent's relative reads resolve.

## Standard checks

- [ ] `skills/engineering/dispatch/SKILL.md` has valid frontmatter (name, description, trigger phrases incl. `/dispatch`).
- [ ] Three copied resource files (`tdd-loop.md`, `log-format.md`, `qa-template.md`) are byte-identical to `implement/resources/` versions: `diff -r skills/engineering/{dispatch,implement}/resources/` shows no differences except for the dispatch-only files (`slice-prompt.md`, `merge-fix-prompt.md`).
- [ ] Spawn-message template in step 4 is given verbatim and contains slug + 3 absolute paths only.
- [ ] Main loop reads coherently end-to-end: identify feature → parse DAG → unblocked → dispatch (single/parallel) → parse `<status>` → merge if worktree → surface if needs-review → conflict → merge-fix → loop → all done → QA → stop.
- [ ] `slice/SKILL.md` and `~/.agents/skills/grill-me/SKILL.md` both contain the free-form rule near the top.
- [ ] All five fixture files exist and are well-formed: `fixture-single`, `fixture-parallel`, `fixture-conflict`, `fixture-checkpoint`.
- [ ] `implement/SKILL.md` was not modified (coexistence chosen per PRD).
