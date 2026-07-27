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

source_dir=$(CDPATH= cd "$(dirname "$0")" && pwd -P)
wrapper_source=$source_dir/bin/claude
repository_url=${CLAUDE_YOLO_REPO_URL:-https://raw.githubusercontent.com/khanalsaroj/claude-yolo/main}

install_root=${CLAUDE_YOLO_HOME:-"$HOME/.claude-yolo"}
install_bin=$install_root/bin
# Resolved for comparison below; on a fresh install the directory does not
# exist yet, in which case nothing on PATH can be it.
install_bin_resolved=$(CDPATH= cd -- "$install_bin" 2>/dev/null && pwd -P) || install_bin_resolved=

# Find the real Claude by walking PATH, skipping our own install directory:
# on a re-install the shim is already first on PATH, and recording the shim
# itself as the "original" would make the wrapper exec itself forever.
original=
old_ifs=$IFS
IFS=:
for directory in ${PATH:-}; do
    [ -n "$directory" ] || directory=.
    resolved_directory=$(CDPATH= cd -- "$directory" 2>/dev/null && pwd -P) || continue
    if [ "$resolved_directory" = "$install_bin_resolved" ]; then continue; fi
    candidate=$resolved_directory/claude
    if [ -f "$candidate" ] && [ -x "$candidate" ]; then
        original=$candidate
        break
    fi
done
IFS=$old_ifs
[ -n "$original" ] || { echo "claude-yolo: Claude CLI was not found in PATH" >&2; exit 1; }

mkdir -p "$install_bin"
if [ -f "$wrapper_source" ]; then
    cp "$wrapper_source" "$install_bin/claude"
else
    # curl | sh path: only this installer is present, so fetch the single
    # source-of-truth wrapper from the repository instead of embedding a copy.
    wrapper_url=$repository_url/bin/claude
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$wrapper_url" -o "$install_bin/claude" \
            || { echo "claude-yolo: failed to download the wrapper from $wrapper_url" >&2; exit 1; }
    elif command -v wget >/dev/null 2>&1; then
        wget -qO "$install_bin/claude" "$wrapper_url" \
            || { echo "claude-yolo: failed to download the wrapper from $wrapper_url" >&2; exit 1; }
    else
        echo "claude-yolo: need curl or wget to download the wrapper" >&2
        exit 1
    fi
    [ -s "$install_bin/claude" ] \
        || { echo "claude-yolo: downloaded wrapper is empty" >&2; exit 1; }
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
