# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

`claude-yolo` is a PATH shim that intercepts `claude` and rewrites the single argument
`--yolo` to `--dangerously-skip-permissions`, then execs the real Claude CLI. It is not
an application: there is no build step, no dependencies, and no runtime beyond POSIX sh
and Windows PowerShell. Everything else (all other args, stdio, exit code) passes through
untouched. Only an argument that is *exactly* `--yolo` is translated — `--yolo=...` and
`--yolo` used as another flag's value are left alone.

## Tests (there is no build or lint)

```bash
sh test/run.sh          # POSIX wrapper: argument translation + exit propagation
sh test/install.sh      # the *installed* artifact, incl. the download path & self-heal
```
```powershell
./test/windows.ps1          # Windows wrapper (bin/claude.cmd -> bin/claude.ps1)
./test/windows-install.ps1  # Windows installer (sandboxed with -NoPath)
```

There is no test runner or filtering — each file is a flat sequence of `check`/assertion
calls; to run a "single test" temporarily comment out the others. CI (`.github/workflows/test.yml`)
runs the sh tests on Linux + macOS and the ps1 tests on Windows.

Tests never touch a real Claude install: they point `CLAUDE_YOLO_ORIGINAL` at a fake
`claude` that echoes its args and honours `FAKE_EXIT_CODE`, and sandbox installs via
`CLAUDE_YOLO_HOME` / `CLAUDE_YOLO_PROFILE` (+ `--no-profile` / `-NoPath` so the real
shell profile and user PATH are never modified).

## Architecture and invariants

The two platform wrappers are the product; installers/uninstallers are packaging.

- **Single source of truth per platform.** `bin/claude` (POSIX) and `bin/claude.ps1`
  (+ `bin/claude.cmd`) are the wrappers. Installers **copy** them when run from a clone,
  or **download** them from the repo for the `curl | sh` / `iwr | iex` paths
  (`CLAUDE_YOLO_REPO_URL`, default the GitHub raw URL). Do **not** re-introduce an embedded
  copy of a wrapper inside an installer — a stale duplicate is exactly the class of bug this
  layout exists to prevent, and CI would not catch it because CI runs `bin/*` directly.

- **Original-executable discovery** (in both wrappers, kept in sync by hand):
  1. `$CLAUDE_YOLO_ORIGINAL` if set — **authoritative, no fallback**. Do not add a PATH
     fallback here; a wrong explicit value must fail with exit 127 (a test depends on this).
  2. else the cached `original-path` file (written at install time next to `bin/`),
  3. else, **self-heal** by scanning PATH for `claude` (skipping the wrapper's own dir) —
     this also covers a stale cached path when Claude is reinstalled elsewhere.

  A candidate that resolves into the wrapper's own directory is never accepted — the
  wrapper would exec itself forever. A self-referencing cached path is treated as stale
  (falls through to the PATH scan); a self-referencing `$CLAUDE_YOLO_ORIGINAL` exits 127.
  The installers likewise skip the install bin when discovering the original, so a
  re-install never records the shim itself in `original-path`.

- **Windows stdio is inherited, never redirected.** `claude.ps1` launches via
  `ProcessStartInfo` with `UseShellExecute=$false` and no stream redirection. The
  `ProcessStartInfo` route (instead of the `&` call operator) is what stops PowerShell
  wrapping native stderr into ErrorRecords and preserves the child's real exit code;
  leaving stdout/stderr un-redirected is what lets Claude's interactive TUI see a real
  console. Do not re-add `RedirectStandardOutput/Error` — it breaks the interactive UI.

- **Windows `.cmd`/`.bat` targets go through `cmd.exe`**, which re-parses metacharacters.
  Args containing `& | < > ( ) ^` are quoted so cmd treats them literally. Embedded quotes
  and `%VAR%` through this path remain an unsolved cmd/MSVCRT quoting limitation.

- **`test/windows.ps1` (and any ps1 test) must `exit 0` on success.** GitHub's `powershell`
  shell propagates `$LASTEXITCODE`; a leaked non-zero code from the last subprocess fails
  the job even when assertions pass.

## Environment variables

- `CLAUDE_YOLO_ORIGINAL` — force the real Claude path (authoritative; used by tests).
- `CLAUDE_YOLO_HOME` — install root (default `~/.claude-yolo` / `%USERPROFILE%\.claude-yolo`).
- `CLAUDE_YOLO_PROFILE` — shell profile the POSIX installer edits (default per `$SHELL`).
- `CLAUDE_YOLO_REPO_URL` — base URL the installers download wrappers from when not run from a clone.
