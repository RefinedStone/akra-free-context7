---
name: context7-web
description: Use when the user asks to search or query Context7 documentation through the direct context7.com web API, especially when the Context7 MCP tool is unavailable or failing due to API key configuration. Supports keyword-based library resolution and snippet retrieval with cross-platform Python, Bash, and PowerShell entrypoints.
metadata:
  short-description: Fetch Context7 docs through web API
---

# Context7 Web

Use this skill when Context7 MCP is unavailable, misconfigured, or the user explicitly asks to search or fetch Context7 docs through the web/API endpoint.

## Entrypoints

The portable core is `scripts/context7_web.py`. Run it from this skill directory:

```bash
python scripts/context7_web.py resolve "rust hexagonal architecture" --limit 8
python scripts/context7_web.py search "ports adapters rust" --limit 5
python scripts/context7_web.py fetch /websites/spring_io_spring-framework_reference_6_2 --topic webflux --tokens 10000
```

On Unix-like shells, the `.sh` files are thin wrappers around the Python core. On Windows PowerShell, use the `.ps1` wrappers.

## Workflow

1. Prefer official Context7 MCP if it is working and the user did not ask for the web API path.
2. Resolve a technology keyword to candidate Context7 projects unless the user already supplied an exact Context7 path.
3. If the resolver output is weak or ambiguous, run direct searches for specific alternatives.
4. Pick the best `Project` using title, description, trust score, benchmark score, snippet count, verification, and relevance to the user's task.
5. Fetch docs for the chosen `Project`.
6. Read the JSON response and answer from the returned snippets. Keep source identifiers such as `codeId` when citing a snippet.
7. If an endpoint requires browser session state, set `CONTEXT7_COOKIE` in the environment and rerun. Do not store cookies in this skill.

## Resolve Strategy

Treat this as a local replacement for Context7 MCP `resolve-library-id`.

- Search the exact user phrase first.
- Expand known aliases for architectural terms: `hexagonal architecture`, `ports and adapters`, `ports adapters`, and `clean architecture`.
- Expand known technology aliases and selected typo aliases, such as `springboot -> spring boot` and `rattauui -> ratatui`.
- When a query combines language and concept, search both together and separately. Example: `rust hexagonal architecture`, `hexagonal architecture`, `ports adapters rust`.
- Prefer official or verified sources with high trust, meaningful snippet counts, and descriptions that match the user's task.
- If no language-specific architecture source exists, combine two sources: one for architecture principles and one official source for language mechanics.
- Be explicit when Context7 does not contain a strong source for the exact language/concept pair.

## Commands

Resolve user intent to Context7 projects:

```text
context7_web.py resolve <query> [--limit N] [--format summary|json]
```

Search Context7 directly:

```text
context7_web.py search <query> [--limit N] [--format summary|json]
```

Fetch snippets for a chosen project:

```text
context7_web.py fetch <library> [--topic topic] [--tokens N] [--type json]
```

Arguments:

- `query`: User-level need, such as `rust hexagonal architecture`, `springboot kotlin`, or `webflux`.
- `library`: Context7 project path from search results, such as `/websites/rs_ratatui`, `/websites/spring_io_spring-framework_reference_6_2`, or `https://context7.com/ratatui/ratatui`.
- `topic`: Optional topic query, such as `design`, `layout`, `testing`, or `auth`. Use `-` for no topic.
- `tokens`: Optional token budget. Defaults to `10000`.
- `format`: `summary` or `json`. Defaults to `summary`.

## Notes

- This uses undocumented Context7 web endpoints, so treat failures as endpoint drift unless the HTTP status clearly says otherwise.
- Keep requests simple. Do not copy browser-only headers unless a specific failure requires one.
- Never hard-code cookies or API keys in the skill. Use environment variables for temporary authenticated calls.
- The Python core is the source of truth; shell and PowerShell scripts are compatibility wrappers.
