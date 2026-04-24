#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'USAGE'
Usage: search_context7_libraries.sh <query> [limit] [format]

Examples:
  search_context7_libraries.sh webflux 5 summary
  search_context7_libraries.sh "spring security" 10 json
  CONTEXT7_COOKIE='name=value; other=value' search_context7_libraries.sh ratatui

Arguments:
  query   Keyword or library name to search on Context7
  limit   Optional result count for summary output. Default: 10
  format  Optional output format: summary or json. Default: summary
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

query="${1:-}"
limit="${2:-10}"
format="${3:-summary}"

if [[ -z "$query" ]]; then
  usage
  exit 2
fi

if ! [[ "$limit" =~ ^[0-9]+$ ]]; then
  echo "error: limit must be a positive integer" >&2
  exit 2
fi

case "$format" in
  summary | json) ;;
  *)
    echo "error: format must be summary or json" >&2
    exit 2
    ;;
esac

urlencode() {
  local input="$1"
  local output=""
  local char
  local encoded
  local i

  for ((i = 0; i < ${#input}; i++)); do
    char="${input:i:1}"
    case "$char" in
      [a-zA-Z0-9.~_-]) output+="$char" ;;
      *) printf -v encoded '%%%02X' "'$char"; output+="$encoded" ;;
    esac
  done

  printf '%s' "$output"
}

url="https://context7.com/api/search?query=$(urlencode "$query")"

headers=(
  -H 'accept: */*'
  -H 'referer: https://context7.com/'
  -H 'user-agent: Codex context7-web skill'
)

cookie_args=()
if [[ -n "${CONTEXT7_COOKIE:-}" ]]; then
  cookie_args=(-b "$CONTEXT7_COOKIE")
fi

response="$(curl -sS --fail-with-body "${headers[@]}" "${cookie_args[@]}" "$url")"

if [[ "$format" == "json" ]]; then
  printf '%s\n' "$response"
  exit 0
fi

CONTEXT7_SEARCH_RESPONSE="$response" python3 - "$limit" <<'PY'
import json
import os
import sys

limit = int(sys.argv[1])
data = json.loads(os.environ["CONTEXT7_SEARCH_RESPONSE"])
results = data.get("results", [])[:limit]

for index, item in enumerate(results, 1):
    settings = item.get("settings") or {}
    version = item.get("version") or {}
    title = settings.get("title") or "(untitled)"
    project = settings.get("project") or ""
    description = settings.get("description") or ""
    trust = settings.get("trustScore")
    benchmark = version.get("benchmarkScore") or settings.get("queryBenchmarkScore")
    snippets = version.get("totalSnippets")
    verified = settings.get("verified")
    docs = settings.get("docsSiteUrl") or settings.get("docsRepoUrl") or ""

    print(f"{index}. {title}")
    print(f"   Project: {project}")
    print(f"   Trust: {trust if trust is not None else 'n/a'} | Benchmark: {benchmark if benchmark is not None else 'n/a'} | Snippets: {snippets if snippets is not None else 'n/a'} | Verified: {bool(verified)}")
    if docs:
        print(f"   Source: {docs}")
    if description:
        print(f"   Description: {description}")
PY
