# Fixture: single-slice dispatch

A minimal one-slice DAG used to feedback-loop the `dispatch` skill's single-slice path. Running `/dispatch fixture-single` should spawn exactly one sub-agent, which writes the placeholder file and reports `done`.

## Slices

### `placeholder-file` — Write a placeholder output file

**Status:** not-started

**Outside-in:** A placeholder file at `docs/fixture-single/output.txt` exists and contains exactly the text `hello` (no trailing newline required, but allowed).

**Feedback loop:** `cat docs/fixture-single/output.txt` prints `hello`.

**Human checkpoint:** no

**Depends on:** none
