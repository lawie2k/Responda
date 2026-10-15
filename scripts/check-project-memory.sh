#!/usr/bin/env bash

set -euo pipefail

workspace_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

required_files=(
  "AGENTS.md"
  "memory/INDEX.md"
  "memory/PROJECT_OVERVIEW.md"
  "memory/PROJECT_MAP.md"
  "memory/ARCHITECTURE.md"
  "memory/CURRENT_STATE.md"
  "memory/DECISIONS.md"
  "memory/NEXT_STEPS.md"
  "memory/WORK_LOG.md"
  ".obsidian/app.json"
  ".obsidian/core-plugins.json"
  ".obsidian/graph.json"
)

for relative_path in "${required_files[@]}"; do
  if [[ ! -s "$workspace_root/$relative_path" ]]; then
    echo "Missing or empty required file: $relative_path" >&2
    exit 1
  fi
done

python3 - "$workspace_root" <<'PY'
import json
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
for path in (root / ".obsidian").glob("*.json"):
    json.loads(path.read_text(encoding="utf-8"))

missing = []
for path in (root / "memory").glob("*.md"):
    text = path.read_text(encoding="utf-8")
    for target in re.findall(r"\[\[([^\]|#]+)", text):
        if not (root / "memory" / f"{target}.md").exists():
            missing.append(f"{path.name}: [[{target}]]")

if missing:
    raise SystemExit("Broken memory links:\n" + "\n".join(missing))
PY

echo "Project memory is valid."
