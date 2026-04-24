#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
library="${1:-}"
topic="${2:-}"
tokens="${3:-10000}"
response_type="${4:-json}"

if [[ -z "$library" || "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  echo "Usage: fetch_context7_docs.sh <library> [topic] [tokens] [type]" >&2
  exit 2
fi

python3 "$script_dir/context7_web.py" fetch "$library" --topic "$topic" --tokens "$tokens" --type "$response_type"
