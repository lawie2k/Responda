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

## Model and chat efficiency protocol

### Ponytail working style

Use Ponytail's full style by default in every Responda chat: inspect the actual
flow and affected callers, then make the smallest complete change using existing
project patterns, platform features, and installed dependencies. Avoid speculative
features, unnecessary layers, and new dependencies for small tasks. Preserve
validation, security, accessibility, data protection, and required project checks.
Use focused verification; do not repeat checks without a remaining risk. Keep
replies concise and disclose material unverified work or limitations. These
guidelines supplement the model-confirmation and project-memory rules below.

Reference: https://github.com/DietrichGebert/ponytail, reviewed at revision
`09c434ab73ca43761c5d8b0c5d341926c2fba710`. The local Codex profile also has the
instruction-file adaptation at `/Users/lawie/.codex/AGENTS.md`; read local rules
instead of fetching upstream every chat. This setup does not install plugin
commands or lifecycle hooks.

### Model selection

For every user-requested action, including follow-ups within the same feature,
recommend the lowest-cost model and reasoning level that should be sufficient
before inspecting files, calling tools, or starting implementation. Use this
exact compact format:

`Recommended: <model> · <reasoning> — <one-sentence reason>`

Wait for the user to switch models or confirm before beginning that action. Do
not claim that the model was changed automatically; the user controls the
active chat model. Repeat the recommendation for every separate action request,
even when it is a follow-up within the same scoped task.

Use these defaults:

- Luna Low for small UI/text edits, simple questions, status checks, and
  tightly scoped single-file work.
- Luna Medium for clear screen builds, documentation, tests, and coordinated
  but straightforward edits.
- GPT-6.1 Sol Medium for normal feature implementation, multi-file integration,
  backend work, GPS/offline behavior, and debugging.
- GPT-6.1 Sol High for difficult bugs, migrations, architecture, or risky
  cross-component changes.
- Astra Medium or High only for unusually ambiguous, security/privacy-critical,
  or release-critical work that needs the strongest review.

Prefer the lowest sufficient reasoning level. Avoid Extra High, Max, and Ultra
unless the user explicitly requests them or the task demonstrably requires
them.

Keep one chat focused on one feature or closely related goal. Continue that
chat through implementation and verification. After a meaningful milestone or
when switching components or unrelated goals, ask the user to run `save`, then
start a fresh chat. The fresh chat should say:

`Read AGENTS.md and project memory. Continue <component/feature>. Recommend the model and reasoning level first, then wait for me to switch or confirm.`

Do not ask the user to retell the complete prior conversation. Recover durable
context from project memory and inspect current source as the authority. Long
chats may use context compaction, so do not restart solely because of message
count; restart at a clean milestone when stale history would add noise.

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
