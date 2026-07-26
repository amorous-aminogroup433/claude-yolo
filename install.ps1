[CmdletBinding()]
param([switch] $NoPath)

$ErrorActionPreference = 'Stop'
$sourceDirectory = Split-Path -Parent $PSCommandPath
$installRoot = if ($env:CLAUDE_YOLO_HOME) { $env:CLAUDE_YOLO_HOME } else { Join-Path $env:USERPROFILE '.claude-yolo' }
$installBin = Join-Path $installRoot 'bin'

$original = Get-Command claude -CommandType Application -ErrorAction SilentlyContinue |
    Where-Object { $_.Source -and $_.Source -notlike "$installBin*" } |
    Select-Object -First 1
if (-not $original) {
    throw 'claude-yolo: Claude CLI was not found in PATH.'
}

New-Item -ItemType Directory -Force -Path $installBin | Out-Null
Copy-Item (Join-Path $sourceDirectory 'bin\claude.cmd') (Join-Path $installBin 'claude.cmd') -Force
Copy-Item (Join-Path $sourceDirectory 'bin\claude.ps1') (Join-Path $installBin 'claude.ps1') -Force
Set-Content -NoNewline -Path (Join-Path $installRoot 'original-path') -Value $original.Source

if (-not $NoPath) {
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $pathEntries = @($userPath -split ';' | Where-Object { $_ })
    if ($pathEntries -notcontains $installBin) {
        [Environment]::SetEnvironmentVariable('Path', (@($installBin) + $pathEntries -join ';'), 'User')
    }
}

Write-Output "Installed claude-yolo in $installBin"
if ($NoPath) {
    Write-Output "Add this directory before the existing PATH: $installBin"
} else {
    Write-Output 'Open a new terminal before running claude --yolo.'
}
