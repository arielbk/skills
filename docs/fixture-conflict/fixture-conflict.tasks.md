# Fixture: Conflict

A two-slice fixture for empirically validating the `merge-flow` slice of `dispatch`. Both slices are independent (`Depends on: none`) so they unblock simultaneously and dispatch parallelises them. Both deliberately rewrite **the same line of the same file** (`docs/fixture-conflict/shared.txt`, line 1), so the second branch-merge after the first will conflict and trigger the merge-fix sub-agent path in `dispatch` step 6a.

The expected dispatch run:

1. Both `write-shared-alpha` and `write-shared-bravo` unblock and spawn in parallel worktrees.
2. The first to finish merges cleanly into the main working tree.
3. The second's `git merge --no-ff` returns non-zero — conflict on line 1 of `shared.txt`.
4. Dispatch spawns a merge-fix agent with both slugs, both log entries, both slice specs, and the conflicted-file path.
5. Merge-fix agent reads the markers, synthesises (or escalates), `git add`s, and reports `<status>done</status>` (or `needs-review`).
6. On `done`, dispatch runs `git commit --no-edit` — the merge commit lands.
7. On `needs-review`, dispatch surfaces the reason + log path + conflicted-file list **without reading the file itself**.

## Slices

### `write-shared-alpha` — Write "alpha" to shared.txt line 1

**Status:** not-started

**Outside-in:** After this slice runs, the file `docs/fixture-conflict/shared.txt` exists and its line 1 contains exactly the word `alpha` (followed by a newline).

**Feedback loop:** `head -n 1 docs/fixture-conflict/shared.txt` outputs `alpha`.

**Human checkpoint:** no

**Depends on:** none

---

### `write-shared-bravo` — Write "bravo" to shared.txt line 1

**Status:** not-started

**Outside-in:** After this slice runs, the file `docs/fixture-conflict/shared.txt` exists and its line 1 contains exactly the word `bravo` (followed by a newline).

**Feedback loop:** `head -n 1 docs/fixture-conflict/shared.txt` outputs `bravo`.

**Human checkpoint:** no

**Depends on:** none
