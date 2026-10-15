#!/usr/bin/env bash

set -euo pipefail

workspace_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
component_root="$workspace_root/.graphify-components"
combined_root="$workspace_root/graphify-out"
obsidian_export="$workspace_root/graphify-notes"
target="${1:-all}"

backend_root="$workspace_root/backend"
web_root="$workspace_root/web"
mobile_root="$workspace_root/mobile"

if ! command -v graphify >/dev/null 2>&1; then
  echo "graphify is not installed or is not on PATH." >&2
  exit 1
fi

extract_component() {
  local name="$1"
  local source_root="$2"
  local output_root="$component_root/$name"

  if [[ ! -d "$source_root" ]]; then
    echo "Missing source directory: $source_root" >&2
    exit 1
  fi

  echo "Updating Graphify component: $name"
  graphify extract "$source_root" --code-only --out "$output_root"
}

case "$target" in
  all)
    extract_component backend "$backend_root"
    extract_component web "$web_root"
    extract_component mobile "$mobile_root"
    extract_component workspace "$workspace_root"
    ;;
  backend)
    extract_component backend "$backend_root"
    ;;
  web)
    extract_component web "$web_root"
    ;;
  mobile)
    extract_component mobile "$mobile_root"
    ;;
  workspace)
    extract_component workspace "$workspace_root"
    ;;
  *)
    echo "Usage: $0 [all|backend|web|mobile|workspace]" >&2
    exit 2
    ;;
esac

graphs=()
for name in backend web mobile workspace; do
  graph_path="$component_root/$name/graphify-out/graph.json"
  if [[ -f "$graph_path" ]]; then
    graphs+=("$graph_path")
  fi
done

if [[ "${#graphs[@]}" -eq 0 ]]; then
  echo "No component graphs exist to merge." >&2
  exit 1
fi

mkdir -p "$combined_root"
graphify merge-graphs "${graphs[@]}" --out "$combined_root/graph.json"

# Recluster the merged graph locally. Placeholder names avoid external model use.
graphify cluster-only "$workspace_root" \
  --graph "$combined_root/graph.json" \
  --no-label

graphify export html --graph "$combined_root/graph.json"
graphify export obsidian \
  --graph "$combined_root/graph.json" \
  --dir "$obsidian_export"
graphify tree \
  --graph "$combined_root/graph.json" \
  --output "$combined_root/GRAPH_TREE.html" \
  --label "Responda"

echo "Combined graph: $combined_root/graph.html"
echo "Obsidian canvas: $obsidian_export/graph.canvas"
