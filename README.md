# Akra Free Context7

[![CI](https://github.com/RefinedStone/akra-free-context7/actions/workflows/ci.yml/badge.svg)](https://github.com/RefinedStone/akra-free-context7/actions/workflows/ci.yml)

Codex에서 Context7 MCP가 API 키 문제로 막혀도 최신 기술 문서 검색을 계속 쓰기 위한 무료 대체 skill입니다. Context7의 공개 웹 API를 직접 호출해 기술 키워드를 Context7 project로 해석하고, 선택한 project에서 필요한 문서 snippet을 가져옵니다.

## Context7이란?

Context7은 AI 코딩 도구가 오래된 학습 지식 대신 현재 라이브러리 문서를 참고하도록 도와주는 문서 검색 레이어입니다. `ratatui`, `springboot kotlin`, `webflux` 같은 키워드를 실제 문서 project로 연결하고, 질문에 맞는 코드 예시와 API 설명을 짧게 가져옵니다.

이 repo는 공식 MCP 서버를 대체하려는 프로젝트가 아닙니다. MCP 설정이 깨졌거나 API 키 없이 빠르게 문서를 찾아야 할 때, Codex skill 형태로 Context7의 검색 흐름을 가볍게 재현합니다.

## 설치

macOS, Linux, WSL, Git Bash:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/RefinedStone/akra-free-context7/main/install.sh)"
```

Windows PowerShell:

```powershell
irm https://raw.githubusercontent.com/RefinedStone/akra-free-context7/main/install.ps1 | iex
```

설치 후 Codex를 재시작해야 skill 목록이 다시 로드됩니다.

## 수동 설치

자동 설치가 실패하면 `context7-web` 폴더를 직접 `skills` 디렉터리에 넣으면 됩니다. 기본 위치는 Codex 기준 `~/.codex/skills/context7-web`입니다. `CODEX_HOME`을 따로 쓰고 있다면 `$CODEX_HOME/skills/context7-web`에 넣으세요.

macOS, Linux, WSL:

```bash
tmp_dir="$(mktemp -d)"
curl -fsSL https://github.com/RefinedStone/akra-free-context7/archive/refs/heads/main.tar.gz | tar -xz -C "$tmp_dir"
mkdir -p "${CODEX_HOME:-$HOME/.codex}/skills"
rm -rf "${CODEX_HOME:-$HOME/.codex}/skills/context7-web"
cp -R "$tmp_dir"/akra-free-context7-main/context7-web "${CODEX_HOME:-$HOME/.codex}/skills/context7-web"
chmod +x "${CODEX_HOME:-$HOME/.codex}/skills/context7-web/scripts/"*.sh
rm -rf "$tmp_dir"
```

Windows PowerShell:

```powershell
$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("akra-free-context7-" + [System.Guid]::NewGuid().ToString("N"))
$zip = Join-Path $tmp "source.zip"
$codexHome = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $HOME ".codex" }
$skillsHome = Join-Path $codexHome "skills"
New-Item -ItemType Directory -Force -Path $tmp, $skillsHome | Out-Null
Invoke-WebRequest https://github.com/RefinedStone/akra-free-context7/archive/refs/heads/main.zip -OutFile $zip
Expand-Archive $zip -DestinationPath $tmp -Force
$dest = Join-Path $skillsHome "context7-web"
Remove-Item $dest -Recurse -Force -ErrorAction SilentlyContinue
Copy-Item (Join-Path $tmp "akra-free-context7-main/context7-web") $dest -Recurse
Remove-Item $tmp -Recurse -Force
```

Git이 이미 설치되어 있다면 clone으로도 설치할 수 있습니다.

```bash
git clone https://github.com/RefinedStone/akra-free-context7.git
mkdir -p "${CODEX_HOME:-$HOME/.codex}/skills"
cp -R akra-free-context7/context7-web "${CODEX_HOME:-$HOME/.codex}/skills/context7-web"
```

수동 설치 후에도 Codex를 재시작해야 skill 목록이 갱신됩니다.

## 요구 사항

- Python 3
- 인터넷 연결
- macOS/Linux 계열 설치: `bash`, `curl`, `tar`, `find`
- Windows 설치: PowerShell 5+ 또는 PowerShell 7+

## 무엇을 하나요

- `webflux`, `springboot kotlin`, `rust ratatui` 같은 키워드로 Context7 project 후보를 찾습니다.
- `springboot -> spring boot`, `rattauui -> ratatui`처럼 자주 나오는 alias와 일부 오타를 보정합니다.
- `hexagonal architecture`, `ports and adapters`, `clean architecture`처럼 같은 개념의 다른 표현을 함께 검색합니다.
- 선택된 Context7 project에서 topic 기반 문서 snippet을 가져옵니다.
- 한국어 query와 출력이 깨지지 않도록 JSON 출력에서 UTF-8을 유지합니다.

## 바로 사용하기

공통 Python CLI:

```bash
python ~/.codex/skills/context7-web/scripts/context7_web.py resolve "springboot kotlin" --limit 8
python ~/.codex/skills/context7-web/scripts/context7_web.py fetch /websites/spring_io_spring-boot_3_5 --topic kotlin --tokens 5000
```

macOS/Linux wrapper:

```bash
~/.codex/skills/context7-web/scripts/resolve_context7_libraries.sh "rust rattauui" 5 summary
~/.codex/skills/context7-web/scripts/fetch_context7_docs.sh /websites/rs_ratatui layout 5000 json
```

Windows PowerShell wrapper:

```powershell
~\.codex\skills\context7-web\scripts\resolve_context7_libraries.ps1 "rust rattauui" 5 summary
~\.codex\skills\context7-web\scripts\fetch_context7_docs.ps1 /websites/rs_ratatui layout 5000 json
```

## 사용 흐름

1. `resolve`로 기술 키워드를 Context7 project 후보로 바꿉니다.
2. `Project`, `Trust`, `Benchmark`, `Snippets`, `Verified`, 설명을 보고 가장 적합한 후보를 고릅니다.
3. `fetch`로 해당 project에서 topic 기반 문서를 가져옵니다.
4. Context7 결과가 약하면 정확히 말합니다. 예를 들어 Rust 전용 hexagonal architecture 자료가 약하면 architecture 자료와 Rust 공식 자료를 조합해서 판단합니다.

## 예시

오타가 있는 Ratatui 검색:

```bash
python ~/.codex/skills/context7-web/scripts/context7_web.py resolve "rust rattauui" --limit 3
```

예상 상위 결과:

```text
1. Ratatui
   Project: /websites/rs_ratatui
   Source: https://docs.rs/ratatui/latest
```

Spring Boot Kotlin 검색:

```bash
python ~/.codex/skills/context7-web/scripts/context7_web.py resolve "springboot kotlin" --limit 3
```

예상 상위 결과:

```text
1. Spring Boot
   Project: /websites/spring_io_spring-boot
   Source: https://docs.spring.io/spring-boot
```

## 쿠키가 필요한 경우

기본적으로 쿠키 없이 동작하도록 설계했습니다. 특정 요청에서 브라우저 세션이 필요하면 환경변수로만 넘깁니다. 쿠키나 API 키를 repo에 저장하지 마세요.

macOS/Linux:

```bash
CONTEXT7_COOKIE='name=value; other=value' python ~/.codex/skills/context7-web/scripts/context7_web.py resolve ratatui
```

Windows PowerShell:

```powershell
$env:CONTEXT7_COOKIE = 'name=value; other=value'
python ~\.codex\skills\context7-web\scripts\context7_web.py resolve ratatui
```

## 제한 사항

- Context7의 비공식 웹 endpoint를 사용합니다. Context7이 endpoint나 응답 구조를 바꾸면 수정이 필요할 수 있습니다.
- 검색 결과의 품질은 Context7 index에 의존합니다.
- 자동 선택보다 후보를 보여주고 사람이 판단할 수 있게 하는 쪽을 우선합니다.

## 개발/검증

```bash
python context7-web/scripts/context7_web.py doctor
python context7-web/scripts/context7_web.py resolve "rust rattauui" --limit 2
python context7-web/scripts/context7_web.py fetch /websites/rs_ratatui --topic layout --tokens 1000
```
