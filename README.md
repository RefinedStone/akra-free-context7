# context7-web-skill

Codex skill for querying Context7 through the public web API when the Context7 MCP server is unavailable or misconfigured.

## Install

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/RefinedStone/context7-web-skill/main/install.sh)"
```

Restart Codex after installation so the skill list is reloaded.

## What It Does

- Resolves technology keywords to Context7 projects.
- Expands common aliases such as `springboot` to `spring boot`.
- Handles selected typo aliases such as `rattauui` to `ratatui`.
- Fetches docs snippets from the selected Context7 project.

## Direct Usage

```bash
~/.codex/skills/context7-web/scripts/resolve_context7_libraries.sh "springboot kotlin" 8 summary
~/.codex/skills/context7-web/scripts/fetch_context7_docs.sh /websites/spring_io_spring-boot_3_5 kotlin 5000 json
```

## Notes

This skill uses undocumented Context7 web endpoints. If Context7 changes those endpoints, the scripts may need updates.

Do not hard-code cookies or API keys. If a request requires browser session state, pass it temporarily:

```bash
CONTEXT7_COOKIE='name=value; other=value' ~/.codex/skills/context7-web/scripts/resolve_context7_libraries.sh ratatui
```
