# Responda web-dashboard instructions

Before web-dashboard work, read the monorepo instructions and current project
state:

- `../AGENTS.md`
- `../memory/INDEX.md`
- `../memory/CURRENT_STATE.md`
- `../memory/DECISIONS.md`

Use the combined code graph before broad codebase searches:

```bash
cd ..
graphify query "<question>" --graph graphify-out/graph.json
```

After material web work, update the concise shared memory and run:

```bash
npm run lint && npm run build
cd ..
./scripts/update-project-graph.sh web
```

Never copy `.env` values, passwords, signing keys, tokens, personal IDs, phone
numbers, or raw emergency-report content into memory or Graphify output.
