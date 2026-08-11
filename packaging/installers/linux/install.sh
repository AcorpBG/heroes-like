#!/bin/sh
set -eu

MARKER_TEXT=heroes-like-user-local-install-v1
EXPECTED_PAYLOADS='heroes-like.x86_64
heroes-like.pck
libaurelion_map_persistence.linux.template_release.x86_64.so
README.txt
build-info.json
install.sh
uninstall.sh'

SOURCE_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
INSTALL_DIR=${HEROES_LIKE_INSTALL_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/heroes-like}
BIN_DIR=${HEROES_LIKE_BIN_DIR:-$HOME/.local/bin}
APPLICATIONS_DIR=${HEROES_LIKE_APPLICATIONS_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/applications}
FAIL_PHASE=${HEROES_LIKE_INSTALL_FAIL_PHASE:-}

STAGE_ROOT=
BACKUP_ROOT=
LAUNCHER_STAGE=
DESKTOP_STAGE=
TRANSACTION_ACTIVE=0
TRANSACTION_COMPLETE=0
NEW_PROGRAM_LIVE=0
NEW_LAUNCHER_LIVE=0
NEW_DESKTOP_LIVE=0

fail() {
	echo "heroes-like installer: $*" >&2
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

sha256_file() {
	if command -v sha256sum >/dev/null 2>&1; then
		sha256sum "$1" | awk '{print $1}'
	elif command -v shasum >/dev/null 2>&1; then
		shasum -a 256 "$1" | awk '{print $1}'
	else
		fail "sha256sum or shasum is required"
	fi
}

parse_manifest() {
	manifest=$1
	rows=$2
	[ -f "$manifest" ] && [ ! -L "$manifest" ] || fail "release manifest is missing or unsafe: $manifest"
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
		/^  "files": \[$/ {
			if (in_files || closed) failed = 1
			in_files = 1
			next
		}
		in_files && /^    \{$/ {
			if (in_row) failed = 1
			in_row = 1; field = 0; path = ""; hash = ""; size = ""
			next
		}
		in_row && field == 0 && /^      "path": "[^"]+",$/ {
			path = $0; sub(/^      "path": "/, "", path); sub(/",$/, "", path); field = 1
			next
		}
		in_row && field == 1 && /^      "sha256": "[0-9a-f]+",$/ {
			hash = $0; sub(/^      "sha256": "/, "", hash); sub(/",$/, "", hash); field = 2
			next
		}
		in_row && field == 2 && /^      "size_bytes": [0-9]+$/ {
			size = $0; sub(/^      "size_bytes": /, "", size); field = 3
			next
		}
		in_row && /^    \}[,]?$/ {
			if (field != 3) failed = 1
			print path "|" size "|" hash
			in_row = 0
			next
		}
		in_files && !in_row && /^  \],$/ { in_files = 0; closed = 1; next }
		END { if (failed || in_files || in_row || !closed) exit 2 }
	' "$manifest" > "$rows" || fail "release manifest file rows are malformed"
}

validate_rows() {
	rows=$1
	mode=$2
	count=0
	total_size=0
	seen=''
	while IFS='|' read -r name size digest; do
		[ -n "$name" ] || fail "release manifest contains an empty path"
		case "$name" in
			.|..|*/*|*\\*|*[!A-Za-z0-9._-]*) fail "release manifest contains unsafe path: $name" ;;
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
		case "$digest" in
			*[!0-9a-f]*) fail "release manifest has invalid SHA-256 for $name" ;;
		esac
		case "
$seen
" in
			*"
$name
"*) fail "release manifest repeats payload path: $name" ;;
		esac
		seen=${seen}${seen:+
}$name
		count=$((count + 1))
		[ "$count" -le 64 ] || fail "release manifest exceeds the 64-row bound"
		if [ "$mode" = incoming ]; then
			case "
$EXPECTED_PAYLOADS
" in
				*"
$name
"*) ;;
				*) fail "release manifest contains unexpected payload: $name" ;;
			esac
		fi
	done < "$rows"
	[ "$count" -gt 0 ] || fail "release manifest contains no payload rows"
	if [ "$mode" = incoming ]; then
		expected_count=$(printf '%s\n' "$EXPECTED_PAYLOADS" | wc -l | tr -d '[:space:]')
		[ "$count" -eq "$expected_count" ] || fail "release manifest payload membership is incomplete"
	fi
}

verify_manifest_payload() {
	root=$1
	rows=$2
	while IFS='|' read -r name expected_size expected_digest; do
		path=$root/$name
		[ -f "$path" ] && [ ! -L "$path" ] || fail "manifest-owned payload is missing or unsafe: $name"
		actual_size=$(wc -c < "$path" | tr -d '[:space:]')
		[ "$actual_size" = "$expected_size" ] || fail "payload size mismatch: $name"
		actual_digest=$(sha256_file "$path")
		[ "$actual_digest" = "$expected_digest" ] || fail "payload SHA-256 mismatch: $name"
	done < "$rows"
}

row_owns_name() {
	requested_name=$1
	while IFS='|' read -r owned_name _owned_size _owned_digest; do
		[ "$owned_name" = "$requested_name" ] && return 0
	done < "$2"
	return 1
}

validate_owned_entries() {
	root=$1
	rows=$2
	for path in "$root"/* "$root"/.[!.]* "$root"/..?*; do
		[ -e "$path" ] || [ -L "$path" ] || continue
		name=${path##*/}
		case "$name" in
			.heroes-like-install|release-manifest.json) ;;
			*) row_owns_name "$name" "$rows" || fail "owned install root contains unexpected entry: $name" ;;
		esac
		[ ! -L "$path" ] || fail "owned install root contains a symbolic link: $name"
		[ ! -d "$path" ] || fail "owned install root contains an unexpected directory: $name"
	done
}

write_launcher() {
	destination=$1
	cat > "$destination" <<EOF
#!/bin/sh
exec "$INSTALL_DIR/heroes-like.x86_64" "\$@"
EOF
	chmod 0755 "$destination"
}

write_desktop() {
	destination=$1
	cat > "$destination" <<EOF
[Desktop Entry]
Type=Application
Name=Aurelion Reach
Comment=Turn-based fantasy strategy
Exec=$BIN_DIR/heroes-like
Terminal=false
Categories=Game;StrategyGame;
EOF
	chmod 0644 "$destination"
}

cleanup() {
	status=$1
	trap - 0 HUP INT TERM
	if [ "$TRANSACTION_ACTIVE" -eq 1 ] && [ "$TRANSACTION_COMPLETE" -eq 0 ]; then
		if [ -n "$BACKUP_ROOT" ] && [ -d "$BACKUP_ROOT/program" ]; then
			rm -rf -- "$INSTALL_DIR"
			mv "$BACKUP_ROOT/program" "$INSTALL_DIR" || status=1
		elif [ "$NEW_PROGRAM_LIVE" -eq 1 ]; then
			rm -rf -- "$INSTALL_DIR"
		fi
		if [ -n "$BACKUP_ROOT" ] && [ -f "$BACKUP_ROOT/launcher" ]; then
			rm -f -- "$BIN_DIR/heroes-like"
			mv "$BACKUP_ROOT/launcher" "$BIN_DIR/heroes-like" || status=1
		elif [ "$NEW_LAUNCHER_LIVE" -eq 1 ]; then
			rm -f -- "$BIN_DIR/heroes-like"
		fi
		if [ -n "$BACKUP_ROOT" ] && [ -f "$BACKUP_ROOT/desktop" ]; then
			rm -f -- "$APPLICATIONS_DIR/heroes-like.desktop"
			mv "$BACKUP_ROOT/desktop" "$APPLICATIONS_DIR/heroes-like.desktop" || status=1
		elif [ "$NEW_DESKTOP_LIVE" -eq 1 ]; then
			rm -f -- "$APPLICATIONS_DIR/heroes-like.desktop"
		fi
	fi
	[ -z "$LAUNCHER_STAGE" ] || rm -f -- "$LAUNCHER_STAGE"
	[ -z "$DESKTOP_STAGE" ] || rm -f -- "$DESKTOP_STAGE"
	[ -z "$STAGE_ROOT" ] || rm -rf -- "$STAGE_ROOT"
	[ -z "$BACKUP_ROOT" ] || rm -rf -- "$BACKUP_ROOT"
	exit "$status"
}

trap 'cleanup $?' 0
trap 'exit 1' HUP INT TERM

validate_target_path "install directory" "$INSTALL_DIR"
validate_target_path "launcher directory" "$BIN_DIR"
validate_target_path "applications directory" "$APPLICATIONS_DIR"
case "$FAIL_PHASE" in
	''|precommit|after_backup) ;;
	*) fail "unknown HEROES_LIKE_INSTALL_FAIL_PHASE: $FAIL_PHASE" ;;
esac
[ ! -L "$INSTALL_DIR" ] || fail "install directory must not be a symbolic link"

INSTALL_PARENT=${INSTALL_DIR%/*}
INSTALL_NAME=${INSTALL_DIR##*/}
[ -n "$INSTALL_PARENT" ] && [ -n "$INSTALL_NAME" ] || fail "install directory has no safe parent or basename"
mkdir -p "$INSTALL_PARENT" "$BIN_DIR" "$APPLICATIONS_DIR"
[ -d "$INSTALL_PARENT" ] && [ -d "$BIN_DIR" ] && [ -d "$APPLICATIONS_DIR" ] || fail "installer targets must be directories"

STAGE_ROOT=$(mktemp -d "$INSTALL_PARENT/.${INSTALL_NAME}.stage.XXXXXX")
mkdir "$STAGE_ROOT/program"
for name in $EXPECTED_PAYLOADS release-manifest.json; do
	[ -f "$SOURCE_DIR/$name" ] && [ ! -L "$SOURCE_DIR/$name" ] || fail "missing or unsafe payload $name"
	cp -p "$SOURCE_DIR/$name" "$STAGE_ROOT/program/$name"
done
chmod 0755 "$STAGE_ROOT/program/heroes-like.x86_64" "$STAGE_ROOT/program/install.sh" "$STAGE_ROOT/program/uninstall.sh"
printf '%s\n' "$MARKER_TEXT" > "$STAGE_ROOT/program/.heroes-like-install"

NEW_ROWS=$STAGE_ROOT/new-manifest.rows
parse_manifest "$STAGE_ROOT/program/release-manifest.json" "$NEW_ROWS"
validate_rows "$NEW_ROWS" incoming
verify_manifest_payload "$STAGE_ROOT/program" "$NEW_ROWS"

OLD_OWNED=0
OLD_ROWS=$STAGE_ROOT/old-manifest.rows
if [ -e "$INSTALL_DIR" ]; then
	[ -d "$INSTALL_DIR" ] || fail "install path exists and is not a directory"
	if [ -f "$INSTALL_DIR/.heroes-like-install" ]; then
		[ ! -L "$INSTALL_DIR/.heroes-like-install" ] || fail "install ownership marker is unsafe"
		[ "$(cat "$INSTALL_DIR/.heroes-like-install")" = "$MARKER_TEXT" ] || fail "install ownership marker is invalid"
		parse_manifest "$INSTALL_DIR/release-manifest.json" "$OLD_ROWS"
		validate_rows "$OLD_ROWS" prior
		validate_owned_entries "$INSTALL_DIR" "$OLD_ROWS"
		verify_manifest_payload "$INSTALL_DIR" "$OLD_ROWS"
		OLD_OWNED=1
	elif [ -n "$(LC_ALL=C ls -A "$INSTALL_DIR")" ]; then
		fail "refusing nonempty install root without a valid ownership marker"
	fi
fi

LAUNCHER_STAGE=$(mktemp "$BIN_DIR/.heroes-like.launcher.XXXXXX")
DESKTOP_STAGE=$(mktemp "$APPLICATIONS_DIR/.heroes-like.desktop.XXXXXX")
write_launcher "$LAUNCHER_STAGE"
write_desktop "$DESKTOP_STAGE"

for pair in "$BIN_DIR/heroes-like|$LAUNCHER_STAGE|launcher" "$APPLICATIONS_DIR/heroes-like.desktop|$DESKTOP_STAGE|desktop entry"; do
	live=${pair%%|*}
	rest=${pair#*|}
	staged=${rest%%|*}
	label=${rest#*|}
	if [ -e "$live" ] || [ -L "$live" ]; then
		[ "$OLD_OWNED" -eq 1 ] || fail "refusing to overwrite unowned $label: $live"
		[ -f "$live" ] && [ ! -L "$live" ] && cmp -s "$live" "$staged" || fail "owned $label has unexpected content: $live"
	fi
done

if [ "$FAIL_PHASE" = precommit ]; then
	fail "injected failure at precommit"
fi

BACKUP_ROOT=$(mktemp -d "$INSTALL_PARENT/.${INSTALL_NAME}.backup.XXXXXX")
TRANSACTION_ACTIVE=1
if [ -d "$INSTALL_DIR" ]; then
	mv "$INSTALL_DIR" "$BACKUP_ROOT/program"
fi
if [ -f "$BIN_DIR/heroes-like" ]; then
	cp -p "$BIN_DIR/heroes-like" "$BACKUP_ROOT/launcher.tmp"
	mv "$BACKUP_ROOT/launcher.tmp" "$BACKUP_ROOT/launcher"
fi
if [ -f "$APPLICATIONS_DIR/heroes-like.desktop" ]; then
	cp -p "$APPLICATIONS_DIR/heroes-like.desktop" "$BACKUP_ROOT/desktop.tmp"
	mv "$BACKUP_ROOT/desktop.tmp" "$BACKUP_ROOT/desktop"
fi

if [ "$FAIL_PHASE" = after_backup ]; then
	fail "injected failure after backup"
fi

NEW_PROGRAM_LIVE=1
mv "$STAGE_ROOT/program" "$INSTALL_DIR"
NEW_LAUNCHER_LIVE=1
mv "$LAUNCHER_STAGE" "$BIN_DIR/heroes-like"
LAUNCHER_STAGE=
NEW_DESKTOP_LIVE=1
mv "$DESKTOP_STAGE" "$APPLICATIONS_DIR/heroes-like.desktop"
DESKTOP_STAGE=
TRANSACTION_COMPLETE=1

echo "heroes-like installed in $INSTALL_DIR"
echo "Launch with $BIN_DIR/heroes-like"
