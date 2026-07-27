$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$temporary = Join-Path ([IO.Path]::GetTempPath()) ("claude-yolo-install-" + [guid]::NewGuid())
New-Item -ItemType Directory -Path $temporary | Out-Null

# Sandbox the install location. -NoPath keeps the real user PATH untouched, so
# this test never mutates persistent machine state (and uninstall.ps1, which
# always rewrites the User PATH, is deliberately not exercised here).
$installHome = Join-Path $temporary 'home'
$installBin = Join-Path $installHome 'bin'
$savedHome = $env:CLAUDE_YOLO_HOME
$savedOriginal = $env:CLAUDE_YOLO_ORIGINAL
try {
    # A fake "real" claude on PATH for install.ps1's Get-Command discovery.
    $realbin = Join-Path $temporary 'realbin'
    New-Item -ItemType Directory -Path $realbin | Out-Null
    $fake = Join-Path $realbin 'claude.cmd'
    Set-Content -Path $fake -Value @('@echo off', 'echo stdout:%*', 'exit /b %FAKE_EXIT_CODE%')

    $env:CLAUDE_YOLO_HOME = $installHome
    Remove-Item Env:CLAUDE_YOLO_ORIGINAL -ErrorAction SilentlyContinue
    $env:Path = "$realbin;$env:Path"

    powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'install.ps1') -NoPath | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "install.ps1 exited $LASTEXITCODE" }

    foreach ($name in 'claude.cmd', 'claude.ps1') {
        if (-not (Test-Path -LiteralPath (Join-Path $installBin $name))) { throw "install: $name missing" }
    }
    $recorded = (Get-Content -Raw (Join-Path $installHome 'original-path')).Trim()
    if ($recorded -ne $fake) { throw "install: original-path is [$recorded], expected [$fake]" }

    # The installed wrapper resolves the original via the recorded original-path.
    $stdout = Join-Path $temporary 'stdout'
    $wrapper = Join-Path $installBin 'claude.cmd'
    & $env:ComSpec /d /s /c "`"$wrapper`" --yolo `"fix this bug`" 1>`"$stdout`""
    $actual = (Get-Content -Raw $stdout).Trim()
    if ($actual -ne 'stdout:--dangerously-skip-permissions "fix this bug"') {
        throw "installed wrapper translation failed: [$actual]"
    }

    # Self-heal: a stale original-path falls back to PATH discovery ($realbin
    # is still on this process's PATH from the install step above).
    Set-Content -NoNewline -Path (Join-Path $installHome 'original-path') -Value (Join-Path $temporary 'gone\claude.cmd')
    & $env:ComSpec /d /s /c "`"$wrapper`" --yolo 1>`"$stdout`""
    $actual = (Get-Content -Raw $stdout).Trim()
    if ($actual -ne 'stdout:--dangerously-skip-permissions') {
        throw "self-heal failed: [$actual]"
    }

    Write-Output 'Windows install tests passed.'
    exit 0
}
finally {
    if ($null -ne $savedHome) { $env:CLAUDE_YOLO_HOME = $savedHome } else { Remove-Item Env:CLAUDE_YOLO_HOME -ErrorAction SilentlyContinue }
    if ($null -ne $savedOriginal) { $env:CLAUDE_YOLO_ORIGINAL = $savedOriginal }
    Remove-Item -Recurse -Force $temporary -ErrorAction SilentlyContinue
}
