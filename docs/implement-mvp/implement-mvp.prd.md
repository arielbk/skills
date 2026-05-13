# PRD: Implement skill — MVP redesign

## Problem Statement

The user has two skills for executing a feature's task slice DAG: `implement` and `dispatch`. `dispatch` is the heavy variant — it always delegates every slice to a fresh sub-agent, runs parallel slices in worktrees, has a merge-fix sub-agent, and enforces a strict "orchestrator never reads slice code" rule. The user tried it on a real feature and found it overkill: too many tokens spent on cold-context spawns, too much ceremony for sequential work.

`implement` today is the lighter variant but is underspecified relative to what the user actually wants:

- Its parallel branch parallelizes any pair of unblocked slices with no collision check, no isolation, and a loose handoff that pastes full slice specs into the brief — risking merge corruption and pulling slice content into the orchestrator's context.
- Its QA generation fires when no unblocked slices remain, even if some slices are `blocked` or `needs-review`, producing a misleading "complete" QA plan.
- It has no clear guidance for when the orchestrator should do slice work inline vs delegate to a sub-agent.

The user wants `implement` to be the day-to-day driver, with the *best* aspects of `dispatch` absorbed but the heavy machinery dropped.

## Solution

Redesign `implement` as the MVP of `dispatch`:

- **Sequential only.** Never parallelize, even when multiple slices are unblocked. Run them one at a time. This eliminates the entire worktree-isolation and merge-fix surface.
- **Hybrid execution model.** The orchestrator does slice work inline by default; it can choose to delegate a single slice to a fresh sub-agent based on judgment. Two named signals justify delegation: orchestrator context is getting heavy, or the slice touches a cold area of the codebase the orchestrator hasn't loaded. Otherwise inline.
- **Strict handoff contract when delegating.** Borrow `dispatch`'s minimal-brief pattern (slug + paths + pointer to a slice-prompt resource) and the `<status>` tag reply contract. The orchestrator never pastes slice content into the brief.
- **Asymmetric human-checkpoint surface.** When a slice ran inline, the orchestrator gives a real summary (it knows the work). When a slice was delegated, the orchestrator surfaces strictly — slug + reason + log path + `git diff --name-only` only — because reading the slice code would defeat the delegation.
- **Strict QA gating.** Generate the QA plan only when *every* slice is `done`. Any non-done slice surfaces a status report and stops.
- **Self-contained skill.** `implement` keeps its own `resources/` directory with its own copies of `tdd-loop.md`, `log-format.md`, `qa-template.md`, plus its own simpler `slice-prompt.md` and a new `delegation-handoff.md`. No filesystem dependencies on the `dispatch` skill.

## User Stories

1. As the user, I want `/implement {feature}` to run a feature's slice DAG sequentially in one orchestrator session, so I don't pay the per-slice cold-context tax of `dispatch`.
2. As the user, I want the orchestrator to *choose* whether to delegate a slice to a sub-agent based on context-weight and cold-area signals, so token usage stays low without me micromanaging.
3. As the user, I want delegation to use a strict minimal-brief + `<status>` tag contract, so slice content never leaks into the orchestrator's transcript.
4. As the user, I want delegated slices to read the slice-prompt resource themselves, so the handoff stays minimal regardless of slice size.
5. As the user, I want human-checkpoint surfaces to give me a real summary for inline slices and a strict path-only surface for delegated ones, so the surface fidelity matches what the orchestrator actually knows.
6. As the user, I want change-requests on a previously-delegated slice to spawn a fresh sub-agent (never inline-fix), so the orchestrator doesn't have to load that slice's context to address feedback.
7. As the user, I want the orchestrator to re-read the tasks file after every delegated return, so a stale in-memory copy doesn't cause double-dispatch or wrong status decisions.
8. As the user, I want QA generation to refuse if any slice is `blocked`, `needs-review`, or `in-progress`, so I don't get a falsely-complete QA plan.
9. As the user, I want `implement` to work standalone — no shared files with `dispatch` — so I can install or remove either skill without breaking the other.
10. As the user, I want the skill to stop completely when QA is written or work is paused, with no offers of next steps, so I can `/clear` cleanly.

## Implementation Decisions

### Skill structure

`skills/engineering/implement/` keeps its current shape but updates contents:

- `SKILL.md` — slim orchestrator process, references resources via progressive disclosure.
- `resources/tdd-loop.md` — same as today (and as `dispatch`'s copy). Loaded by orchestrator before inline TDD work, and referenced by `slice-prompt.md` for delegated slices.
- `resources/log-format.md` — same as today.
- `resources/qa-template.md` — same as today.
- `resources/slice-prompt.md` — **new file**, a simplified version of `dispatch`'s slice-prompt. Defines the slice-agent role, required reads, and `<status>` output contract. Drops worktree/merge-fix concerns since `implement` never delegates in parallel.
- `resources/delegation-handoff.md` — **new file**, loaded by the orchestrator only when it decides to delegate. Contains: the delegation signals restated with examples; the exact spawn-message template (slug + `TASKS_PATH` + `LOG_PATH` + `SLICE_PROMPT_PATH`).

### Orchestrator process (SKILL.md)

1. **Identify the feature** — same as today.
2. **Read the tasks file** — parse slugs, statuses, `Depends on:`.
3. **Identify the next unblocked slice** — pick exactly one (lowest in file order if multiple). Sequential is enforced here.
   - None unblocked, all done → step 8 (QA gate).
   - None unblocked, some non-done → surface non-done state, stop.
   - One unblocked → step 4.
4. **Decide: inline or delegate?**
   - Default: inline.
   - Delegate when context is heavy or the slice touches a cold area. Loaded guidance: `resources/delegation-handoff.md`.
5. **Execute.**
   - **Inline path:** load `tdd-loop.md`, set status `in-progress`, work the red-green loop, write log entry per `log-format.md`, set status `done` (or `needs-review` if `Human checkpoint: yes`).
   - **Delegate path:** load `delegation-handoff.md`, spawn one sub-agent with the minimal brief. Sub-agent reads `slice-prompt.md` first, then locates its slice by slug in the tasks file, runs TDD, writes its log entry, updates only its own row, ends reply with `<status>` tag.
6. **Parse the sub-agent's `<status>` tag** (delegated path only) — same three forms as `dispatch`: `done`, `needs-review` with `reason`, `blocked` with `reason`. Re-read the tasks file after a delegated return.
7. **Handle human checkpoints** (when status becomes `needs-review`, either inline or delegated):
   - **Inline:** rich summary (key decisions, files touched, what was built). Pause for user.
   - **Delegated:** strict surface — slug + verbatim reason + log path + `git diff --name-only`. Never read changed files. Pause for user.
   - **User approval** → mark `done`, return to step 3.
   - **User change-request:**
     - If originally inline → orchestrator addresses feedback inline, writes a new log entry.
     - If originally delegated → spawn a fresh sub-agent with feedback verbatim in the brief; never inline-fix delegated work.
8. **QA gate.** If every slice is `done`, generate `docs/{feature}/{feature}.qa.md` per `qa-template.md`, weighted toward human-checkpoint slices and log entries with deviations. Tell the user the path. Stop completely.
   - If any slice is non-`done`, surface the status report (slug + status + reason for each non-done slice) and stop. No QA file written.

### Constraints carried over from `dispatch` (when delegating)

- Minimal brief — never paste slice content into the spawn message.
- Re-read tasks file after every delegated return.
- The orchestrator's only inputs to the human-checkpoint surface for a delegated slice are: slug, `reason` attribute, log path, `git diff --name-only` output.
- Default sub-agent model: `sonnet`. No worktree isolation (sequential, no merge concern).

### Constraints intentionally *not* carried over

- No "never read slice code" rule. The orchestrator does slice work inline and reads code constantly; a carve-out for previously-delegated code would be incoherent and would push toward cascading delegation.
- No worktree isolation. Sequential execution makes this unnecessary.
- No merge-fix sub-agent. Sequential execution makes this unnecessary.
- No always-delegate rule. Inline is the explicit default.

## Testing Decisions

This skill is documentation and orchestration logic, not code, so "tests" here means the skill behaves correctly when invoked on representative task DAGs. The existing fixture features in `docs/` (`fixture-single`, `fixture-checkpoint`, `fixture-parallel`, `fixture-conflict`) provide ready test scenarios:

- **`fixture-single`** — exercises the inline path on a single-slice feature.
- **`fixture-checkpoint`** — exercises the inline + human-checkpoint path with the rich summary surface.
- **`fixture-parallel`** — under the new design, runs sequentially; verifies the skill no longer spawns parallel agents.
- **`fixture-conflict`** — under the new design, runs sequentially with no merge-fix path; verifies the skill correctly avoids the parallel/conflict surface entirely.

A new fixture is worth adding for the **delegation path**: a feature where one slice is in a cold area of the codebase, exercising the orchestrator's judgment to delegate and the strict surface on `needs-review`.

QA on the skill itself is empirical — run it on a real feature and check that token usage is meaningfully lower than `dispatch` while the QA plan it produces is faithful.

## Out of Scope

- Parallel slice execution. Removed entirely.
- Worktree isolation. Removed entirely.
- Merge-fix sub-agent. Removed entirely.
- File-collision heuristics on slice specs (would require a `Touches:` field on the slice template; deferred until sequential-only feels too slow in practice).
- Sharing files with `dispatch` via filesystem path or via a third skill. Each skill stays self-contained.
- Promoting `tdd-loop`, `log-format`, or `qa-template` into reusable standalone skills.
- A user-facing override to force inline or force delegate per slice. Orchestrator judgment is the only mechanism.
- Partial QA generation when slices are non-done. The gate is strict.

## Open Questions

- Should `delegation-handoff.md` include any worked examples of the two delegation signals, or stay rule-only? Recommend rule-only for the MVP and add examples once the user has run it on a real feature and noticed gaps.
- Should the inline-path human-checkpoint summary have a fixed structure (e.g., "what was built / key decisions / files touched") or be free-form? Recommend free-form initially — fixed structure can come from observed friction.
