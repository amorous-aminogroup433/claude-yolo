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

## Install

Claude CLI must already be on your `PATH`.

**macOS / Linux**

```bash
curl -fsSL https://raw.githubusercontent.com/OWNER/claude-yolo/main/install.sh | sh
```

Or from a clone: `./install.sh`

**Windows (PowerShell)**

```powershell
.\install.ps1
```

Open a new terminal after installation.

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

## Disclaimer

Unofficial and not affiliated with Anthropic. `--yolo` skips Claude permission prompts—use it only in an environment you trust.
