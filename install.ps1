[CmdletBinding()]
param([switch] $NoPath)

$ErrorActionPreference = 'Stop'
$sourceDirectory = if ($PSCommandPath) { Split-Path -Parent $PSCommandPath } else { $null }
$repositoryUrl = 'https://raw.githubusercontent.com/khanalsaroj/claude-yolo/main'
$installRoot = if ($env:CLAUDE_YOLO_HOME) { $env:CLAUDE_YOLO_HOME } else { Join-Path $env:USERPROFILE '.claude-yolo' }
$installBin = Join-Path $installRoot 'bin'

$original = Get-Command claude -CommandType Application -ErrorAction SilentlyContinue |
    Where-Object { $_.Source -and $_.Source -notlike "$installBin*" } |
    Select-Object -First 1
if (-not $original) {
    throw 'claude-yolo: Claude CLI was not found in PATH.'
}

New-Item -ItemType Directory -Force -Path $installBin | Out-Null
$wrapperSource = if ($sourceDirectory) { Join-Path $sourceDirectory 'bin' } else { $null }
if ($wrapperSource -and (Test-Path -LiteralPath $wrapperSource -PathType Container)) {
    Copy-Item (Join-Path $wrapperSource 'claude.cmd') (Join-Path $installBin 'claude.cmd') -Force
    Copy-Item (Join-Path $wrapperSource 'claude.ps1') (Join-Path $installBin 'claude.ps1') -Force
}
else {
    # Support `irm .../install.ps1 | iex`, where only this installer is present.
    Invoke-WebRequest -UseBasicParsing -Uri "$repositoryUrl/bin/claude.cmd" -OutFile (Join-Path $installBin 'claude.cmd')
    Invoke-WebRequest -UseBasicParsing -Uri "$repositoryUrl/bin/claude.ps1" -OutFile (Join-Path $installBin 'claude.ps1')
}
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
