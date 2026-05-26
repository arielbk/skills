# Bare-repo layout detection

A "bare-repo layout" is the convention where a clone lives as:

```
<root>/
  .bare/           # bare git repository
  .git             # a regular file containing `gitdir: ./.bare`
  main/            # a worktree
  feat-x/          # another worktree
```

The shared git dir has no working tree of its own; every checkout is a linked worktree sitting beside `.bare/`. New worktrees should be created as siblings (`<root>/<slug>`), not nested under `.worktrees/`.

## Detection

After step 1 of the SKILL has resolved the parent repo, you know `git_common` (the shared git dir, e.g. `<root>/.bare`). The layout is bare-repo iff:

1. `git_common` itself has no working tree — `git --git-dir="$git_common" rev-parse --is-bare-repository` returns `true`.
2. At least one existing linked worktree sits as a sibling of `git_common` — i.e. its path's parent equals `dirname "$git_common"`.

Snippet:

```bash
detect_bare_layout() {
  local git_common="$1"
  local parent
  parent=$(dirname "$git_common")

  # Condition 1: shared git dir is bare.
  [ "$(git --git-dir="$git_common" rev-parse --is-bare-repository 2>/dev/null)" = "true" ] \
    || { echo "false"; return; }

  # Condition 2: at least one linked worktree is a sibling of $git_common.
  local found=false
  while IFS= read -r line; do
    case "$line" in
      worktree\ *)
        local wt="${line#worktree }"
        if [ "$(dirname "$wt")" = "$parent" ] && [ "$wt" != "$git_common" ]; then
          found=true
          break
        fi
        ;;
    esac
  done < <(git --git-dir="$git_common" worktree list --porcelain)

  if $found; then
    echo "true $parent"
  else
    echo "false"
  fi
}
```

Output is `false` or `true <sibling-root>`. The SKILL uses `<sibling-root>` as the directory containing `.bare/` and the existing worktrees, then places the new one at `<sibling-root>/<slug>`.

## Why both conditions

Condition 1 alone is not enough — a plain bare clone with no worktrees yet would also pass it, and there is no established sibling layout to follow. Requiring at least one existing sibling worktree means the layout is in active use; otherwise treat the repo as a normal clone and fall back to `.worktrees/<slug>`.

## What this skips

- Conversion. The skill never *creates* a bare-repo layout; it only respects one when it sees it.
- Layouts where the bare dir is named something other than `.bare/`. Detection keys on "is bare + has sibling worktrees", so any directory name works as long as the structure matches.
