---
tags:
  - responda/memory
  - responda/index
updated: 2026-10-15
---

# Responda memory index

Read these notes in this order when beginning a new project task:

1. [[PROJECT_OVERVIEW]] — what Responda is and its system boundary.
2. [[CURRENT_STATE]] — what is implemented now.
3. [[DECISIONS]] — choices that should not be rediscovered each session.
4. [[PROJECT_MAP]] — exact folders, entry points, and commands.
5. [[NEXT_STEPS]] — current implementation priorities.

Use [[ARCHITECTURE]] for data flow and component responsibilities. Use
[[WORK_LOG]] when the reason for a recent change matters.

## Memory rules

- Keep this vault concise and factual.
- Record decisions and outcomes, not complete chat transcripts.
- Verify changing technical facts against the source code.
- Never store secrets, `.env` contents, private keys, authentication tokens,
  personal IDs, phone numbers, or real emergency-report data.
- Mark proposals as proposals; do not present them as implemented.

## Chat save command

When the user types `save`, capture every material requirement, decision,
completed task, verification result, blocker, and next step from the current
work into the appropriate memory notes and work log. Do not store a verbatim
chat transcript or any secret, credential, personal identifier, phone number,
or real emergency-report content.

The `save` command updates local project memory and refreshes Graphify when
needed. It does not commit or push unless the user explicitly asks for that.

## Generated navigation

- Graphify HTML: `graphify-out/graph.html`
- Graphify report: `graphify-out/GRAPH_REPORT.md`
- Graphify Obsidian canvas: `graphify-notes/graph.canvas`
- Generated Graphify node notes: `graphify-notes/`
