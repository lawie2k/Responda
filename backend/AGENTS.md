# Responda backend instructions

Before backend work, read the monorepo instructions and current project state:

- `../AGENTS.md`
- `../memory/INDEX.md`
- `../memory/CURRENT_STATE.md`
- `../memory/DECISIONS.md`

Use the combined code graph before broad codebase searches:

```bash
cd ..
graphify query "<question>" --graph graphify-out/graph.json
```

After material backend work, update the concise shared memory and run:

```bash
make check
cd ..
./scripts/update-project-graph.sh backend
```

Never copy `.env` values, passwords, signing keys, tokens, personal IDs, phone
numbers, or raw emergency-report content into memory or Graphify output.
