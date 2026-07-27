#!/usr/bin/env sh
# Exercises the *installed* artifact: runs install.sh into a sandboxed
# CLAUDE_YOLO_HOME against a fake Claude, then drives the installed wrapper.
# This covers what test/run.sh (which tests bin/claude directly) cannot:
# installer output, original-path resolution, the download branch, and 127.
set -eu

root=$(CDPATH= cd "$(dirname "$0")/.." && pwd -P)
temporary=$(mktemp -d)
trap 'rm -rf "$temporary"' EXIT HUP INT TERM

# A fake "real" claude that echoes its arguments and honours FAKE_EXIT_CODE.
realbin=$temporary/realbin
mkdir -p "$realbin"
cat > "$realbin/claude" <<'EOF'
#!/usr/bin/env sh
printf 'stdout:'
for item in "$@"; do printf '<%s>' "$item"; done
printf '\n'
exit "${FAKE_EXIT_CODE:-0}"
EOF
chmod 755 "$realbin/claude"
# The installer records symlink-resolved paths (mktemp on macOS lives behind
# /var -> /private/var), so assert against the resolved spelling.
realbin_resolved=$(CDPATH= cd "$realbin" && pwd -P)

fail() { echo "install-test: $1" >&2; exit 1; }

# Run the installed wrapper and assert stdout + exit status.
check() {
    home=$1 name=$2 expected_stdout=$3 expected_status=$4
    shift 4
    out=$temporary/out
    set +e
    # CLAUDE_YOLO_ORIGINAL is intentionally unset so resolution goes through
    # the installed original-path file, exactly as a real user's shell would.
    ( unset CLAUDE_YOLO_ORIGINAL; CLAUDE_YOLO_HOME="$home" "$home/bin/claude" "$@" ) >"$out" 2>/dev/null
    status=$?
    set -e
    [ "$status" -eq "$expected_status" ] || fail "$name: exit $status != $expected_status"
    [ "$(cat "$out")" = "$expected_stdout" ] || fail "$name: stdout [$(cat "$out")] != [$expected_stdout]"
}

# --- Path A: clone install (local bin/claude is copied) -----------------------
home_a=$temporary/home-clone
CLAUDE_YOLO_HOME="$home_a" PATH="$realbin:$PATH" sh "$root/install.sh" --no-profile >/dev/null

[ -f "$home_a/bin/claude" ] || fail "clone: wrapper not installed"
[ "$(cat "$home_a/original-path")" = "$realbin_resolved/claude" ] || fail "clone: original-path not recorded"
[ -x "$home_a/bin/claude" ] || fail "clone: installed wrapper not executable"

check "$home_a" 'clone/bare'   'stdout:' 0
check "$home_a" 'clone/yolo'   'stdout:<--dangerously-skip-permissions>' 0 --yolo
check "$home_a" 'clone/prompt' 'stdout:<--dangerously-skip-permissions><fix this bug>' 0 --yolo 'fix this bug'
check "$home_a" 'clone/passthrough' 'stdout:<update>' 0 update

# Re-installing with the shim already first on PATH must not record the shim
# itself as the original (that would make the wrapper exec itself forever).
CLAUDE_YOLO_HOME="$home_a" PATH="$home_a/bin:$realbin:$PATH" sh "$root/install.sh" --no-profile >/dev/null
[ "$(cat "$home_a/original-path")" = "$realbin_resolved/claude" ] \
    || fail "reinstall: original-path is $(cat "$home_a/original-path")"
check "$home_a" 'reinstall/yolo' 'stdout:<--dangerously-skip-permissions>' 0 --yolo

# Exit-code propagation through the installed wrapper.
set +e
( unset CLAUDE_YOLO_ORIGINAL; FAKE_EXIT_CODE=23 CLAUDE_YOLO_HOME="$home_a" "$home_a/bin/claude" --yolo ) >/dev/null 2>&1
status=$?
set -e
[ "$status" -eq 23 ] || fail "clone: exit propagation got $status"

# Missing original executable -> 127 (CLAUDE_YOLO_ORIGINAL wins over original-path).
set +e
CLAUDE_YOLO_ORIGINAL="$temporary/does-not-exist" "$home_a/bin/claude" --yolo >/dev/null 2>&1
status=$?
set -e
[ "$status" -eq 127 ] || fail "missing original: got $status, expected 127"

# CLAUDE_YOLO_ORIGINAL pointing back at the shim is a wrong explicit value:
# it must fail with 127, not exec itself forever.
set +e
CLAUDE_YOLO_ORIGINAL="$home_a/bin/claude" "$home_a/bin/claude" --yolo >/dev/null 2>&1
status=$?
set -e
[ "$status" -eq 127 ] || fail "self-referencing original: got $status, expected 127"

# A self-referencing original-path (broken install) must self-heal via the
# PATH scan rather than exec itself forever.
printf '%s\n' "$home_a/bin/claude" > "$home_a/original-path"
out=$temporary/out
set +e
( unset CLAUDE_YOLO_ORIGINAL; PATH="$realbin:$PATH" CLAUDE_YOLO_HOME="$home_a" "$home_a/bin/claude" --yolo ) >"$out" 2>/dev/null
status=$?
set -e
[ "$status" -eq 0 ] || fail "self-reference heal: exit $status"
[ "$(cat "$out")" = 'stdout:<--dangerously-skip-permissions>' ] || fail "self-reference heal: stdout [$(cat "$out")]"

# Self-heal: a stale original-path falls back to PATH discovery.
printf '%s\n' "$temporary/gone/claude" > "$home_a/original-path"
out=$temporary/out
set +e
( unset CLAUDE_YOLO_ORIGINAL; PATH="$realbin:$PATH" CLAUDE_YOLO_HOME="$home_a" "$home_a/bin/claude" --yolo ) >"$out" 2>/dev/null
status=$?
set -e
[ "$status" -eq 0 ] || fail "self-heal: exit $status"
[ "$(cat "$out")" = 'stdout:<--dangerously-skip-permissions>' ] || fail "self-heal: stdout [$(cat "$out")]"

# Uninstall removes the installed files (profile untouched via --no-profile).
CLAUDE_YOLO_HOME="$home_a" CLAUDE_YOLO_PROFILE="$temporary/noprofile" sh "$root/uninstall.sh" >/dev/null
[ ! -e "$home_a/bin/claude" ] || fail "uninstall: wrapper still present"
[ ! -e "$home_a/original-path" ] || fail "uninstall: original-path still present"

# --- Path B: download install (curl|sh path, fetched via file://) -------------
# Copy install.sh alone so no sibling bin/claude exists, forcing the download.
lone=$temporary/lone
mkdir -p "$lone"
cp "$root/install.sh" "$lone/install.sh"
# Prefer a native path for the file:// URL (Windows curl rejects MSYS /d/... paths).
repo_path=$(cd "$root" && pwd -W 2>/dev/null || printf '%s' "$root")
repo_url="file://$repo_path"

home_b=$temporary/home-download
if CLAUDE_YOLO_HOME="$home_b" CLAUDE_YOLO_REPO_URL="$repo_url" PATH="$realbin:$PATH" \
        sh "$lone/install.sh" --no-profile >/dev/null 2>&1; then
    cmp -s "$home_b/bin/claude" "$root/bin/claude" \
        || fail "download: fetched wrapper differs from bin/claude"
    check "$home_b" 'download/yolo' 'stdout:<--dangerously-skip-permissions>' 0 --yolo
else
    # file:// support in curl/wget is not universal; skip rather than false-fail.
    echo "install-test: note: download-path check skipped (no file:// support)" >&2
fi

echo 'All install tests passed.'
