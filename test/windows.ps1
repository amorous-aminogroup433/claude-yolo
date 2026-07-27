$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$temporary = Join-Path ([IO.Path]::GetTempPath()) ("claude-yolo-test-" + [guid]::NewGuid())
New-Item -ItemType Directory -Path $temporary | Out-Null
try {
    $fake = Join-Path $temporary 'real-claude.cmd'
    Set-Content -Path $fake -Value @('@echo off', 'echo stdout:%*', 'echo stderr:%* 1>&2', 'exit /b %FAKE_EXIT_CODE%')

    $env:CLAUDE_YOLO_ORIGINAL = $fake
    $stderr = Join-Path $temporary 'stderr'
    $stdout = Join-Path $temporary 'stdout'
    $wrapper = Join-Path $root 'bin\claude.cmd'

    & $env:ComSpec /d /s /c "`"$wrapper`" 1>`"$stdout`" 2>`"$stderr`""
    if ($LASTEXITCODE -ne 0) { throw "no-argument exit status failed: $LASTEXITCODE" }
    if ((Get-Content -Raw $stdout).Trim() -ne 'stdout:') { throw 'no-argument stdout failed' }
    if ((Get-Content -Raw $stderr).Trim() -ne 'stderr:') { throw 'no-argument stderr failed' }

    & $env:ComSpec /d /s /c "`"$wrapper`" --yolo `"fix this bug`" 1>`"$stdout`" 2>`"$stderr`""
    $actualStdout = (Get-Content -Raw $stdout).Trim()
    if ($actualStdout -ne 'stdout:--dangerously-skip-permissions "fix this bug"') { throw "stdout translation failed: [$actualStdout]" }
    if ((Get-Content -Raw $stderr).Trim() -ne 'stderr:--dangerously-skip-permissions "fix this bug"') { throw 'stderr propagation failed' }

    # A cmd metacharacter with no surrounding spaces must survive the cmd.exe
    # round-trip (regression guard for the & / | / < > handling).
    & $env:ComSpec /d /s /c "`"$wrapper`" `"a&b`" 1>`"$stdout`" 2>`"$stderr`""
    $actualStdout = (Get-Content -Raw $stdout).Trim()
    if ($actualStdout -ne 'stdout:"a&b"') { throw "metacharacter handling failed: [$actualStdout]" }

    $env:FAKE_EXIT_CODE = '23'
    & $env:ComSpec /d /s /c "`"$wrapper`" --yolo >nul 2>nul"
    if ($LASTEXITCODE -ne 23) { throw "exit propagation failed: $LASTEXITCODE" }

    # CLAUDE_YOLO_ORIGINAL pointing back at the shim is a wrong explicit
    # value: it must fail with 127, not re-enter the wrapper forever.
    $env:CLAUDE_YOLO_ORIGINAL = $wrapper
    & $env:ComSpec /d /s /c "`"$wrapper`" --yolo >nul 2>nul"
    if ($LASTEXITCODE -ne 127) { throw "self-referencing original: $LASTEXITCODE, expected 127" }

    Write-Output 'Windows tests passed.'
    # Do not leak the last subprocess's exit code; GitHub's powershell shell
    # propagates $LASTEXITCODE and would otherwise fail the job.
    exit 0
}
finally {
    Remove-Item Env:CLAUDE_YOLO_ORIGINAL -ErrorAction SilentlyContinue
    Remove-Item Env:FAKE_EXIT_CODE -ErrorAction SilentlyContinue
    Remove-Item -Recurse -Force $temporary -ErrorAction SilentlyContinue
}
