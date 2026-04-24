#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'USAGE'
Usage: resolve_context7_libraries.sh <query> [limit] [format]

Examples:
  resolve_context7_libraries.sh "rust hexagonal architecture" 8 summary
  resolve_context7_libraries.sh webflux 5 json
  CONTEXT7_COOKIE='name=value; other=value' resolve_context7_libraries.sh ratatui

Arguments:
  query   User-level technology need to resolve to Context7 projects
  limit   Optional result count. Default: 10
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

CONTEXT7_RESOLVE_QUERY="$query" CONTEXT7_RESOLVE_LIMIT="$limit" CONTEXT7_RESOLVE_FORMAT="$format" python3 <<'PY'
import json
import math
import os
import re
import sys
from urllib.error import HTTPError, URLError
from urllib.parse import quote
from urllib.request import Request, urlopen


QUERY = os.environ["CONTEXT7_RESOLVE_QUERY"].strip()
LIMIT = int(os.environ["CONTEXT7_RESOLVE_LIMIT"])
FORMAT = os.environ["CONTEXT7_RESOLVE_FORMAT"]
COOKIE = os.environ.get("CONTEXT7_COOKIE", "")

LANGUAGES = {
    "rust", "java", "kotlin", "go", "golang", "python", "typescript",
    "javascript", "spring", "react", "nextjs", "next.js", "node", "nodejs",
}

ALIASES = {
    "hexagonal architecture": [
        "ports and adapters",
        "ports adapters",
        "clean architecture",
    ],
    "ports and adapters": [
        "hexagonal architecture",
        "ports adapters",
        "clean architecture",
    ],
    "ports adapters": [
        "ports and adapters",
        "hexagonal architecture",
        "clean architecture",
    ],
    "clean architecture": [
        "hexagonal architecture",
        "ports and adapters",
        "ports adapters",
    ],
    "webflux": [
        "spring webflux",
        "spring framework webflux",
    ],
    "springboot": [
        "spring boot",
    ],
    "spring boot": [
        "springboot",
    ],
    "ratatui": [
        "ratatui rust",
        "rust terminal ui",
    ],
    "rattauui": [
        "ratatui",
    ],
}


def words(text):
    return re.findall(r"[a-z0-9.+#-]+", text.lower())


def dedupe(items):
    seen = set()
    result = []
    for item in items:
        normalized = " ".join(item.lower().split())
        if normalized and normalized not in seen:
            seen.add(normalized)
            result.append(item)
    return result


def contains_language(text, language_terms):
    text_terms = set(words(text))
    return any(language in text_terms for language in language_terms)


def expand_queries(query):
    lowered = query.lower()
    tokens = words(query)
    language_terms = [token for token in tokens if token in LANGUAGES]
    variants = [query]

    for key, aliases in ALIASES.items():
        if key in lowered:
            variants.extend(aliases)
            for language in language_terms:
                for alias in aliases:
                    if not contains_language(alias, language_terms):
                        variants.extend([f"{language} {alias}", f"{alias} {language}"])

    if language_terms:
        concept_tokens = [token for token in tokens if token not in LANGUAGES]
        if concept_tokens:
            concept = " ".join(concept_tokens)
            variants.append(concept)
            for language in language_terms:
                variants.append(f"{concept} {language}")

    return dedupe(variants)[:12]


def fetch_search(query):
    url = f"https://context7.com/api/search?query={quote(query)}"
    headers = {
        "accept": "*/*",
        "referer": "https://context7.com/",
        "user-agent": "Codex context7-web skill",
    }
    if COOKIE:
        headers["cookie"] = COOKIE

    request = Request(url, headers=headers)
    try:
        with urlopen(request, timeout=20) as response:
            return json.loads(response.read().decode("utf-8"))
    except HTTPError as error:
        body = error.read().decode("utf-8", errors="replace")
        raise SystemExit(f"Context7 search failed for {query!r}: HTTP {error.code}\n{body}")
    except URLError as error:
        raise SystemExit(f"Context7 search failed for {query!r}: {error}")


def number(value, default=0.0):
    if isinstance(value, (int, float)) and not isinstance(value, bool):
        return float(value)
    return default


def snippet_score(value):
    snippets = max(number(value), 0.0)
    return min(math.log10(snippets + 1.0) * 8.0, 32.0)


def text_match_score(text, terms):
    lowered = text.lower()
    score = 0.0
    for term in terms:
        if len(term) < 3:
            continue
        if term in lowered:
            score += 3.0
    return min(score, 30.0)


query_terms = set(words(QUERY))
lower_query = QUERY.lower()
architecture_query = any(
    term in lower_query
    for term in [
        "hexagonal architecture",
        "ports and adapters",
        "ports adapters",
        "clean architecture",
    ]
)


def domain_adjustment(text):
    lowered = text.lower()
    score = 0.0

    if architecture_query:
        architecture_terms = [
            "hexagonal architecture",
            "ports and adapters",
            "ports adapters",
            "clean architecture",
            "architecture pattern",
            "adapters pattern",
        ]
        if any(term in lowered for term in architecture_terms):
            score += 24.0
        if "architecture" in lowered and "pattern" in lowered:
            score += 10.0

        geometry_terms = [
            "hexagonal grid",
            "hexagonal grids",
            "geometry",
            "coordinate systems",
            "spatial computing",
        ]
        if any(term in lowered for term in geometry_terms):
            score -= 55.0

        adapter_false_friends = [
            "dbt adapters",
            "transformer",
            "freebsd ports",
            "defillama",
            "data warehouse",
            "application adapters",
            "adapter methods",
        ]
        if any(term in lowered for term in adapter_false_friends):
            score -= 40.0

    return score


queries = expand_queries(QUERY)
projects = {}

for query_index, expanded_query in enumerate(queries):
    data = fetch_search(expanded_query)
    for rank, item in enumerate(data.get("results", []), 1):
        settings = item.get("settings") or {}
        version = item.get("version") or {}
        project = settings.get("project")
        if not project:
            continue

        existing = projects.setdefault(project, {
            "settings": settings,
            "version": version,
            "matchedQueries": [],
            "bestRank": rank,
            "score": 0.0,
        })
        existing["matchedQueries"].append(expanded_query)
        existing["bestRank"] = min(existing["bestRank"], rank)

        searchable = " ".join(str(value or "") for value in [
            settings.get("title"),
            settings.get("project"),
            settings.get("description"),
            settings.get("docsSiteUrl"),
            settings.get("docsRepoUrl"),
        ])
        trust = number(settings.get("trustScore"))
        benchmark = number(version.get("benchmarkScore") or settings.get("queryBenchmarkScore"))
        snippets = version.get("totalSnippets")
        verified = 1.0 if settings.get("verified") else 0.0

        score = 0.0
        score += max(0.0, 35.0 - ((rank - 1) * 3.0))
        score += max(0.0, 8.0 - (query_index * 0.8))
        score += trust * 4.0
        score += benchmark * 0.35
        score += snippet_score(snippets)
        score += verified * 12.0
        score += text_match_score(searchable, query_terms)
        score += domain_adjustment(searchable)

        existing["score"] = max(existing["score"], score)

ranked = sorted(
    projects.values(),
    key=lambda item: (item["score"], -item["bestRank"]),
    reverse=True,
)[:LIMIT]

if FORMAT == "json":
    print(json.dumps({
        "query": QUERY,
        "expandedQueries": queries,
        "results": ranked,
    }, ensure_ascii=False, indent=2))
    sys.exit(0)

print(f"Query: {QUERY}")
print("Expanded queries: " + ", ".join(queries))
print()

for index, item in enumerate(ranked, 1):
    settings = item["settings"]
    version = item["version"]
    title = settings.get("title") or "(untitled)"
    project = settings.get("project") or ""
    description = settings.get("description") or ""
    trust = settings.get("trustScore")
    benchmark = version.get("benchmarkScore") or settings.get("queryBenchmarkScore")
    snippets = version.get("totalSnippets")
    verified = settings.get("verified")
    docs = settings.get("docsSiteUrl") or settings.get("docsRepoUrl") or ""
    matched = ", ".join(dedupe(item["matchedQueries"]))

    print(f"{index}. {title}")
    print(f"   Project: {project}")
    print(f"   Score: {item['score']:.1f} | Best rank: {item['bestRank']} | Trust: {trust if trust is not None else 'n/a'} | Benchmark: {benchmark if benchmark is not None else 'n/a'} | Snippets: {snippets if snippets is not None else 'n/a'} | Verified: {bool(verified)}")
    print(f"   Matched queries: {matched}")
    if docs:
        print(f"   Source: {docs}")
    if description:
        print(f"   Description: {description}")
PY
