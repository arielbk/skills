---
name: worktree
description: Create a ready-to-work git worktree for a topic — slugifies the topic into a branch, places the worktree at `.worktrees/<slug>` (or as a sibling in bare-repo layouts), copies local-only files like `.env` and `.claude/settings.local.json`, and runs the JS package manager's install. Use when the user says `/worktree <topic>`, "spin up a worktree", or when an agent decides to do new work on its own branch. Agents — infer a topic slug from the surrounding conversation before invoking; only prompt the user if no signal exists.
---

# Worktree

Spin up a worktree that is *actually ready to work in*: branched, isolated, with local-only files copied and dependencies installed. One worktree per invocation. No subcommands.

> **Free-form questions only.** If you need to ask the user for a topic, ask plain text in the chat. Do NOT use the `AskUserQuestion` multi-choice UI.

## Procedure

### 1. Resolve invocation context

Run from wherever the caller is. Read git's view of the current location:

```bash
git_dir=$(git rev-parse --git-dir 2>/dev/null) || { echo "not a git repo"; exit 1; }
git_common=$(git rev-parse --git-common-dir)
super=$(git rev-parse --show-superproject-working-tree 2>/dev/null)
```

- **Not in a git repo** → report and stop.
- **Inside a submodule** (`super` is non-empty) → treat as a normal repo. Do not climb to the superproject; submodules have their own worktrees.
- **Inside a linked worktree** (`git_dir != git_common`, and not a submodule) → resolve the parent repo's working root and continue from there. The new worktree must be a *sibling* of the current one, not nested inside it.

  ```bash
  parent_root=$(git -C "$(dirname "$git_common")" rev-parse --show-toplevel 2>/dev/null \
              || dirname "$git_common")
  cd "$parent_root"
  ```

- **Otherwise** → already at a working root. Continue from `git rev-parse --show-toplevel`.

The rest of the procedure runs with the *resolved parent* as the source checkout.

### 2. Detect bare-repo layout

Some users keep a `.bare/` clone with `.git` as a pointer file and worktrees as siblings. See [resources/bare-repo-detection.md](resources/bare-repo-detection.md) for the detection snippet — load it only if you need to handle this layout. Output: `bare_layout=true|false` and (if true) `sibling_root=<dir>` (the directory containing `.bare/` and the existing worktrees).

### 3. Resolve topic and slug

Topic source priority:

1. Argument the caller passed (`/worktree fix login button` → `fix login button`).
2. Topic an agent inferred from conversation context.
3. Ask the user plain text: **"What should I call this worktree?"** No multi-choice UI, no auto-generated `worktree-<timestamp>` fallback.

Slugify:

- Lowercase.
- Whitespace runs → single `-`.
- Preserve `/` (so `feat/login` stays `feat/login`).
- Strip characters outside `[a-z0-9/_-]`.
- Collapse repeated `-`.
- Trim leading/trailing `-` from each `/`-separated segment.

Branch name = slug. Directory basename = slug.

### 4. Choose worktree path

- **Bare-repo layout** → `path="$sibling_root/$slug"`. Skip the gitignore step.
- **Normal clone** → `path="$repo_root/.worktrees/$slug"`. Enforce gitignore safety:

  ```bash
  if ! git check-ignore -q .worktrees/.placeholder 2>/dev/null \
     && ! grep -qxE '\.worktrees/?' .gitignore 2>/dev/null; then
    printf '\n.worktrees/\n' >> .gitignore
    git add .gitignore
    git commit -m 'chore: gitignore .worktrees/'
  fi
  ```

  Commit before `git worktree add` runs. If `.gitignore` already covers `.worktrees/`, skip silently.

### 5. Create the worktree

```bash
git worktree add "$path" -b "$slug"
```

- If the branch already exists, **stop with an error**. Do not overwrite. The user can re-run with their own `git worktree add "$path" "$slug"` if reusing an existing branch is intentional.
- On any other failure (permission denied, sandbox restriction, disk full) → report the exact stderr and stop. Do not roll back the gitignore commit; do not try to "work in place" as a fallback. The caller decides next step.

### 6. Copy local-only files

Fixed allowlist lives at [resources/copy-allowlist.txt](resources/copy-allowlist.txt). Read it, strip blank lines and `#` comments.

Per-project extension: if `.claude/worktree-copy.txt` exists in the *source checkout*, read it the same way and append its entries. (See [resources/worktree-copy.example.txt](resources/worktree-copy.example.txt) for the format users put in their repos.)

For each path in the final list:

- If it exists in the source checkout → copy preserving mode (`cp -p`) to the same relative path in `$path`. Create parent directories as needed.
- If it doesn't exist → skip silently.

Record the list of files actually copied for the final report.

### 7. Install dependencies

Detect the JS package manager from lockfiles in `$path`, in priority order:

| Lockfile present | Command |
|---|---|
| `pnpm-lock.yaml` | `pnpm install` |
| `yarn.lock` | `yarn install` |
| `package-lock.json` | `npm install` |
| `package.json` only | `npm install` |
| none of the above | skip step 7 entirely |

Run with `$path` as cwd. Stream output so the user sees progress. On non-zero exit, report the exit code and the tail of stderr; do **not** roll back — the worktree stays so the developer can `cd` in and debug.

### 8. Report

Print exactly:

- **Path:** absolute path to the new worktree.
- **Branch:** the slug.
- **Layout:** `bare-repo (sibling)` or `.worktrees/`.
- **Copied:** comma-separated list of files actually copied, or `none`.
- **Install:** the command run and its outcome (`ok` / `failed (exit N)`), or `no package manager detected`.

No suggested next steps. The caller decides what to do next.
