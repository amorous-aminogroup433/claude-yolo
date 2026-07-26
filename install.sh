#!/usr/bin/env sh
# Installs a PATH shim; the Claude executable itself is never changed.
set -eu

usage() {
    echo "Usage: $0 [--no-profile]" >&2
}

update_profile=true
case "${1:-}" in
    '') ;;
    --no-profile) update_profile=false ;;
    *) usage; exit 2 ;;
esac

source_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
wrapper_source=$source_dir/bin/claude

original=$(command -v claude 2>/dev/null || true)
[ -n "$original" ] || { echo "claude-yolo: Claude CLI was not found in PATH" >&2; exit 1; }

install_root=${CLAUDE_YOLO_HOME:-"$HOME/.claude-yolo"}
install_bin=$install_root/bin
mkdir -p "$install_bin"
if [ -f "$wrapper_source" ]; then
    cp "$wrapper_source" "$install_bin/claude"
else
    # Keep the curl | sh installation path self-contained.
    cat > "$install_bin/claude" <<'WRAPPER'
#!/usr/bin/env bash
set -u
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
translated=()
for argument in "$@"; do
    case "$argument" in
        --yolo) translated+=("--dangerously-skip-permissions") ;;
        *) translated+=("$argument") ;;
    esac
done
if [ -n "${CLAUDE_YOLO_ORIGINAL:-}" ]; then
    original=$CLAUDE_YOLO_ORIGINAL
elif [ -r "$script_dir/../original-path" ]; then
    IFS= read -r original < "$script_dir/../original-path" || original=
else
    original=
    old_ifs=$IFS
    IFS=:
    for directory in ${PATH:-}; do
        [ -n "$directory" ] || directory=.
        resolved_directory=$(CDPATH= cd -- "$directory" 2>/dev/null && pwd -P) || continue
        [ "$resolved_directory" = "$script_dir" ] && continue
        candidate=$resolved_directory/claude
        if [ -f "$candidate" ] && [ -x "$candidate" ]; then original=$candidate; break; fi
    done
    IFS=$old_ifs
fi
if [ -z "${original:-}" ] || [ ! -x "$original" ]; then
    echo "claude-yolo: could not find the original Claude executable" >&2
    exit 127
fi
exec "$original" "${translated[@]}"
WRAPPER
fi
chmod 755 "$install_bin/claude"
printf '%s\n' "$original" > "$install_root/original-path"

profile=
if "$update_profile"; then
    if [ -n "${CLAUDE_YOLO_PROFILE:-}" ]; then
        profile=$CLAUDE_YOLO_PROFILE
    else
        case "${SHELL:-}" in
            */zsh) profile=$HOME/.zshrc ;;
            */bash) profile=$HOME/.bashrc ;;
            *) profile=$HOME/.profile ;;
        esac
    fi
    touch "$profile"
    if ! grep -Fq '# >>> claude-yolo >>>' "$profile"; then
        escaped_bin=$(printf '%s' "$install_bin" | sed "s/'/'\\\\''/g")
        {
            echo '# >>> claude-yolo >>>'
            printf "export PATH='%s':\"\$PATH\"\n" "$escaped_bin"
            echo '# <<< claude-yolo <<<'
        } >> "$profile"
    fi
fi

echo "Installed claude-yolo in $install_bin"
if [ -n "$profile" ]; then
    echo "Restart your shell or run: export PATH=\"$install_bin:\$PATH\""
else
    echo "Add this directory before the existing PATH: $install_bin"
fi
