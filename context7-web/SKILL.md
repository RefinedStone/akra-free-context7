---
name: context7-web
description: Use when the user asks to search or query Context7 documentation through the direct context7.com web API, especially when the Context7 MCP tool is unavailable or failing due to API key configuration. Supports keyword-based library search through /api/search and snippet retrieval through /api/web/docs/code/{project}.
metadata:
  short-description: Fetch Context7 docs through web API
---

# Context7 Web

Use this skill when Context7 MCP is unavailable, misconfigured, or the user explicitly asks to search or fetch Context7 docs through the web/API endpoint.

## Workflow

1. Prefer official MCP if it is working and the user did not ask for the web API path.
2. Resolve a technology keyword to candidate Context7 projects unless the user already supplied an exact Context7 path:

```bash
/home/akra/.codex/skills/context7-web/scripts/resolve_context7_libraries.sh "rust hexagonal architecture" 8 summary
```

3. If the resolver output is weak or ambiguous, run direct searches for specific alternatives:

```bash
/home/akra/.codex/skills/context7-web/scripts/search_context7_libraries.sh "ports adapters rust" 5 summary
```

4. Pick the best `Project` using title, description, trust score, benchmark score, snippet count, verification, and relevance to the user's task.
5. Fetch docs for the chosen `Project`:

```bash
/home/akra/.codex/skills/context7-web/scripts/fetch_context7_docs.sh /websites/spring_io_spring-framework_reference_6_2 webflux 10000 json
```

6. Read the JSON response and answer from the returned snippets. Keep source identifiers such as `codeId` when citing a snippet.
7. If an endpoint requires browser session state, set `CONTEXT7_COOKIE` in the environment and rerun. Do not store cookies in this skill.

## Resolve Strategy

Treat this as a local replacement for Context7 MCP `resolve-library-id`.

- Search the exact user phrase first.
- Expand known aliases for architectural terms: `hexagonal architecture`, `ports and adapters`, `ports adapters`, and `clean architecture`.
- When a query combines language and concept, search both together and separately. Example: `rust hexagonal architecture`, `hexagonal architecture`, `ports adapters rust`.
- Prefer official or verified sources with high trust, meaningful snippet counts, and descriptions that match the user's task.
- If no language-specific architecture source exists, combine two sources: one for architecture principles and one official source for language mechanics.
- Be explicit when Context7 does not contain a strong source for the exact language/concept pair.

## Resolve Script

```text
resolve_context7_libraries.sh <query> [limit] [format]
```

- `query`: User-level need, such as `rust hexagonal architecture` or `webflux`.
- `limit`: Optional result count. Defaults to `10`.
- `format`: `summary` or `json`. Defaults to `summary`.

This script runs multiple Context7 searches, deduplicates by `Project`, scores candidates, and shows which expanded queries matched each project.

## Search Script

```text
search_context7_libraries.sh <query> [limit] [format]
```

- `query`: Keyword or library name, such as `webflux`, `ratatui`, or `spring security`.
- `limit`: Optional result count for summary output. Defaults to `10`.
- `format`: `summary` or `json`. Defaults to `summary`.

Use `summary` for selection and `json` when raw metadata is needed.

## Docs Script

```text
fetch_context7_docs.sh <library> [topic] [tokens] [type]
```

- `library`: Context7 project path from search results, such as `/ratatui/ratatui`, `/websites/spring_io_spring-framework_reference_6_2`, or `https://context7.com/ratatui/ratatui`.
- `topic`: Optional topic query, such as `design`, `layout`, `testing`, or `auth`. Use `-` for no topic.
- `tokens`: Optional token budget. Defaults to `10000`.
- `type`: Optional Context7 response type. Defaults to `json`.

## Notes

- This uses an undocumented web endpoint, so treat failures as endpoint drift unless the HTTP status clearly says otherwise.
- Keep requests simple. Do not copy browser-only headers unless a specific failure requires one.
- Never hard-code cookies or API keys in the skill. Use environment variables for temporary authenticated calls.
