[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$installRoot = if ($env:CLAUDE_YOLO_HOME) { $env:CLAUDE_YOLO_HOME } else { Join-Path $env:USERPROFILE '.claude-yolo' }
$installBin = Join-Path $installRoot 'bin'

$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
$remaining = @($userPath -split ';' | Where-Object { $_ -and $_ -ine $installBin })
[Environment]::SetEnvironmentVariable('Path', ($remaining -join ';'), 'User')

Remove-Item -LiteralPath (Join-Path $installBin 'claude.cmd') -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath (Join-Path $installBin 'claude.ps1') -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath (Join-Path $installRoot 'original-path') -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $installBin -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $installRoot -Force -ErrorAction SilentlyContinue
Write-Output 'claude-yolo uninstalled'
