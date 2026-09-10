extends RefCounted

# Transient, opt-in render snapshots. Removed synchronously before an action
# returns; never a save field or an input to simulation/RNG.
const CAPTURE_KEY := "_live_action_playback_capture"

static func begin(battle: Dictionary) -> void:
	battle[CAPTURE_KEY] = []

static func finish(battle: Dictionary, result: Dictionary) -> Dictionary:
	var frames: Array = battle.get(CAPTURE_KEY, [])
	battle.erase(CAPTURE_KEY)
	if bool(result.get("ok", false)):
		result["playback_frames"] = frames
	return result

static func capture(battle: Dictionary, event: Dictionary) -> void:
	if not battle.has(CAPTURE_KEY): return
	var frames: Array = battle[CAPTURE_KEY]
	var snapshot := {}
	for key in battle:
		if key == CAPTURE_KEY: continue
		var value = battle[key]
		snapshot[key] = value.duplicate(true) if value is Dictionary or value is Array else value
	var record := event.duplicate(true)
	if not frames.is_empty() and String(record.get("event_id", "")) in ["battle_unit_hit", "battle_unit_death", "battle_status_applied"]:
		for previous in frames.back().get("stacks", []):
			if String(previous.get("battle_id", "")) != String(record.get("battle_id", "")): continue
			for current in snapshot.get("stacks", []):
				if current.get("battle_id") != previous.get("battle_id"): continue
				record["damage"] = maxi(0, int(previous.get("total_health",0))-int(current.get("total_health",0)))
				var hp := maxi(1,int(current.get("unit_hp",1)))
				record["casualties"] = maxi(0, int(ceil(float(previous.get("total_health",0))/hp))-int(ceil(float(current.get("total_health",0))/hp)))
	record["serial"] = 1000000 + frames.size()
	snapshot["playback_event"] = record
	# Use the existing render owners, but expose exactly one event at a time.
	snapshot["battle_animation_events"] = [record]
	snapshot["stack_animation_states"] = {String(record.get("battle_id", "")): record}
	snapshot["active_stack_id"] = String(record.get("source_battle_id", "")) if String(record.get("source_battle_id", "")) != "" else String(record.get("battle_id", ""))
	snapshot["selected_target_id"] = String(record.get("target_battle_id", ""))
	frames.append(snapshot)
