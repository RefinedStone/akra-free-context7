#!/usr/bin/env python3
import argparse
import json
import math
import os
import re
import shutil
import sys
from urllib.error import HTTPError, URLError
from urllib.parse import quote
from urllib.request import Request, urlopen

LANGUAGES = {
    "rust", "java", "kotlin", "go", "golang", "python", "typescript",
    "javascript", "spring", "react", "nextjs", "next.js", "node", "nodejs",
}

ALIASES = {
    "hexagonal architecture": ["ports and adapters", "ports adapters", "clean architecture"],
    "ports and adapters": ["hexagonal architecture", "ports adapters", "clean architecture"],
    "ports adapters": ["ports and adapters", "hexagonal architecture", "clean architecture"],
    "clean architecture": ["hexagonal architecture", "ports and adapters", "ports adapters"],
    "webflux": ["spring webflux", "spring framework webflux"],
    "springboot": ["spring boot"],
    "spring boot": ["springboot"],
    "ratatui": ["ratatui rust", "rust terminal ui"],
    "rattauui": ["ratatui"],
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


def context7_headers(referer):
    headers = {
        "accept": "*/*",
        "referer": referer,
        "user-agent": "Codex context7-web skill",
    }
    cookie = os.environ.get("CONTEXT7_COOKIE", "")
    if cookie:
        headers["cookie"] = cookie
    return headers


def request_json(url, headers):
    request = Request(url, headers=headers)
    try:
        with urlopen(request, timeout=30) as response:
            return json.loads(response.read().decode("utf-8"))
    except HTTPError as error:
        body = error.read().decode("utf-8", errors="replace")
        raise SystemExit(f"Context7 request failed: HTTP {error.code}\n{body}")
    except URLError as error:
        raise SystemExit(f"Context7 request failed: {error}")


def search_context7(query):
    url = f"https://context7.com/api/search?query={quote(query)}"
    return request_json(url, context7_headers("https://context7.com/"))


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
        if len(term) >= 3 and term in lowered:
            score += 3.0
    return min(score, 30.0)


def domain_adjustment(text, architecture_query):
    lowered = text.lower()
    score = 0.0
    if architecture_query:
        if any(term in lowered for term in [
            "hexagonal architecture", "ports and adapters", "ports adapters",
            "clean architecture", "architecture pattern", "adapters pattern",
        ]):
            score += 24.0
        if "architecture" in lowered and "pattern" in lowered:
            score += 10.0
        if any(term in lowered for term in [
            "hexagonal grid", "hexagonal grids", "geometry", "coordinate systems", "spatial computing",
        ]):
            score -= 55.0
        if any(term in lowered for term in [
            "dbt adapters", "transformer", "freebsd ports", "defillama",
            "data warehouse", "application adapters", "adapter methods",
        ]):
            score -= 40.0
    return score


def print_candidate(index, settings, version, score=None, best_rank=None, matched_queries=None):
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
    if score is None:
        print(f"   Trust: {trust if trust is not None else 'n/a'} | Benchmark: {benchmark if benchmark is not None else 'n/a'} | Snippets: {snippets if snippets is not None else 'n/a'} | Verified: {bool(verified)}")
    else:
        print(f"   Score: {score:.1f} | Best rank: {best_rank} | Trust: {trust if trust is not None else 'n/a'} | Benchmark: {benchmark if benchmark is not None else 'n/a'} | Snippets: {snippets if snippets is not None else 'n/a'} | Verified: {bool(verified)}")
        print(f"   Matched queries: {', '.join(dedupe(matched_queries or []))}")
    if docs:
        print(f"   Source: {docs}")
    if description:
        print(f"   Description: {description}")


def resolve_context7(query, limit):
    query_terms = set(words(query))
    lowered_query = query.lower()
    architecture_query = any(term in lowered_query for term in [
        "hexagonal architecture", "ports and adapters", "ports adapters", "clean architecture",
    ])
    queries = expand_queries(query)
    projects = {}

    for query_index, expanded_query in enumerate(queries):
        data = search_context7(expanded_query)
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
                settings.get("title"), settings.get("project"), settings.get("description"),
                settings.get("docsSiteUrl"), settings.get("docsRepoUrl"),
            ])
            score = 0.0
            score += max(0.0, 35.0 - ((rank - 1) * 3.0))
            score += max(0.0, 8.0 - (query_index * 0.8))
            score += number(settings.get("trustScore")) * 4.0
            score += number(version.get("benchmarkScore") or settings.get("queryBenchmarkScore")) * 0.35
            score += snippet_score(version.get("totalSnippets"))
            score += (12.0 if settings.get("verified") else 0.0)
            score += text_match_score(searchable, query_terms)
            score += domain_adjustment(searchable, architecture_query)
            existing["score"] = max(existing["score"], score)

    ranked = sorted(projects.values(), key=lambda item: (item["score"], -item["bestRank"]), reverse=True)
    return {"query": query, "expandedQueries": queries, "results": ranked[:limit]}


def normalize_library(library):
    library = re.sub(r"^https?://context7\.com/", "", library)
    library = library.split("?", 1)[0].strip("/")
    if not library:
        raise SystemExit("error: library path is empty after normalization")
    return library


def fetch_docs(library, topic, tokens, response_type):
    if not str(tokens).isdigit():
        raise SystemExit("error: tokens must be a positive integer")
    normalized = normalize_library(library)
    url = (
        f"https://context7.com/api/web/docs/code/{quote(normalized, safe='/')}"
        f"?tokens={tokens}&type={quote(response_type)}"
    )
    if topic and topic != "-":
        url += f"&topic={quote(topic)}"
    headers = context7_headers(f"https://context7.com/{quote(normalized, safe='/')}")
    headers["content-type"] = "application/json"
    return request_json(url, headers)


def command_search(args):
    data = search_context7(args.query)
    if args.format == "json":
        print(json.dumps(data, ensure_ascii=False, indent=2))
        return
    for index, item in enumerate(data.get("results", [])[:args.limit], 1):
        print_candidate(index, item.get("settings") or {}, item.get("version") or {})


def command_resolve(args):
    data = resolve_context7(args.query, args.limit)
    if args.format == "json":
        print(json.dumps(data, ensure_ascii=False, indent=2))
        return
    print(f"Query: {data['query']}")
    print("Expanded queries: " + ", ".join(data["expandedQueries"]))
    print()
    for index, item in enumerate(data["results"], 1):
        print_candidate(index, item["settings"], item["version"], item["score"], item["bestRank"], item["matchedQueries"])


def command_fetch(args):
    print(json.dumps(fetch_docs(args.library, args.topic, args.tokens, args.type), ensure_ascii=False, indent=2))


def command_doctor(_args):
    print(f"python: {shutil.which('python3') or shutil.which('python') or sys.executable}")
    print(f"version: {sys.version.split()[0]}")
    print("status: ok")


def build_parser():
    parser = argparse.ArgumentParser(description="Context7 web API helper for Codex skills")
    subparsers = parser.add_subparsers(dest="command", required=True)
    search = subparsers.add_parser("search", help="Search Context7 libraries by keyword")
    search.add_argument("query")
    search.add_argument("--limit", type=int, default=10)
    search.add_argument("--format", choices=["summary", "json"], default="summary")
    search.set_defaults(func=command_search)
    resolve = subparsers.add_parser("resolve", help="Resolve user intent to Context7 projects")
    resolve.add_argument("query")
    resolve.add_argument("--limit", type=int, default=10)
    resolve.add_argument("--format", choices=["summary", "json"], default="summary")
    resolve.set_defaults(func=command_resolve)
    fetch = subparsers.add_parser("fetch", help="Fetch snippets for a Context7 project")
    fetch.add_argument("library")
    fetch.add_argument("--topic", default="")
    fetch.add_argument("--tokens", default="10000")
    fetch.add_argument("--type", default="json")
    fetch.set_defaults(func=command_fetch)
    doctor = subparsers.add_parser("doctor", help="Check local runtime")
    doctor.set_defaults(func=command_doctor)
    return parser


def main(argv=None):
    parser = build_parser()
    args = parser.parse_args(argv)
    args.func(args)


if __name__ == "__main__":
    main()
