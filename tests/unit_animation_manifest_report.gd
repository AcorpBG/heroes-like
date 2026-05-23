extends Node

const OUTPUT_DIR := "res://.artifacts/unit_animation_manifest_report"
const UNIT_ANIMATION_MANIFEST := "res://content/unit_animation_manifest.json"
const ANIMATION_EVENT_CUES := "res://content/animation_event_cues.json"
const EXPECTED_SCHEMA_ID := "unit_animation_manifest_v1"
const EXPECTED_GENERATOR := "deterministic_unit_animation_assets_v1"
const EXPECTED_FRAME_SIZE := Vector2i(64, 64)
const EXPECTED_FRAMES_PER_STATE := 4
const REQUIRED_STATE_FAMILIES := [
	"idle",
	"ready",
	"move",
	"attack",
	"hit",
	"death",
	"cast",
	"status",
	"defend",
	"retreat",
]

var _errors: Array[String] = []
var _report := {
	"ok": false,
	"unit_count": 0,
	"manifest_count": 0,
	"state_count": 0,
	"sprite_sheet_loaded_count": 0,
	"unique_sprite_sheet_hash_count": 0,
	"state_family_counts": {},
	"units": [],
	"errors": [],
}

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	_ensure_output_dir()
	var units := _items(ContentService.load_json(ContentService.UNITS_PATH))
	var manifest := ContentService.load_json(UNIT_ANIMATION_MANIFEST)
	var records := _items(manifest)
	var states: Array = manifest.get("states", []) if manifest.get("states", []) is Array else []
	var frame_size := Vector2i(int(manifest.get("frame_size", {}).get("width", 0)), int(manifest.get("frame_size", {}).get("height", 0)))
	var frames_per_state := int(manifest.get("frames_per_state", 0))
	var sheet_size := Vector2i(int(manifest.get("sheet_size", {}).get("width", 0)), int(manifest.get("sheet_size", {}).get("height", 0)))
	_report["unit_count"] = units.size()
	_report["manifest_count"] = records.size()
	_report["state_count"] = states.size()
	_validate_manifest_header(manifest, frame_size, frames_per_state, sheet_size, states)
	var states_by_name := _validate_states(states)
	_validate_event_cue_alignment(states)
	var records_by_unit := _index_by_unit_id(records)
	var sheet_hashes := {}
	if records_by_unit.size() != units.size():
		_error("Unit animation manifest count %d does not match authored unit count %d." % [records_by_unit.size(), units.size()])
	for unit in units:
		if not (unit is Dictionary):
			continue
		var unit_id := String(unit.get("id", "")).strip_edges()
		if unit_id == "":
			_error("Unit record is missing id.")
			continue
		if not records_by_unit.has(unit_id):
			_error("Unit animation manifest is missing %s." % unit_id)
			continue
		_validate_unit_record(unit, records_by_unit[unit_id], states_by_name, frame_size, frames_per_state, sheet_size, sheet_hashes)
	_report["unique_sprite_sheet_hash_count"] = sheet_hashes.size()
	_report["ok"] = _errors.is_empty()
	_report["errors"] = _errors.duplicate()
	_write_json("%s/report.json" % OUTPUT_DIR, _report)
	if _errors.is_empty():
		print("UNIT_ANIMATION_MANIFEST_REPORT %s" % JSON.stringify(_summary_payload()))
	get_tree().quit(0 if _errors.is_empty() else 1)

func _validate_manifest_header(manifest: Dictionary, frame_size: Vector2i, frames_per_state: int, sheet_size: Vector2i, states: Array) -> void:
	if String(manifest.get("schema_id", "")) != EXPECTED_SCHEMA_ID:
		_error("Unexpected unit animation manifest schema: %s." % manifest.get("schema_id", ""))
	if String(manifest.get("generator", "")) != EXPECTED_GENERATOR:
		_error("Unexpected unit animation manifest generator: %s." % manifest.get("generator", ""))
	if frame_size != EXPECTED_FRAME_SIZE:
		_error("Unit animation frame size expected %s but got %s." % [EXPECTED_FRAME_SIZE, frame_size])
	if frames_per_state != EXPECTED_FRAMES_PER_STATE:
		_error("Unit animation frames_per_state expected %d but got %d." % [EXPECTED_FRAMES_PER_STATE, frames_per_state])
	var expected_sheet_size := Vector2i(EXPECTED_FRAME_SIZE.x * EXPECTED_FRAMES_PER_STATE, EXPECTED_FRAME_SIZE.y * states.size())
	if sheet_size != expected_sheet_size:
		_error("Unit animation sheet size expected %s but got %s." % [expected_sheet_size, sheet_size])

func _validate_states(states: Array) -> Dictionary:
	var by_name := {}
	var family_counts := {}
	for state in states:
		if not (state is Dictionary):
			_error("Unit animation state is not an object: %s." % state)
			continue
		var state_name := String(state.get("state", "")).strip_edges()
		var family := String(state.get("family", "")).strip_edges()
		var event_id := String(state.get("event_id", "")).strip_edges()
		if state_name == "" or family == "" or event_id == "":
			_error("Unit animation state must define event_id, family, and state: %s." % state)
			continue
		if by_name.has(state_name):
			_error("Unit animation state is duplicated: %s." % state_name)
		by_name[state_name] = state
		family_counts[family] = int(family_counts.get(family, 0)) + 1
	for family in REQUIRED_STATE_FAMILIES:
		if int(family_counts.get(family, 0)) <= 0:
			_error("Unit animation manifest is missing state family %s." % family)
	_report["state_family_counts"] = family_counts
	return by_name

func _validate_event_cue_alignment(states: Array) -> void:
	var cue_catalog := ContentService.load_json(ANIMATION_EVENT_CUES)
	var entries: Array = cue_catalog.get("entries", []) if cue_catalog.get("entries", []) is Array else []
	var entries_by_event := {}
	for entry in entries:
		if entry is Dictionary:
			var event_id := String(entry.get("event_id", "")).strip_edges()
			if event_id != "":
				entries_by_event[event_id] = entry
	for state in states:
		if not (state is Dictionary):
			continue
		var event_id := String(state.get("event_id", "")).strip_edges()
		if not entries_by_event.has(event_id):
			_error("Unit animation state references missing cue event %s." % event_id)
			continue
		var cue: Dictionary = entries_by_event[event_id]
		var expected_family := String(cue.get("animation_state_family", "")).strip_edges()
		var expected_state := String(cue.get("animation_state", "")).strip_edges()
		if String(state.get("family", "")).strip_edges() != expected_family:
			_error("Unit animation state %s family does not match cue catalog family %s." % [event_id, expected_family])
		if String(state.get("state", "")).strip_edges() != expected_state:
			_error("Unit animation state %s name does not match cue catalog state %s." % [event_id, expected_state])

func _validate_unit_record(
	unit: Dictionary,
	record: Dictionary,
	states_by_name: Dictionary,
	frame_size: Vector2i,
	frames_per_state: int,
	sheet_size: Vector2i,
	sheet_hashes: Dictionary
) -> void:
	var unit_id := String(unit.get("id", "")).strip_edges()
	var path := String(record.get("sprite_sheet", "")).strip_edges()
	if String(record.get("name", "")) != String(unit.get("name", "")):
		_error("Unit animation manifest name mismatch for %s." % unit_id)
	var record_states: Array = record.get("states", []) if record.get("states", []) is Array else []
	if record_states.size() != states_by_name.size():
		_error("Unit %s animation state list size %d does not match manifest state count %d." % [unit_id, record_states.size(), states_by_name.size()])
	for state_name in states_by_name.keys():
		if state_name not in record_states:
			_error("Unit %s animation record is missing state %s." % [unit_id, state_name])
	var image: Image = _load_image(path)
	var loaded := image != null
	var hash := FileAccess.get_md5(path) if FileAccess.file_exists(path) else ""
	if not loaded:
		_error("Unit %s animation sprite sheet failed to load: %s." % [unit_id, path])
		return
	_report["sprite_sheet_loaded_count"] = int(_report["sprite_sheet_loaded_count"]) + 1
	if image.get_size() != sheet_size:
		_error("Unit %s animation sheet expected %s but got %s." % [unit_id, sheet_size, image.get_size()])
	if hash == "":
		_error("Unit %s animation sheet has no readable hash: %s." % [unit_id, path])
	elif sheet_hashes.has(hash):
		_error("Unit %s animation sheet duplicates PNG bytes with %s." % [unit_id, sheet_hashes[hash]])
	else:
		sheet_hashes[hash] = unit_id
	var state_summaries := []
	for row in range(states_by_name.size()):
		var state_name := String(record_states[row]) if row < record_states.size() else ""
		var frame_signatures := {}
		var frame_visual_pass_count := 0
		for frame_index in range(frames_per_state):
			var frame_rect := Rect2i(Vector2i(frame_index * frame_size.x, row * frame_size.y), frame_size)
			var frame: Image = image.get_region(frame_rect)
			var metrics := _visual_metrics(frame)
			if _frame_metrics_pass(metrics):
				frame_visual_pass_count += 1
			else:
				_error("Unit %s state %s frame %d failed animation visual gate: %s." % [unit_id, state_name, frame_index, JSON.stringify(metrics)])
			frame_signatures[_frame_signature(frame)] = true
		if frame_signatures.size() < 2:
			_error("Unit %s state %s does not animate across frames." % [unit_id, state_name])
		state_summaries.append({
			"state": state_name,
			"frame_visual_pass_count": frame_visual_pass_count,
			"unique_frame_signature_count": frame_signatures.size(),
		})
	_report["units"].append({
		"unit_id": unit_id,
		"name": String(unit.get("name", "")),
		"sprite_sheet": path,
		"loaded": loaded,
		"hash": hash,
		"states": state_summaries,
	})

func _visual_metrics(image: Image) -> Dictionary:
	var visible_pixels := 0
	var quantized_colors := {}
	var min_luma := 255
	var max_luma := 0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var color: Color = image.get_pixel(x, y)
			if color.a <= 0.03:
				continue
			visible_pixels += 1
			var luma := int(round((0.2126 * color.r + 0.7152 * color.g + 0.0722 * color.b) * 255.0))
			min_luma = mini(min_luma, luma)
			max_luma = maxi(max_luma, luma)
			quantized_colors["%d:%d:%d" % [int(color.r * 15.0), int(color.g * 15.0), int(color.b * 15.0)]] = true
	return {
		"alpha_coverage": float(visible_pixels) / float(maxi(image.get_width() * image.get_height(), 1)),
		"visible_pixel_count": visible_pixels,
		"luminance_range": max_luma - min_luma if visible_pixels > 0 else 0,
		"quantized_color_count": quantized_colors.size(),
	}

func _frame_metrics_pass(metrics: Dictionary) -> bool:
	return (
		float(metrics.get("alpha_coverage", 0.0)) >= 0.08
		and int(metrics.get("visible_pixel_count", 0)) >= 240
		and int(metrics.get("luminance_range", 0)) >= 12
		and int(metrics.get("quantized_color_count", 0)) >= 5
	)

func _frame_signature(image: Image) -> String:
	var sample := image.duplicate()
	sample.resize(8, 8, Image.INTERPOLATE_LANCZOS)
	var bits := PackedStringArray()
	var total := 0.0
	var luminance_values := []
	for y in range(8):
		for x in range(8):
			var color: Color = sample.get_pixel(x, y)
			var luminance: float = 255.0 if color.a <= 0.03 else (0.2126 * color.r + 0.7152 * color.g + 0.0722 * color.b) * 255.0
			luminance_values.append(luminance)
			total += luminance
	var average := total / 64.0
	for luminance in luminance_values:
		bits.append("1" if float(luminance) >= average else "0")
	return "".join(bits)

func _load_image(path: String):
	if path == "" or not FileAccess.file_exists(path):
		return null
	var image := Image.new()
	if image.load(ProjectSettings.globalize_path(path)) != OK:
		return null
	image.convert(Image.FORMAT_RGBA8)
	return image

func _index_by_unit_id(records: Array) -> Dictionary:
	var indexed := {}
	for record in records:
		if record is Dictionary:
			var unit_id := String(record.get("unit_id", record.get("id", ""))).strip_edges()
			if unit_id != "":
				indexed[unit_id] = record
	return indexed

func _items(raw: Dictionary) -> Array:
	var items = raw.get("items", [])
	return items if items is Array else []

func _summary_payload() -> Dictionary:
	return {
		"ok": true,
		"unit_count": _report["unit_count"],
		"manifest_count": _report["manifest_count"],
		"state_count": _report["state_count"],
		"sprite_sheet_loaded_count": _report["sprite_sheet_loaded_count"],
		"unique_sprite_sheet_hash_count": _report["unique_sprite_sheet_hash_count"],
		"state_family_counts": _report["state_family_counts"],
	}

func _ensure_output_dir() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))

func _write_json(path: String, payload: Dictionary) -> void:
	var file := FileAccess.open(ProjectSettings.globalize_path(path), FileAccess.WRITE)
	if file == null:
		_error("Failed to write %s." % path)
		return
	file.store_string(JSON.stringify(payload, "\t"))

func _error(message: String) -> void:
	push_error(message)
	_errors.append(message)
