#!/usr/bin/env sh
# Removes only files and profile lines created by install.sh.
set -eu

install_root=${CLAUDE_YOLO_HOME:-"$HOME/.claude-yolo"}
install_bin=$install_root/bin
profile=${CLAUDE_YOLO_PROFILE:-}

if [ -z "$profile" ]; then
    case "${SHELL:-}" in
        */zsh) profile=$HOME/.zshrc ;;
        */bash) profile=$HOME/.bashrc ;;
        *) profile=$HOME/.profile ;;
    esac
fi

if [ -f "$profile" ] && grep -Fq '# >>> claude-yolo >>>' "$profile"; then
    temporary=$(mktemp "${profile}.claude-yolo.XXXXXX")
    awk '
        /# >>> claude-yolo >>>/ { skipping=1; next }
        /# <<< claude-yolo <<</ { skipping=0; next }
        !skipping { print }
    ' "$profile" > "$temporary"
    mv "$temporary" "$profile"
fi

rm -f "$install_bin/claude" "$install_root/original-path"
rmdir "$install_bin" 2>/dev/null || true
rmdir "$install_root" 2>/dev/null || true
echo "claude-yolo uninstalled"
