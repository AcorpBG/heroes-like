#!/bin/sh
set -eu

SOURCE_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
INSTALL_DIR=${HEROES_LIKE_INSTALL_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/heroes-like}
BIN_DIR=${HEROES_LIKE_BIN_DIR:-$HOME/.local/bin}
APPLICATIONS_DIR=${HEROES_LIKE_APPLICATIONS_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/applications}

for name in heroes-like.x86_64 heroes-like.pck libaurelion_map_persistence.linux.template_release.x86_64.so README.txt build-info.json release-manifest.json uninstall.sh; do
	if [ ! -f "$SOURCE_DIR/$name" ]; then
		echo "heroes-like installer: missing payload $name" >&2
		exit 1
	fi
done

mkdir -p "$INSTALL_DIR" "$BIN_DIR" "$APPLICATIONS_DIR"
for name in heroes-like.x86_64 heroes-like.pck libaurelion_map_persistence.linux.template_release.x86_64.so README.txt build-info.json release-manifest.json install.sh uninstall.sh; do
	cp "$SOURCE_DIR/$name" "$INSTALL_DIR/$name"
done
chmod 0755 "$INSTALL_DIR/heroes-like.x86_64" "$INSTALL_DIR/install.sh" "$INSTALL_DIR/uninstall.sh"
printf '%s\n' 'heroes-like-user-local-install-v1' > "$INSTALL_DIR/.heroes-like-install"

cat > "$BIN_DIR/heroes-like" <<EOF
#!/bin/sh
exec "$INSTALL_DIR/heroes-like.x86_64" "\$@"
EOF
chmod 0755 "$BIN_DIR/heroes-like"

cat > "$APPLICATIONS_DIR/heroes-like.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Heroes Like
Comment=Turn-based fantasy strategy
Exec=$BIN_DIR/heroes-like
Terminal=false
Categories=Game;StrategyGame;
EOF
chmod 0644 "$APPLICATIONS_DIR/heroes-like.desktop"

echo "heroes-like installed in $INSTALL_DIR"
echo "Launch with $BIN_DIR/heroes-like"
