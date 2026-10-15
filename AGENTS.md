# Responda monorepo instructions

This repository contains the three Responda applications and the shared project
memory.

## Required context check

Before inspecting broadly or editing project files:

1. Read `memory/INDEX.md`.
2. Read `memory/CURRENT_STATE.md` and `memory/DECISIONS.md`.
3. Read only the component note relevant to the task.
4. Query Graphify before broad codebase searches when the combined graph exists.

The current source code is stronger evidence than a memory note. When they
disagree, verify the code and update the note.

## Repository structure

- `mobile/` — Flutter citizen application.
- `backend/` — Python/FastAPI service and PostgreSQL models/migrations.
- `web/` — React/Vite MDRRMO dashboard.
- `memory/` — concise Obsidian project memory.
- `scripts/` — memory and Graphify maintenance.

## Project memory protocol

After material project work:

- Update `memory/CURRENT_STATE.md` when implementation status changes.
- Add durable choices to `memory/DECISIONS.md`.
- Update `memory/NEXT_STEPS.md` when priorities change.
- Append a short dated outcome and verification entry to `memory/WORK_LOG.md`.
- Save conclusions and decisions, not full chat transcripts or every prompt.
- Never record passwords, API keys, tokens, `.env` values, personal IDs, phone
  numbers, or raw emergency-report content.

### Explicit `save` command

When the user types `save` as a standalone instruction, create a comprehensive
but concise checkpoint of the current work:

- Update `memory/CURRENT_STATE.md`, `memory/DECISIONS.md`, and
  `memory/NEXT_STEPS.md` wherever the conversation changed them.
- Append the completed work, verification, affected components, blockers, and
  next action to `memory/WORK_LOG.md`.
- Preserve all material requirements and conclusions since the previous save,
  but do not copy the raw chat transcript.
- Run `./scripts/check-project-memory.sh`.
- If source code changed since the last Graphify build, refresh the affected
  component graph, or use `./scripts/update-project-graph.sh all` when several
  components changed.
- Report exactly what was saved.

`save` does not authorize a Git commit or remote push. Only commit or push when
the user explicitly asks, such as `save and commit` or `save and push`.

## Graphify

The combined graph is generated at `graphify-out/graph.json` and is intentionally
not committed.

```bash
graphify query "<question>" --graph graphify-out/graph.json
graphify explain "<concept>" --graph graphify-out/graph.json
graphify affected "<concept>" --graph graphify-out/graph.json
./scripts/update-project-graph.sh all
```

After changing only one component, replace `all` with `mobile`, `backend`, or
`web`. The scan is code-only and does not require an API key.

## Verification

- Backend: `(cd backend && make check)`
- Web: `(cd web && npm run lint && npm run build)`
- Mobile: `(cd mobile && flutter analyze && flutter test)`
- Memory only: `./scripts/check-project-memory.sh`
