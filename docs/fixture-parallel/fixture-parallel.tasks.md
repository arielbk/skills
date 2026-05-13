# Fixture: parallel — exercise dispatch's parallel worktree path

A throwaway feature DAG used to validate the `parallel-worktrees` slice of `dispatch`. Two independent slices that touch different files; they should be spawned in parallel into separate worktrees and merged cleanly back into the working tree.

## Slices

### `write-alpha` — Write the alpha output file

**Status:** not-started

**Outside-in:** Running this slice produces `docs/fixture-parallel/output-a.txt` containing the single word `alpha` followed by a trailing newline.

**Feedback loop:** `cat docs/fixture-parallel/output-a.txt` prints `alpha`.

**Human checkpoint:** no

**Depends on:** none

---

### `write-bravo` — Write the bravo output file

**Status:** not-started

**Outside-in:** Running this slice produces `docs/fixture-parallel/output-b.txt` containing the single word `bravo` followed by a trailing newline.

**Feedback loop:** `cat docs/fixture-parallel/output-b.txt` prints `bravo`.

**Human checkpoint:** no

**Depends on:** none
