extends RefCounted

const BattleEngine = preload("res://scripts/core/BattleEngine.gd")

# Transient, opt-in render snapshots. Removed synchronously before an action
# returns; never a save field or an input to simulation/RNG.
const CAPTURE_KEY := "_live_action_playback_capture"

static func capture(battle: Dictionary, event: Dictionary) -> void:
	BattleEngine.native_writing(&"BattleActionPlayback.capture", [battle, event])
