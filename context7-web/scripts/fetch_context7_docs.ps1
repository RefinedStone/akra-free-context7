param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string] $Library,
    [Parameter(Position = 1)]
    [string] $Topic = "",
    [Parameter(Position = 2)]
    [string] $Tokens = "10000",
    [Parameter(Position = 3)]
    [string] $Type = "json"
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Python = Get-Command python -ErrorAction SilentlyContinue
if ($Python) {
    & $Python.Source (Join-Path $ScriptDir "context7_web.py") fetch $Library --topic $Topic --tokens $Tokens --type $Type
    exit $LASTEXITCODE
}

$Py = Get-Command py -ErrorAction SilentlyContinue
if ($Py) {
    & $Py.Source -3 (Join-Path $ScriptDir "context7_web.py") fetch $Library --topic $Topic --tokens $Tokens --type $Type
    exit $LASTEXITCODE
}

throw "Python 3 was not found. Install Python 3 and retry."
