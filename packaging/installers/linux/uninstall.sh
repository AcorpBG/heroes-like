#!/bin/sh
set -eu

MARKER_TEXT=heroes-like-user-local-install-v1
INSTALL_DIR=${HEROES_LIKE_INSTALL_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/heroes-like}
BIN_DIR=${HEROES_LIKE_BIN_DIR:-$HOME/.local/bin}
APPLICATIONS_DIR=${HEROES_LIKE_APPLICATIONS_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/applications}
TEMP_ROOT=

fail() {
	echo "heroes-like uninstaller: $*" >&2
	exit 1
}

validate_target_path() {
	label=$1
	value=$2
	case "$value" in
		/*) ;;
		*) fail "$label must be an absolute path" ;;
	esac
	case "$value/" in
		"//"|*"//"*|*"/./"*|*"/../"*) fail "refusing unsafe $label" ;;
	esac
	case "$value" in
		*'
'*) fail "refusing newline in $label" ;;
	esac
}

parse_manifest() {
	manifest=$1
	rows=$2
	[ -f "$manifest" ] && [ ! -L "$manifest" ] || fail "release manifest is missing or unsafe"
	manifest_size=$(wc -c < "$manifest" | tr -d '[:space:]')
	case "$manifest_size" in
		''|*[!0-9]*) fail "release manifest size is invalid" ;;
	esac
	[ "$manifest_size" -gt 0 ] && [ "$manifest_size" -le 65536 ] || fail "release manifest exceeds the 64 KiB bound"
	[ "$(grep -c '^  "schema_id": "heroes_like_platform_release_manifest_v2",$' "$manifest" || true)" -eq 1 ] || fail "release manifest schema is invalid"
	[ "$(grep -c '^  "product_id": "heroes-like",$' "$manifest" || true)" -eq 1 ] || fail "release manifest product is invalid"
	[ "$(grep -c '^  "platform": "linux-x86_64",$' "$manifest" || true)" -eq 1 ] || fail "release manifest platform is invalid"
	awk '
		BEGIN { in_files = 0; in_row = 0; closed = 0; failed = 0 }
		/^  "files": \[$/ { if (in_files || closed) failed = 1; in_files = 1; next }
		in_files && /^    \{$/ { if (in_row) failed = 1; in_row = 1; field = 0; path = ""; hash = ""; size = ""; next }
		in_row && field == 0 && /^      "path": "[^"]+",$/ { path = $0; sub(/^      "path": "/, "", path); sub(/",$/, "", path); field = 1; next }
		in_row && field == 1 && /^      "sha256": "[0-9a-f]+",$/ { hash = $0; sub(/^      "sha256": "/, "", hash); sub(/",$/, "", hash); field = 2; next }
		in_row && field == 2 && /^      "size_bytes": [0-9]+$/ { size = $0; sub(/^      "size_bytes": /, "", size); field = 3; next }
		in_row && /^    \}[,]?$/ { if (field != 3) failed = 1; print path "|" size "|" hash; in_row = 0; next }
		in_files && !in_row && /^  \],$/ { in_files = 0; closed = 1; next }
		END { if (failed || in_files || in_row || !closed) exit 2 }
	' "$manifest" > "$rows" || fail "release manifest file rows are malformed"
}

validate_rows() {
	rows=$1
	count=0
	total_size=0
	seen=''
	while IFS='|' read -r name size digest; do
		case "$name" in
			''|.|..|*/*|*\\*|*[!A-Za-z0-9._-]*) fail "release manifest contains unsafe path: $name" ;;
		esac
		case "$name" in
			.heroes-like-install|release-manifest.json) fail "release manifest contains reserved path: $name" ;;
		esac
		case "$size" in
			''|*[!0-9]*) fail "release manifest has invalid size for $name" ;;
		esac
		[ "$size" -le 2147483648 ] || fail "release manifest payload exceeds the 2 GiB per-file bound: $name"
		total_size=$((total_size + size))
		[ "$total_size" -le 4294967296 ] || fail "release manifest exceeds the 4 GiB payload bound"
		[ "${#digest}" -eq 64 ] || fail "release manifest has invalid SHA-256 for $name"
		case "$digest" in *[!0-9a-f]*) fail "release manifest has invalid SHA-256 for $name" ;; esac
		case "
$seen
" in *"
$name
"*) fail "release manifest repeats payload path: $name" ;; esac
		seen=${seen}${seen:+
}$name
		count=$((count + 1))
		[ "$count" -le 64 ] || fail "release manifest exceeds the 64-row bound"
	done < "$rows"
	[ "$count" -gt 0 ] || fail "release manifest contains no payload rows"
}

row_owns_name() {
	requested_name=$1
	while IFS='|' read -r owned_name _owned_size _owned_digest; do
		[ "$owned_name" = "$requested_name" ] && return 0
	done < "$2"
	return 1
}

write_expected_launcher() {
	cat > "$1" <<EOF
#!/bin/sh
exec "$INSTALL_DIR/heroes-like.x86_64" "\$@"
EOF
}

write_expected_desktop() {
	cat > "$1" <<EOF
[Desktop Entry]
Type=Application
Name=Heroes Like
Comment=Turn-based fantasy strategy
Exec=$BIN_DIR/heroes-like
Terminal=false
Categories=Game;StrategyGame;
EOF
}

cleanup() {
	status=$?
	trap - 0 HUP INT TERM
	# Temporary scratch cleanup is bounded; the live install is never removed with rm -rf.
	[ -z "$TEMP_ROOT" ] || rm -rf -- "$TEMP_ROOT"
	exit "$status"
}
trap cleanup 0
trap 'exit 1' HUP INT TERM

validate_target_path "install directory" "$INSTALL_DIR"
validate_target_path "launcher directory" "$BIN_DIR"
validate_target_path "applications directory" "$APPLICATIONS_DIR"
[ -d "$INSTALL_DIR" ] && [ ! -L "$INSTALL_DIR" ] || fail "install directory is missing or unsafe"
[ -f "$INSTALL_DIR/.heroes-like-install" ] && [ ! -L "$INSTALL_DIR/.heroes-like-install" ] || fail "install ownership marker is missing or unsafe"
[ "$(cat "$INSTALL_DIR/.heroes-like-install")" = "$MARKER_TEXT" ] || fail "install ownership marker is invalid"

TEMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/heroes-like-uninstall.XXXXXX")
ROWS=$TEMP_ROOT/manifest.rows
parse_manifest "$INSTALL_DIR/release-manifest.json" "$ROWS"
validate_rows "$ROWS"

for path in "$INSTALL_DIR"/* "$INSTALL_DIR"/.[!.]* "$INSTALL_DIR"/..?*; do
	[ -e "$path" ] || [ -L "$path" ] || continue
	name=${path##*/}
	case "$name" in
		.heroes-like-install|release-manifest.json) ;;
		*) row_owns_name "$name" "$ROWS" || fail "refusing unexpected unowned install entry: $name" ;;
	esac
	[ ! -L "$path" ] || fail "refusing symbolic link in install root: $name"
	[ ! -d "$path" ] || fail "refusing unexpected directory in install root: $name"
done

EXPECTED_LAUNCHER=$TEMP_ROOT/launcher
EXPECTED_DESKTOP=$TEMP_ROOT/desktop
write_expected_launcher "$EXPECTED_LAUNCHER"
write_expected_desktop "$EXPECTED_DESKTOP"
if [ -e "$BIN_DIR/heroes-like" ] || [ -L "$BIN_DIR/heroes-like" ]; then
	[ -f "$BIN_DIR/heroes-like" ] && [ ! -L "$BIN_DIR/heroes-like" ] && cmp -s "$BIN_DIR/heroes-like" "$EXPECTED_LAUNCHER" || fail "refusing unexpected launcher content"
fi
if [ -e "$APPLICATIONS_DIR/heroes-like.desktop" ] || [ -L "$APPLICATIONS_DIR/heroes-like.desktop" ]; then
	[ -f "$APPLICATIONS_DIR/heroes-like.desktop" ] && [ ! -L "$APPLICATIONS_DIR/heroes-like.desktop" ] && cmp -s "$APPLICATIONS_DIR/heroes-like.desktop" "$EXPECTED_DESKTOP" || fail "refusing unexpected desktop entry content"
fi

while IFS='|' read -r name _size _digest; do
	rm -f -- "$INSTALL_DIR/$name"
done < "$ROWS"
rm -f -- "$INSTALL_DIR/release-manifest.json" "$INSTALL_DIR/.heroes-like-install"
rmdir "$INSTALL_DIR" || fail "install root was not empty after removing manifest-owned files"
rm -f -- "$BIN_DIR/heroes-like" "$APPLICATIONS_DIR/heroes-like.desktop"

echo "heroes-like program files removed"
echo "Saved games, settings, generated maps, and runtime logs were preserved."
