#!/bin/sh
set -eu

INSTALL_DIR=${HEROES_LIKE_INSTALL_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/heroes-like}
BIN_DIR=${HEROES_LIKE_BIN_DIR:-$HOME/.local/bin}
APPLICATIONS_DIR=${HEROES_LIKE_APPLICATIONS_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/applications}

case "$INSTALL_DIR" in
	""|"/")
		echo "heroes-like uninstaller: refusing unsafe install directory" >&2
		exit 1
		;;
esac

if [ ! -f "$INSTALL_DIR/.heroes-like-install" ]; then
	echo "heroes-like uninstaller: install ownership marker is missing" >&2
	exit 1
fi

rm -f "$BIN_DIR/heroes-like" "$APPLICATIONS_DIR/heroes-like.desktop"
rm -rf "$INSTALL_DIR"

echo "heroes-like program files removed"
echo "Saved games, settings, generated maps, and runtime logs were preserved."
