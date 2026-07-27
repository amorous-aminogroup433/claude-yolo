# Claude YOLO

Claude's best flag deserved a shorter name.

```bash
claude --yolo
```

is translated to:

```bash
claude --dangerously-skip-permissions
```

`claude-yolo` is a tiny unofficial wrapper. It does not modify Claude or patch binaries; every other argument, output stream, and exit code is passed through unchanged.

Only an argument that is exactly `--yolo` is rewritten. Anything else — including `--yolo=...` or `--yolo` used as another flag's value — is passed through untouched.

## Install

Claude CLI must already be on your `PATH`.

**macOS / Linux**

```bash
curl -fsSL https://raw.githubusercontent.com/khanalsaroj/claude-yolo/main/install.sh | sh
```

Or from a clone: `./install.sh`

**Windows (PowerShell installer)**

Open PowerShell as Administrator:

```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
iwr -useb https://raw.githubusercontent.com/khanalsaroj/claude-yolo/main/install.ps1 | iex
```

Or from a clone:

```powershell
.\install.ps1
```

Restart your terminal after installation.

## Use

```bash
claude --yolo "fix this bug"
claude --yolo --print
```

## Uninstall

```bash
./uninstall.sh
```

Windows: `./uninstall.ps1`

## Development

The wrapper has a single source of truth per platform: `bin/claude` (POSIX) and
`bin/claude.ps1` (+ `bin/claude.cmd`, Windows). Installers copy these when run
from a clone, or download them from the repo for the `curl | sh` / `iwr | iex`
paths — they never embed a second copy, so there is nothing to keep in sync.

Run the tests locally:

```bash
sh test/run.sh          # wrapper translation
sh test/install.sh      # the installed artifact, incl. the download path
```

```powershell
./test/windows.ps1          # Windows wrapper
./test/windows-install.ps1  # Windows installer (sandboxed, PATH untouched)
```

CI runs all of these on Linux, macOS, and Windows.

## Disclaimer

Unofficial and not affiliated with Anthropic. `--yolo` skips Claude permission prompts—use it only in an environment you trust.
