# plan.md

# Claude YOLO

A tiny wrapper that adds `--yolo` as an alias for Claude CLI's
`--dangerously-skip-permissions`.

## Goal

Allow developers to type:

```bash
claude --yolo
```

instead of:

```bash
claude --dangerously-skip-permissions
```

The wrapper should behave exactly like the original Claude CLI in every other
situation.

---

# MVP

## Features

- Replace `--yolo` with `--dangerously-skip-permissions`
- Forward every other argument unchanged
- Preserve exit codes
- Preserve stdout/stderr
- Add almost zero startup overhead

Example:

```bash
claude --yolo "fix this bug"
```

becomes

```bash
claude --dangerously-skip-permissions "fix this bug"
```

---

# Installation

Provide an install script:

```bash
curl -fsSL https://.../install.sh | bash
```

The installer should:

1. Detect the Claude executable.
2. Install the wrapper.
3. Keep the original Claude executable untouched whenever possible.
4. Make uninstall easy.

---

# Wrapper Behavior

Input:

```bash
claude --yolo
```

Output:

```bash
claude --dangerously-skip-permissions
```

Input:

```bash
claude --yolo --print
```

Output:

```bash
claude --dangerously-skip-permissions --print
```

Input:

```bash
claude chat
```

Output:

```bash
claude chat
```

Input:

```bash
claude update
```

Output:

```bash
claude update
```

Only the `--yolo` flag should be translated.

---

# Project Structure

```
claude-yolo/
├── README.md
├── LICENSE
├── install.sh
├── uninstall.sh
├── bin/
│   └── claude
├── test/
└── .github/
    └── workflows/
```

---

# README

Include:

- What the project does
- Installation
- Usage examples
- Uninstall instructions
- Disclaimer that this is an unofficial wrapper

---

# Tests

Test:

- no arguments
- --yolo
- --yolo with prompts
- multiple arguments
- exit code propagation
- stderr propagation

---

# Nice-to-have

- Support aliases:

```
--yolo
--yes
```

via a simple config file.

---

# Non-goals

- Do not modify Claude internals.
- Do not patch binaries.
- Do not reimplement Claude.
- Do not change any behavior except replacing `--yolo`.

---

# Success Criteria

After installation:

```bash
claude --yolo
```

behaves identically to:

```bash
claude --dangerously-skip-permissions
```

with no noticeable performance difference.