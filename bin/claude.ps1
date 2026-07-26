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

if ($env:CLAUDE_YOLO_ORIGINAL) {
    $original = $env:CLAUDE_YOLO_ORIGINAL
}
elseif (Test-Path (Join-Path (Split-Path -Parent $scriptDirectory) 'original-path')) {
    $original = (Get-Content -Raw (Join-Path (Split-Path -Parent $scriptDirectory) 'original-path')).TrimEnd("`r", "`n")
}
else {
    $original = $null
    foreach ($directory in ($env:Path -split [IO.Path]::PathSeparator)) {
        if (-not $directory) { continue }
        try { $resolvedDirectory = [IO.Path]::GetFullPath($directory) } catch { continue }
        if ($resolvedDirectory.TrimEnd('\') -ieq $scriptDirectory.TrimEnd('\')) { continue }
        foreach ($extension in '.exe', '.cmd', '.bat') {
            $candidate = Join-Path $resolvedDirectory "claude$extension"
            if (Test-Path -LiteralPath $candidate -PathType Leaf) {
                $original = $candidate
                break
            }
        }
        if ($original) { break }
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

# ProcessStartInfo avoids PowerShell converting native stderr into ErrorRecords.
$argumentLine = (($translated | ForEach-Object { ConvertTo-WindowsArgument $_ }) -join ' ')
$startInfo = [Diagnostics.ProcessStartInfo]::new()
$startInfo.UseShellExecute = $false
$startInfo.RedirectStandardOutput = $true
$startInfo.RedirectStandardError = $true
$startInfo.FileName = $original
$startInfo.Arguments = $argumentLine
if ([IO.Path]::GetExtension($original) -in '.cmd', '.bat') {
    $startInfo.FileName = $env:ComSpec
    $startInfo.Arguments = '/d /s /c ""' + $original + '" ' + $argumentLine + '"'
}

$process = [Diagnostics.Process]::new()
$process.StartInfo = $startInfo
[void] $process.Start()
$stdoutTask = $process.StandardOutput.BaseStream.CopyToAsync([Console]::OpenStandardOutput())
$stderrTask = $process.StandardError.BaseStream.CopyToAsync([Console]::OpenStandardError())
$process.WaitForExit()
[void] $stdoutTask.GetAwaiter().GetResult()
[void] $stderrTask.GetAwaiter().GetResult()
$exitCode = $process.ExitCode
$process.Dispose()
exit $exitCode
