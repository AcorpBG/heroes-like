#!/usr/bin/env bash
# Run one headless AI-vs-AI match in an isolated Godot user profile.
#
# Usage: run_match.sh <out_dir> <run_id> <players> <size_class> <factions> [max_days] [guards] [water] [levels] [seed]
#   out_dir     scratch folder for <run_id>.json/.log/.done and the profile
#   players     number of computer players (2-8)
#   size_class  homm3_small | homm3_medium | homm3_large | homm3_extra_large
#   factions    comma-separated faction ids, one per seat, or "random"
#   max_days    day cap (default 320)
#   guards      weak | normal | strong (default normal, as a new game)
#   water       land | normal_water | islands (default land, as a new game)
#   levels      1 | 2 (2 adds the underground level; default 1, as a new game)
#   seed        match seed, e.g. ai-match-1520175333 (default random); the same
#               seed on the same commit replays the same match
#
# Writes <run_id>.json (match record), <run_id>.log and, when finished,
# <run_id>.done holding "exit=<code>". Never run two matches with the same seed
# at once: both write the same generated map package under res://maps.
# Batches go through tools/ai_match_batch.py; this script is for one match.
# GODOT_BIN overrides the Godot binary.
set -u
OUT="$1"; RUN="$2"; PLAYERS="$3"; SIZE="$4"; FACTIONS="$5"; MAX_DAYS="${6:-320}"; GUARDS="${7:-normal}"; WATER="${8:-land}"; LEVELS="${9:-1}"; SEED="${10:-random}"
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
export HEROES_AI_MATCH_SEED="$SEED" HEROES_AI_MATCH_PLAYERS="$PLAYERS" HEROES_AI_MATCH_SIZE="$SIZE"
export HEROES_AI_MATCH_MAX_DAYS="$MAX_DAYS" HEROES_AI_MATCH_OUT="$OUT/$RUN.json" HEROES_AI_MATCH_GUARDS="$GUARDS"
export HEROES_AI_MATCH_WATER="$WATER" HEROES_AI_MATCH_LEVELS="$LEVELS"
if [ "$FACTIONS" != "random" ]; then
	export HEROES_AI_MATCH_FACTIONS="$FACTIONS"
fi
timeout 14400 "$GODOT_BIN" --headless --path "$REPO" res://tests/ai_versus_ai_match_report.tscn > "$OUT/$RUN.log" 2>&1
echo "exit=$?" > "$OUT/$RUN.done"
