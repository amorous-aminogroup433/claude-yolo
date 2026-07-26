#!/usr/bin/env sh
set -eu

root=$(CDPATH= cd "$(dirname "$0")/.." && pwd -P)
temporary=$(mktemp -d)
trap 'rm -rf "$temporary"' EXIT HUP INT TERM

fake=$temporary/real-claude
cat > "$fake" <<'EOF'
#!/usr/bin/env sh
printf 'stdout:'
for item in "$@"; do printf '<%s>' "$item"; done
printf '\n'
printf 'stderr:' >&2
for item in "$@"; do printf '<%s>' "$item" >&2; done
printf '\n' >&2
exit "${FAKE_EXIT_CODE:-0}"
EOF
chmod 755 "$fake"

check() {
    name=$1 expected_stdout=$2 expected_stderr=$3 expected_status=$4
    shift 4
    stdout=$temporary/stdout stderr=$temporary/stderr
    set +e
    CLAUDE_YOLO_ORIGINAL="$fake" "$root/bin/claude" "$@" >"$stdout" 2>"$stderr"
    status=$?
    set -e
    [ "$status" -eq "$expected_status" ] || { echo "$name: wrong exit status: $status" >&2; exit 1; }
    [ "$(cat "$stdout")" = "$expected_stdout" ] || { echo "$name: wrong stdout" >&2; exit 1; }
    [ "$(cat "$stderr")" = "$expected_stderr" ] || { echo "$name: wrong stderr" >&2; exit 1; }
}

check 'no arguments' 'stdout:' 'stderr:' 0
check 'yolo' 'stdout:<--dangerously-skip-permissions>' 'stderr:<--dangerously-skip-permissions>' 0 --yolo
check 'prompt' 'stdout:<--dangerously-skip-permissions><fix this bug>' 'stderr:<--dangerously-skip-permissions><fix this bug>' 0 --yolo 'fix this bug'
check 'multiple arguments' 'stdout:<chat><--dangerously-skip-permissions><--print>' 'stderr:<chat><--dangerously-skip-permissions><--print>' 0 chat --yolo --print
check 'unchanged' 'stdout:<update>' 'stderr:<update>' 0 update

set +e
FAKE_EXIT_CODE=23 CLAUDE_YOLO_ORIGINAL="$fake" "$root/bin/claude" --yolo >"$temporary/stdout" 2>"$temporary/stderr"
status=$?
set -e
[ "$status" -eq 23 ] || { echo "exit propagation: got $status" >&2; exit 1; }
[ "$(cat "$temporary/stderr")" = 'stderr:<--dangerously-skip-permissions>' ] || { echo 'stderr propagation failed' >&2; exit 1; }

echo 'All tests passed.'
