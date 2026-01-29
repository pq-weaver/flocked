#!/bin/sh
#
# flocked installer
#
# Usage: curl -fsSL https://raw.githubusercontent.com/pq-weaver/flocked/main/install.sh | sh
#
set -e

REPO="pq-weaver/flocked"
BINARY="flocked"
URL="https://raw.githubusercontent.com/$REPO/main/$BINARY"

main() {
    # Determine install directory
    if [ -w /usr/local/bin ]; then
        INSTALL_DIR="/usr/local/bin"
    else
        INSTALL_DIR="$HOME/.local/bin"
        mkdir -p "$INSTALL_DIR"
    fi

    TARGET="$INSTALL_DIR/$BINARY"

    printf 'Installing %s to %s...\n' "$BINARY" "$TARGET"

    # Download
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$URL" -o "$TARGET"
    elif command -v wget >/dev/null 2>&1; then
        wget -qO "$TARGET" "$URL"
    else
        printf 'Error: curl or wget required\n' >&2
        exit 1
    fi

    # Make executable
    chmod +x "$TARGET"

    # Verify
    if [ ! -x "$TARGET" ]; then
        printf 'Error: installation failed\n' >&2
        exit 1
    fi

    printf 'Installed %s %s\n' "$BINARY" "$("$TARGET" --version 2>/dev/null || echo "")"

    # Warn about PATH if using ~/.local/bin
    if [ "$INSTALL_DIR" = "$HOME/.local/bin" ]; then
        case ":$PATH:" in
            *":$INSTALL_DIR:"*) ;;
            *)
                printf '\nNote: Add %s to your PATH:\n' "$INSTALL_DIR"
                printf '  export PATH="%s:$PATH"\n' "$INSTALL_DIR"
                ;;
        esac
    fi

    printf '\nUsage:\n'
    printf '  %s run <name> <command...>\n' "$BINARY"
    printf '  %s ps [name]\n' "$BINARY"
    printf '  %s kill <name>\n' "$BINARY"
}

main
