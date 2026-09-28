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
	# Frames are read-only once captured, so a value that has not changed since
	# the previous frame is shared with it instead of deep-copied again. One
	# click can drain several enemy turns and capture dozens of frames.
	var previous_frame: Dictionary = frames.back() if not frames.is_empty() else {}
	var snapshot := {}
	for key in battle:
		if key in [CAPTURE_KEY, "battle_animation_events", "stack_animation_states"]: continue
		var value = battle[key]
		if value is Dictionary or value is Array:
			var previous_value = previous_frame.get(key)
			snapshot[key] = previous_value if typeof(previous_value) == typeof(value) and previous_value == value else value.duplicate(true)
		else:
			snapshot[key] = value
	var record := event.duplicate(true)
	# Damage events normally carry their applied damage. Inferring it from the
	# previous frame is a fallback: that frame may already include this hit.
	if not record.has("damage") and not frames.is_empty() and String(record.get("event_id", "")) in ["battle_unit_hit", "battle_unit_death"]:
		for previous in frames.back().get("stacks", []):
			if String(previous.get("battle_id", "")) != String(record.get("battle_id", "")): continue
			for current in snapshot.get("stacks", []):
				if current.get("battle_id") != previous.get("battle_id"): continue
				record["damage"] = maxi(0, int(previous.get("total_health",0))-int(current.get("total_health",0)))
				var hp := maxi(1,int(current.get("unit_hp",1)))
				record["casualties"] = maxi(0, int(ceil(float(previous.get("total_health",0))/hp))-int(ceil(float(current.get("total_health",0))/hp)))
	record["serial"] = 1000000 + frames.size()
	snapshot["playback_event"] = record
	# Use the existing render owners, but expose exactly one event at a time;
	# the loop above skips the two queues replaced here.
	snapshot["battle_animation_events"] = [record]
	snapshot["stack_animation_states"] = {String(record.get("battle_id", "")): record}
	snapshot["active_stack_id"] = String(record.get("source_battle_id", "")) if String(record.get("source_battle_id", "")) != "" else String(record.get("battle_id", ""))
	snapshot["selected_target_id"] = String(record.get("target_battle_id", ""))
	frames.append(snapshot)
