#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
query="${1:-}"
limit="${2:-10}"
format="${3:-summary}"

if [[ -z "$query" || "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  echo "Usage: search_context7_libraries.sh <query> [limit] [summary|json]" >&2
  exit 2
fi

python3 "$script_dir/context7_web.py" search "$query" --limit "$limit" --format "$format"
