# Gather sources

Sweep everything below for the window since the **last sent** edition. Group finds
under the section-template headings as you go.

## Vendor releases and changelogs

- **Anthropic news** — `anthropic.com/news` — model launches, availability and
  pricing changes, policy/retention notes
- **OpenAI** — `openai.com/index` — model launches, benchmark claims
- **Cursor changelog** — `cursor.com/changelog` — versioned; note the version
  number and date for anything kept
- **Claude Code release notes** — features, research previews
- Other labs as they surface: xAI, Mistral, Google, open-weight releases

Changelog items are the easiest thing to over-include. A changelog line only
earns a place if it changes how someone **works** — July kept Cursor Remote
Control and dropped Side Chats, Customize and team MCPs, because only the first
described a workflow.

## Infinum Slack

The community section comes from here. Read since the last sent edition:

- `#ai-accelerated-engineering` — the main channel; experiments, takes, security
  finds
- `#team-frontend`

Look for: workflow tricks someone actually runs, skills/plugins built in-house,
side-project experiments, security warnings, and **threads** — a thread with
several voices is usually a beat, not an item. Capture the Slack permalink and
the person's name at gather time; both are needed in prose.

## Internal talks and infra

- Recorded talks (Drive) and standup sessions
- `infinum/ai` repo changes, marketplace plugins and skills

Much of this is too internal to ship — park it under an "Infinum infra (probably
too internal)" heading rather than dropping it. July's cloud-agent workflows talk
was parked there and later promoted to a real beat when the frontier frame
changed.

## Thinkpieces

Blogs that recur: Geoffrey Litt, Addy Osmani, fsck.com, Infinum's own blog. These
feed the "At the frontier" close more often than the body.

## Clippings

**Sweep the vault's `Clippings/` folder every time.** Ariel saves articles he
means to come back to, and they are among the highest-signal sources in the
sweep — pieces he already judged worth keeping, months before the edition needs
them. Filter by save date for the window, but read the publish date too: a
clipping saved in-window can be a year old and stale as news.

Git history for the folder is empty after the vault restructure, so file
birthtime/mtime is the only date signal available.

## Ariel's own context

Not a feed, but the highest-signal source — what he's actually been trying,
Things tasks about AI, and 1:1s that produce a one-off addition to the sign-off
(July invited the team to a pre-workshop AI survey).

## Filters

- **Skip anything politically charged** — the audience is JS devs; keep it technical
- **Check recall against the record.** Half-remembered names and attributions come
  up in the walkthrough; verify every one against Slack before it reaches prose
- **Resolve Slack handles to real people before attributing.** Display names and
  full names are both in the export and they collide — `vasko` is Filip Voska.
  Two entries for one person means prose credits them twice under two names.
  Run every contributor through `slack_search_users` at gather time
- **Re-check the status of anything still in flight.** A PR that was "in review"
  during the sweep may have merged before the scope session, let alone the send
- **Note staleness.** An item that sat for a month usually shouldn't ship
