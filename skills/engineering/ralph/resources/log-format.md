<!-- Vendored from skills/engineering/implement/resources/log-format.md (canonical) so /ralph is self-contained. Keep in sync. -->
# Log Entry Format

Append one entry to the feature's `{feature}.log.md` (sibling of the tasks file) after completing each slice.

The log is a running, append-only record. Under `/ralph`, each iteration runs in a fresh context with no memory of the prior one — the log is the **only** channel through which one iteration hands off to the next. Write entries so a fresh agent (or a human catching up) can read top-to-bottom and reconstruct what's been decided and what's still load-bearing.

```markdown
## `{slice-slug}` — {YYYY-MM-DD HH:MM:SS}

**Status:** done | blocked | needs-review
**Summary:** {What was built. One or two sentences.}
**Deviations:** {Any deviations from the plan, or "none".}
**Handoff:** {What the next agent (fresh context) needs to know — non-obvious decisions, gotchas, invariants now in place, follow-ups for downstream slices. Write "none" only if there is genuinely nothing.}
```

Use a local-time timestamp to the second (e.g. `2026-05-17 14:32:08`). Get it from `date '+%Y-%m-%d %H:%M:%S'` — do not guess. Keep entries factual and brief; they also feed the end-of-run QA plan, so focus on decisions with downstream consequences and anything that got weird.
