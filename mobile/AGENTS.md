# Responda mobile instructions

Before Flutter work, read the monorepo instructions and current project state:

- `../AGENTS.md`
- `../memory/INDEX.md`
- `../memory/CURRENT_STATE.md`
- `../memory/DECISIONS.md`

Use the combined code graph before broad codebase searches:

```bash
cd ..
graphify query "<question>" --graph graphify-out/graph.json
```

After material Flutter work, update the concise shared memory and run:

```bash
flutter analyze && flutter test
cd ..
./scripts/update-project-graph.sh mobile
```

Never copy `.env` values, passwords, signing keys, tokens, personal IDs, phone
numbers, or raw emergency-report content into memory or Graphify output.
