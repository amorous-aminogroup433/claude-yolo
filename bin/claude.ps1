[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]] $Arguments
)

$ErrorActionPreference = 'Stop'
$scriptDirectory = Split-Path -Parent $PSCommandPath
$translated = foreach ($argument in $Arguments) {
    if ($argument -ceq '--yolo') { '--dangerously-skip-permissions' }
    else { $argument }
}

function Find-OriginalOnPath([string] $scriptDirectory) {
    foreach ($directory in ($env:Path -split [IO.Path]::PathSeparator)) {
        if (-not $directory) { continue }
        try { $resolvedDirectory = [IO.Path]::GetFullPath($directory) } catch { continue }
        if ($resolvedDirectory.TrimEnd('\') -ieq $scriptDirectory.TrimEnd('\')) { continue }
        foreach ($extension in '.exe', '.cmd', '.bat') {
            $candidate = Join-Path $resolvedDirectory "claude$extension"
            if (Test-Path -LiteralPath $candidate -PathType Leaf) { return $candidate }
        }
    }
    return $null
}

if ($env:CLAUDE_YOLO_ORIGINAL) {
    # An explicit override is authoritative: do not second-guess it.
    $original = $env:CLAUDE_YOLO_ORIGINAL
}
else {
    $original = $null
    $originalPathFile = Join-Path (Split-Path -Parent $scriptDirectory) 'original-path'
    if (Test-Path -LiteralPath $originalPathFile) {
        $original = (Get-Content -Raw $originalPathFile).TrimEnd("`r", "`n")
    }
    # Self-heal: if the recorded path is stale (Claude moved or was reinstalled
    # elsewhere), rediscover it from PATH instead of failing.
    if (-not $original -or -not (Test-Path -LiteralPath $original -PathType Leaf)) {
        $original = Find-OriginalOnPath $scriptDirectory
    }
}

if (-not $original -or -not (Test-Path -LiteralPath $original -PathType Leaf)) {
    [Console]::Error.WriteLine('claude-yolo: could not find the original Claude executable')
    exit 127
}

function ConvertTo-WindowsArgument([string] $value) {
    if ($value.Length -eq 0) { return '""' }
    if ($value -notmatch '[\s"]') { return $value }
    $escaped = [regex]::Replace($value, '(\\*)"', { param($match) $match.Groups[1].Value + $match.Groups[1].Value + '\"' })
    $escaped = [regex]::Replace($escaped, '(\\+)$', '$1$1')
    return '"' + $escaped + '"'
}

$isBatch = [IO.Path]::GetExtension($original) -in '.cmd', '.bat'

# Standard MSVCRT quoting is correct for a native executable. A .cmd/.bat target
# must be run through cmd.exe, which re-parses a handful of metacharacters; wrap
# any argument containing them so cmd treats them literally even without spaces.
$quoted = foreach ($value in $translated) {
    $argument = ConvertTo-WindowsArgument $value
    if ($isBatch -and $argument -notmatch '^".*"$' -and $value -match '[&|<>()^]') {
        $argument = '"' + $value + '"'
    }
    $argument
}
$argumentLine = $quoted -join ' '

# ProcessStartInfo (rather than the call operator) keeps PowerShell from turning
# native stderr into ErrorRecords and preserves the child's real exit code.
# Streams are left inherited (not redirected) so the child sees a real console:
# the interactive UI, colors, and raw stdin all keep working.
$startInfo = [Diagnostics.ProcessStartInfo]::new()
$startInfo.UseShellExecute = $false
if ($isBatch) {
    $startInfo.FileName = $env:ComSpec
    $startInfo.Arguments = '/d /s /c ""' + $original + '" ' + $argumentLine + '"'
}
else {
    $startInfo.FileName = $original
    $startInfo.Arguments = $argumentLine
}

$process = [Diagnostics.Process]::new()
$process.StartInfo = $startInfo
[void] $process.Start()
$process.WaitForExit()
$exitCode = $process.ExitCode
$process.Dispose()
exit $exitCode
