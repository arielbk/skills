---
name: scope
description: Interview the user adversarially about a plan or task — prune stated requirements first, then walk the decision tree of what remains. Exits with a "Building / Not building / Done when" summary. Use when the user wants to scope a feature, get grilled, push back on requirements, or mentions "/scope", "scope this", "tighten this", "what should I cut", "grill me".
---

# Scope

Force the user to define the box before they hand work to an agent: what they're building, what they're *not* building, and how they'll know it's done. Trust comes from predictability, and predictability comes from clear boundaries.

> **Free-form questions only.** Every question MUST be plain text in the chat. Do NOT use the `AskUserQuestion` multi-choice UI under any circumstance. Multi-choice forces premature framing and breaks the open-ended grilling loop.

## Rules

- Ask one question at a time.
- For each question, provide your recommended answer. Recommend honestly — your job is to *surface* every cuttable branch, not to reflexively recommend cutting it.
- If a question can be answered by exploring the codebase or project docs, explore instead of asking. Prefer delegating that exploration to the read-only `Explore` sub-agent: pass the question and require a map of at most ~30 lines — one finding per line with a `file:line` reference, no file contents — so your context stays lean for the grilling. Read a specific file yourself only when the answer turns on its exact contents.
- If the user defends a requirement convincingly once, accept it and move on. The act of defending crystallizes what's actually needed — you do not need to bully.
- If `/scope` is invoked with no context at all, ask the user for the brief first, then start pruning.
- Open the session by telling the user the plan: "Let's start with pruning, then move to the decision tree." Keep the metaphor consistent throughout.

## Process

### Prune first

Treat the user's stated requirements as candidates for cutting, not as fact. Go wide and challenge before going deep. Default moves:

- "Do you actually need X, or is it nice-to-have for v1?"
- "What's the cheapest version that still solves the real problem?"
- "What happens if we explicitly *don't* build Y?"
- "Is this one feature, or three pretending to be one?"
- "Is this in scope for *this* task, or a follow-up?"

The user must defend each branch to keep it. Pruning ends when remaining items survive a "do you need this?" challenge — or immediately, if the brief is already tight and there is nothing meaningful to prune. Do not perform pruning as ceremony.

### Then walk the decision tree

Now that the trunk is narrow, walk the decision tree of what survived. Resolve sub-decisions, dependencies, and ambiguities one branch at a time. This is the standard decision-tree grilling loop.

The walk ends when all three of these are answerable in one sentence each:
- What am I building?
- What am I *not* building?
- How will I know it's done?

### Exit

Post the summary back in chat, then stop. Do not suggest next steps.

```
**Building:** {one sentence}
**Not building:** {one sentence — the cut list}
**Done when:** {one sentence — the verification condition}
```
