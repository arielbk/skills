# Recording

Recorder rules: `agent-browser` only (`agent-browser skills get core` for usage), viewport 1440x900,
**one clip per beat**, never record a wait. Record the beat's actions, stop, wait off camera, then
record the arrival as its own clip (or record through the very end of the wait and leave a trim hint).

```bash
agent-browser set viewport 1440 900
agent-browser record start <run>/clips/03-topic-appears.webm <url>
# ... actions ...
agent-browser record stop
```

## Before the first clip

- **Logged-in sites (GitHub, private apps).** Use a dedicated persistent profile. The user logs in
  once by hand:
  `agent-browser --headed --profile ~/.agent-browser/<name> open https://github.com/login`
  and every later command passes `--profile ~/.agent-browser/<name>`. Copying the user's own browser
  profile doesn't work (singleton lock, keychain-encrypted cookies). A daemon that is already running
  ignores `--profile` and `--headed`: run `agent-browser close --all` first. Verify the login (for
  GitHub, `meta[name=user-login]` is non-empty) before filming.
- **Keep the screen awake.** `caffeinate -dimu -t 5400 &`. A locked or sleeping screen stops Chrome
  painting: `requestAnimationFrame` never fires, `screenshot` hangs and wedges the daemon queue, while
  JS eval still works. If that happens, stop and ask the user to unlock; don't keep trying.
- Check the app's state and settings are what SCRIPT.md expects (read the API, change nothing).

## Gotchas while filming

- **Click positions can double after `record start`** (coordinate input lands at 2x the CSS px), and
  the miss is silent. Prefer the keyboard and DOM: `find text "..."`/role selectors, `focus` +
  keyboard, `element.click()` via eval, `fill` for text. On GitHub's Files changed view: focus the
  line cell, ArrowRight to reveal "Add comment", click it through the DOM, `fill` the box. Verify the
  result (the posted comment exists) after every action that matters.
- **Each `record start` leaves its tab open.** Close stale tabs between clips; closing the last tab
  relaunches the browser with an extra new-tab page.
- `agent-browser screenshot` can capture at 2x. Take stills from the clip's last frame instead:
  `ffmpeg -sseof -0.1 -i clip.webm -frames:v 1 frames/clip.png`.
- Paste text (`fill`) rather than typing it live; the edit can't make typing readable anyway.
- Post comments as single comments, never start a pending review (or the platform's equivalent),
  so each one triggers its webhook on its own.
- Hold 2–3 s on every end state; the edit can trim but can't invent a hold of real motion.
- Don't hover anything whose tooltip shows internals. Don't open settings or token pages.
- Watch for dialogs that show attribution or internals (a merge dialog listing `Co-authored-by:`
  lines with a model name). Note the exact seconds in the trim hints so the edit cuts around them.

## RECORDING.md format

```markdown
# Recording (run YYYY-MM-DD)

Status: complete | partial (why). Sessions and interruptions.

**Edit order:** 01, 02, 02b, 03, ... (what replaces what, which ending to use)

Notes that change the story: labels that differ from SCRIPT.md (what the product actually named
things), beats moved or dropped, anything filmed off camera.

| # | File | Beats | Raw dur | On screen | Caption (SCRIPT.md) | Trim hints |
|---|------|-------|---------|-----------|---------------------|------------|
| 1 | clips/01-empty-app.webm | B01 | 24.1 s | 0–6 s overview "No topics yet"; then ... | "..." | First ~1 s page load. Keep ~3 s of each view. |

Trim hints say where page loads, dead stretches, best stills, and anything that must not be shown
(with seconds) are.

## External artefacts created (for cleanup)

Per system: every comment/PR/branch/record/upload ID the recording created, merges with their
commit SHAs, app state IDs. This list is the inventory for the final clean slate.
```

Also keep `logs/recorder-issues.md`: product misbehaviour (separately from tooling problems), with
what was done about each.
