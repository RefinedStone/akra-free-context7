#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'USAGE'
Usage: fetch_context7_docs.sh <library> [topic] [tokens] [type]

Examples:
  fetch_context7_docs.sh ratatui/ratatui design 10000 json
  fetch_context7_docs.sh /vercel/next.js routing 5000 json
  CONTEXT7_COOKIE='name=value; other=value' fetch_context7_docs.sh ratatui/ratatui - 2000 json

Arguments:
  library  Context7 path like ratatui/ratatui, /ratatui/ratatui, or https://context7.com/ratatui/ratatui
  topic    Optional topic. Use '-' to omit. Default: omitted
  tokens   Optional token budget. Default: 10000
  type     Optional response type. Default: json
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

library="${1:-}"
topic="${2:-}"
tokens="${3:-10000}"
response_type="${4:-json}"

if [[ -z "$library" ]]; then
  usage
  exit 2
fi

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

encode_path_preserving_slashes() {
  local path="$1"
  local encoded_path=""
  local segment
  local segments

  IFS='/' read -r -a segments <<< "$path"
  for segment in "${segments[@]}"; do
    if [[ -n "$encoded_path" ]]; then
      encoded_path+="/"
    fi
    encoded_path+="$(urlencode "$segment")"
  done

  printf '%s' "$encoded_path"
}

library="${library#https://context7.com/}"
library="${library#http://context7.com/}"
library="${library%%\?*}"
library="${library#/}"
library="${library%/}"

if [[ -z "$library" ]]; then
  echo "error: library path is empty after normalization" >&2
  exit 2
fi

if ! [[ "$tokens" =~ ^[0-9]+$ ]]; then
  echo "error: tokens must be a positive integer" >&2
  exit 2
fi

encoded_library="$(encode_path_preserving_slashes "$library")"
encoded_type="$(urlencode "$response_type")"
url="https://context7.com/api/web/docs/code/${encoded_library}?tokens=${tokens}&type=${encoded_type}"

if [[ -n "$topic" && "$topic" != "-" ]]; then
  url+="&topic=$(urlencode "$topic")"
fi

headers=(
  -H 'accept: */*'
  -H 'content-type: application/json'
  -H "referer: https://context7.com/${encoded_library}"
  -H 'user-agent: Codex context7-web skill'
)

cookie_args=()
if [[ -n "${CONTEXT7_COOKIE:-}" ]]; then
  cookie_args=(-b "$CONTEXT7_COOKIE")
fi

curl -sS --fail-with-body "${headers[@]}" "${cookie_args[@]}" "$url"
