param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string] $Query,
    [Parameter(Position = 1)]
    [int] $Limit = 10,
    [Parameter(Position = 2)]
    [ValidateSet("summary", "json")]
    [string] $Format = "summary"
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Python = Get-Command python -ErrorAction SilentlyContinue
if ($Python) {
    & $Python.Source (Join-Path $ScriptDir "context7_web.py") search $Query --limit $Limit --format $Format
    exit $LASTEXITCODE
}

$Py = Get-Command py -ErrorAction SilentlyContinue
if ($Py) {
    & $Py.Source -3 (Join-Path $ScriptDir "context7_web.py") search $Query --limit $Limit --format $Format
    exit $LASTEXITCODE
}

throw "Python 3 was not found. Install Python 3 and retry."
