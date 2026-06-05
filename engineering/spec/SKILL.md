---
name: spec
description: Turn the current conversation context into a PRD written to docs/{feature}/{feature}.prd.md. Use when user wants to create a spec or PRD from the current context.
---

# Spec

Synthesise the current conversation context and codebase understanding into a PRD written to `docs/{feature}/{feature}.prd.md`. Do NOT interview the user — synthesise what you already know.

## Process

### 1. Derive the feature slug

Generate a kebab-case slug from the feature being described (e.g. `checkout-flow`, `dark-mode`). Confirm with the user if ambiguous.

### 2. Explore the codebase

Understand the current state of the relevant areas. Use the project's domain glossary vocabulary throughout the PRD, and respect any ADRs in the area you're touching.

Prefer delegating the exploration to the read-only `Explore` sub-agent: pass the feature brief and require a map of at most ~30 lines — one finding per line with a `file:line` reference, no file contents — covering the modules touched, prior art, glossary terms, and relevant ADRs. Read a specific file yourself only when a PRD decision turns on its exact contents.

### 3. Collect resources

Scan the conversation for any resource links — Figma boards, Notion docs, design specs, external APIs, tickets. Include them in the PRD's Resources section so implementing agents know what's fetchable. If an MCP server exists for a linked resource (e.g. Figma), note that the agent can use it to pull assets directly.

### 4. Sketch modules

Identify the major modules to build or modify. Look for opportunities to extract deep modules — small interfaces that encapsulate significant complexity and can be tested in isolation.

Check with the user that the modules match their expectations, and which they want tests written for.

### 5. Write the PRD

Create `docs/{feature}/` if it doesn't exist. Write `docs/{feature}/{feature}.prd.md` using the template below.

The file is ephemeral by default — the team may delete it once the feature ships, or keep it for review and reference. Do not reference it in code comments.

### 6. Stop

Tell the user the PRD is at `docs/{feature}/{feature}.prd.md`. Then stop completely — do not suggest next steps, offer to slice, or offer to implement. The user will `/clear` and continue when they're ready.

## Template

```markdown
# PRD: {Feature name}

## Resources

{Links from the conversation — Figma, Notion, tickets, APIs, etc. For each, note whether an MCP server is available to fetch assets from it. Omit section if no links were provided.}

## Problem Statement

{The problem the user is facing, from the user's perspective.}

## Solution

{The solution, from the user's perspective.}

## User Stories

{A numbered list of user stories. Be extensive — cover all aspects of the feature.}

1. As a {actor}, I want {feature}, so that {benefit}.

## Implementation Decisions

{Modules to build or modify, their interfaces, architectural decisions, schema changes, API contracts. Do NOT include specific file paths or code snippets — they go stale quickly.}

## Testing Decisions

{What makes a good test for this feature. Which modules will be tested. Any prior art in the codebase.}

## Out of Scope

{What this PRD explicitly does not cover.}

## Open Questions

{Unresolved questions. Remove this section when all questions are answered.}
```
