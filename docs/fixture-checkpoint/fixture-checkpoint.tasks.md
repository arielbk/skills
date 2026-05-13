# fixture-checkpoint — tasks

Trivial fixture for empirically validating the `human-checkpoint` flow in `/dispatch`.

## Slices

### `placeholder-checkpoint` — Write a placeholder file and request review

**Status:** not-started

**Outside-in:** A slice agent writes `docs/fixture-checkpoint/placeholder.txt` containing the single line `placeholder for human-checkpoint fixture` and emits `<status reason="please confirm placeholder text reads correctly">needs-review</status>` so the orchestrator's checkpoint surfacing flow can be observed.

**Feedback loop:** Run `/dispatch fixture-checkpoint`. Confirm the orchestrator's pause message contains exactly: the slug, the `reason` verbatim, the log file path, and the changed-file list (paths only, including `placeholder.txt` and the log file). Reply with a change request like "make the text say 'updated placeholder' instead". Confirm a fresh sub-agent is spawned with that feedback inlined verbatim in its brief, and that the orchestrator's own context did not grow with reads of the placeholder file.

**Human checkpoint:** yes

**Depends on:** none
