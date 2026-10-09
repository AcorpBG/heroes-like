#!/usr/bin/env bash
# Run one headless AI-vs-AI match in an isolated Godot user profile.
#
# Usage: run_match.sh <out_dir> <run_id> <players> <size_class> <factions> [max_days]
#   out_dir     scratch folder for <run_id>.json/.log/.done and the profile
#   players     number of computer players (2-8)
#   size_class  homm3_small | homm3_medium | homm3_large | homm3_extra_large
#   factions    comma-separated faction ids, one per seat, or "random"
#   max_days    day cap (default 160)
#
# Writes <run_id>.json (match record), <run_id>.log and, when finished,
# <run_id>.done holding "exit=<code>". The map seed is drawn at random.
# GODOT_BIN overrides the Godot binary.
set -u
OUT="$1"; RUN="$2"; PLAYERS="$3"; SIZE="$4"; FACTIONS="$5"; MAX_DAYS="${6:-160}"
REPO="$(cd "$(dirname "$0")/../../../.." && pwd)"
if [ -z "${GODOT_BIN:-}" ]; then
	if [ -x /d/Games/godot/Godot_v4.6.2-stable_win64_console.exe ]; then
		GODOT_BIN=/d/Games/godot/Godot_v4.6.2-stable_win64_console.exe
	else
		GODOT_BIN=godot
	fi
fi
# Godot and the profile variables need native paths (C:/... on Windows).
if command -v cygpath >/dev/null 2>&1; then
	OUT="$(cygpath -m "$OUT")"; REPO="$(cygpath -m "$REPO")"
fi
mkdir -p "$OUT/profile_$RUN"
rm -f "$OUT/$RUN.done"
# Never touch the owner's real game profile: APPDATA on Windows,
# XDG_DATA_HOME on Linux.
export APPDATA="$OUT/profile_$RUN" XDG_DATA_HOME="$OUT/profile_$RUN"
export HEROES_AI_MATCH_SEED=random HEROES_AI_MATCH_PLAYERS="$PLAYERS" HEROES_AI_MATCH_SIZE="$SIZE"
export HEROES_AI_MATCH_MAX_DAYS="$MAX_DAYS" HEROES_AI_MATCH_OUT="$OUT/$RUN.json"
if [ "$FACTIONS" != "random" ]; then
	export HEROES_AI_MATCH_FACTIONS="$FACTIONS"
fi
timeout 3000 "$GODOT_BIN" --headless --path "$REPO" res://tests/ai_versus_ai_match_report.tscn > "$OUT/$RUN.log" 2>&1
echo "exit=$?" > "$OUT/$RUN.done"
