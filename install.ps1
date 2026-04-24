$ErrorActionPreference = "Stop"

$Repo = if ($env:CONTEXT7_WEB_SKILL_REPO) { $env:CONTEXT7_WEB_SKILL_REPO } else { "RefinedStone/akra-free-context7" }
$Ref = if ($env:CONTEXT7_WEB_SKILL_REF) { $env:CONTEXT7_WEB_SKILL_REF } else { "main" }
$SkillName = "context7-web"
$CodexHome = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $HOME ".codex" }
$SkillsHome = Join-Path $CodexHome "skills"
$ArchiveSource = if ($env:CONTEXT7_WEB_SKILL_ARCHIVE_URL) {
    $env:CONTEXT7_WEB_SKILL_ARCHIVE_URL
} else {
    "https://github.com/$Repo/archive/$Ref.zip"
}

$TempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("akra-free-context7-" + [System.Guid]::NewGuid().ToString("N"))
$ArchivePath = Join-Path $TempDir "source.zip"

New-Item -ItemType Directory -Force -Path $TempDir | Out-Null
New-Item -ItemType Directory -Force -Path $SkillsHome | Out-Null

try {
    if (Test-Path -LiteralPath $ArchiveSource) {
        Copy-Item -LiteralPath $ArchiveSource -Destination $ArchivePath
    } else {
        Invoke-WebRequest -Uri $ArchiveSource -OutFile $ArchivePath
    }

    Expand-Archive -LiteralPath $ArchivePath -DestinationPath $TempDir -Force
    $SkillSource = Get-ChildItem -Path $TempDir -Directory -Recurse -Filter $SkillName | Select-Object -First 1
    if (-not $SkillSource) {
        throw "Skill directory not found in archive: $SkillName"
    }

    $Destination = Join-Path $SkillsHome $SkillName
    if (Test-Path -LiteralPath $Destination) {
        Remove-Item -LiteralPath $Destination -Recurse -Force
    }
    Copy-Item -LiteralPath $SkillSource.FullName -Destination $Destination -Recurse

    Write-Host "Installed $SkillName to $Destination"
    Write-Host "Restart Codex to reload available skills."
} finally {
    Remove-Item -LiteralPath $TempDir -Recurse -Force -ErrorAction SilentlyContinue
}
