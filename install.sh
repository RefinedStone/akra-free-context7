#!/usr/bin/env bash
set -euo pipefail

repo="${CONTEXT7_WEB_SKILL_REPO:-RefinedStone/akra-free-context7}"
ref="${CONTEXT7_WEB_SKILL_REF:-main}"
skill_name="context7-web"
codex_home="${CODEX_HOME:-$HOME/.codex}"
skills_home="$codex_home/skills"

need_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "error: required command not found: $1" >&2
    exit 1
  fi
}

need_command curl
need_command tar
need_command find

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

archive_url="${CONTEXT7_WEB_SKILL_ARCHIVE_URL:-https://codeload.github.com/${repo}/tar.gz/${ref}}"

mkdir -p "$skills_home"
curl -fsSL "$archive_url" | tar -xz -C "$tmp_dir"

skill_src="$(find "$tmp_dir" -mindepth 2 -maxdepth 2 -type d -name "$skill_name" | head -n 1)"
if [[ -z "$skill_src" ]]; then
  echo "error: skill directory not found in archive: $skill_name" >&2
  exit 1
fi

rm -rf "$skills_home/$skill_name"
cp -R "$skill_src" "$skills_home/$skill_name"

if compgen -G "$skills_home/$skill_name/scripts/*.sh" >/dev/null; then
  chmod +x "$skills_home/$skill_name/scripts/"*.sh
fi

echo "Installed $skill_name to $skills_home/$skill_name"
echo "Restart Codex to reload available skills."
