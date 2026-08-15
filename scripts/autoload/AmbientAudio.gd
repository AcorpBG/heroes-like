class_name HeroesAmbientAudio
extends Node

const SAMPLE_RATE := 22050
const MAX_ACTIVE_PLAYERS := 4
const MAX_RECORDS := 24
const DEFAULT_SEGMENT_DURATION := 0.85
const REPORT_SCHEMA := "overworld_ambient_audio_runtime_v1"
const AMBIENT_SFX_MANIFEST_PATH := "res://content/ambient_sfx_manifest.json"
const EFFECTS_AUDIO_BUS := "Effects"
const TERRAIN_SPECS := {
	"grass": {"frequency": 176.0, "gain": 0.035, "label": "grassland air"},
	"water": {"frequency": 132.0, "gain": 0.032, "label": "river wash"},
	"mire": {"frequency": 118.0, "gain": 0.038, "label": "marsh drone"},
	"dirt": {"frequency": 154.0, "gain": 0.03, "label": "dry road"},
	"rough": {"frequency": 96.0, "gain": 0.034, "label": "stone wind"},
	"sand": {"frequency": 142.0, "gain": 0.028, "label": "sand hush"},
	"snow": {"frequency": 88.0, "gain": 0.026, "label": "snow hush"},
	"lava": {"frequency": 74.0, "gain": 0.04, "label": "heat rumble"},
	"underground": {"frequency": 64.0, "gain": 0.036, "label": "deep hall"},
}
const PRESSURE_SPEC := {"frequency": 214.0, "gain": 0.022, "label": "distant war drums"}
const DAY_SPEC := {"frequency": 248.0, "gain": 0.014, "label": "day pulse"}

var _records: Array[Dictionary] = []
var _active_players: Array[AudioStreamPlayer] = []
var _current_signature := ""
var _current_layers: Array[Dictionary] = []
var _ambient_sfx_manifest: Dictionary = {}
var _ambient_sfx_manifest_loaded := false

func sync_overworld_session(session: Variant, source: String = "overworld") -> Dictionary:
	if session == null:
		stop_overworld_ambient("missing_session")
		return _append_record({
			"schema": REPORT_SCHEMA,
			"cue_id": "overworld_ambient_stopped",
			"source": source,
			"changed": true,
			"played": false,
			"muted": SettingsService.effects_audio_muted(),
			"reason": "missing_session",
			"layer_count": 0,
			"layers": [],
			"audio_bus": EFFECTS_AUDIO_BUS,
			"sfx_manifest_path": AMBIENT_SFX_MANIFEST_PATH,
			"sfx_manifest_loaded": _ambient_sfx_manifest_loaded,
			"active_player_count": _active_players.size(),
			"timestamp_msec": Time.get_ticks_msec(),
		})
	var context := _overworld_context(session)
	var signature := _signature_for_context(context)
	_prune_players()
	if signature == _current_signature and not _active_players.is_empty():
		return {
			"schema": REPORT_SCHEMA,
			"cue_id": "overworld_ambient_mix",
			"source": source,
			"changed": false,
			"signature": signature,
			"scenario_id": String(context.get("scenario_id", "")),
			"day": int(context.get("day", 0)),
			"terrain_id": String(context.get("terrain_id", "")),
			"dominant_terrain_id": String(context.get("dominant_terrain_id", "")),
			"threat_level": String(context.get("threat_level", "")),
			"layer_count": _current_layers.size(),
			"layers": _current_layers.duplicate(true),
			"audio_bus": EFFECTS_AUDIO_BUS,
			"sfx_manifest_path": AMBIENT_SFX_MANIFEST_PATH,
			"sfx_manifest_loaded": _ambient_sfx_manifest_loaded,
			"active_player_count": _active_players.size(),
			"muted": SettingsService.effects_audio_muted(),
			"played": not SettingsService.effects_audio_muted(),
			"timestamp_msec": Time.get_ticks_msec(),
		}
	stop_overworld_ambient("signature_changed")
	_current_signature = signature
	_current_layers = _ambient_layers_for_context(context)
	var muted := SettingsService.effects_audio_muted()
	if not muted:
		_play_layers(_current_layers)
	return _append_record({
		"schema": REPORT_SCHEMA,
		"cue_id": "overworld_ambient_mix",
		"source": source,
		"changed": true,
		"signature": signature,
		"scenario_id": String(context.get("scenario_id", "")),
		"day": int(context.get("day", 0)),
		"terrain_id": String(context.get("terrain_id", "")),
		"dominant_terrain_id": String(context.get("dominant_terrain_id", "")),
		"threat_level": String(context.get("threat_level", "")),
		"layer_count": _current_layers.size(),
		"layers": _current_layers.duplicate(true),
		"audio_bus": EFFECTS_AUDIO_BUS,
		"sfx_manifest_path": AMBIENT_SFX_MANIFEST_PATH,
		"sfx_manifest_loaded": _ambient_sfx_manifest_loaded,
		"active_player_count": _active_players.size(),
		"muted": muted,
		"played": not muted,
		"timestamp_msec": Time.get_ticks_msec(),
	})

func stop_overworld_ambient(reason: String = "manual") -> void:
	for player in _active_players:
		if is_instance_valid(player):
			player.queue_free()
	_active_players.clear()
	_current_signature = ""
	_current_layers.clear()

func validation_reset() -> void:
	stop_overworld_ambient("validation_reset")
	_records.clear()

func validation_records() -> Array:
	return _records.duplicate(true)

func validation_summary() -> Dictionary:
	var cue_counts := {}
	var terrain_counts := {}
	var pressure_layer_count := 0
	for record in _records:
		var cue_id := String(record.get("cue_id", ""))
		cue_counts[cue_id] = int(cue_counts.get(cue_id, 0)) + 1
		var terrain_id := String(record.get("terrain_id", ""))
		if terrain_id != "":
			terrain_counts[terrain_id] = int(terrain_counts.get(terrain_id, 0)) + 1
		for layer in record.get("layers", []):
			if layer is Dictionary and String(layer.get("layer_id", "")) == "pressure":
				pressure_layer_count += 1
	return {
		"schema": REPORT_SCHEMA,
		"record_count": _records.size(),
		"cue_counts": cue_counts,
		"terrain_counts": terrain_counts,
		"pressure_layer_count": pressure_layer_count,
		"active_player_count": _active_players.size(),
		"current_signature": _current_signature,
		"current_layers": _current_layers.duplicate(true),
		"audio_bus": EFFECTS_AUDIO_BUS,
		"max_active_players": MAX_ACTIVE_PLAYERS,
		"sfx_manifest_path": AMBIENT_SFX_MANIFEST_PATH,
		"sfx_manifest_loaded": _ambient_sfx_manifest_loaded,
		"records": validation_records(),
	}

func _overworld_context(session: Variant) -> Dictionary:
	var overworld: Dictionary = session.overworld if session.overworld is Dictionary else {}
	var hero_position: Dictionary = overworld.get("hero_position", {}) if overworld.get("hero_position", {}) is Dictionary else {}
	var x := int(hero_position.get("x", 0))
	var y := int(hero_position.get("y", 0))
	var map_data: Array = overworld.get("map", []) if overworld.get("map", []) is Array else []
	var terrain_id := _terrain_at(map_data, x, y)
	var dominant_terrain_id := _dominant_terrain(map_data)
	var max_pressure := _max_enemy_pressure(overworld.get("enemy_states", []))
	return {
		"scenario_id": String(session.scenario_id),
		"day": int(session.day),
		"x": x,
		"y": y,
		"terrain_id": terrain_id,
		"dominant_terrain_id": dominant_terrain_id,
		"max_enemy_pressure": max_pressure,
		"threat_level": _threat_level(max_pressure),
	}

func _ambient_layers_for_context(context: Dictionary) -> Array[Dictionary]:
	var layers: Array[Dictionary] = []
	var terrain_id := String(context.get("terrain_id", ""))
	var terrain_spec: Dictionary = TERRAIN_SPECS.get(terrain_id, TERRAIN_SPECS.get(String(context.get("dominant_terrain_id", "grass")), TERRAIN_SPECS["grass"]))
	layers.append(_layer_payload("terrain", "overworld_ambient_%s" % terrain_id, terrain_spec, 0.0))
	if int(context.get("max_enemy_pressure", 0)) > 0:
		layers.append(_layer_payload("pressure", "overworld_ambient_pressure", PRESSURE_SPEC, 0.35))
	if int(context.get("day", 1)) > 1:
		layers.append(_layer_payload("day_pulse", "overworld_ambient_day_pulse", DAY_SPEC, 0.65))
	return layers

func _layer_payload(layer_id: String, cue_id: String, spec: Dictionary, phase_offset: float) -> Dictionary:
	var manifest_cue := _ambient_sfx_manifest_cue(cue_id)
	return {
		"layer_id": layer_id,
		"cue_id": cue_id,
		"label": String(spec.get("label", cue_id)),
		"frequency": float(spec.get("frequency", 120.0)),
		"gain": float(spec.get("gain", 0.03)),
		"duration_sec": DEFAULT_SEGMENT_DURATION,
		"phase_offset": phase_offset,
		"audio_bus": EFFECTS_AUDIO_BUS,
		"sfx_manifest_path": AMBIENT_SFX_MANIFEST_PATH,
		"sfx_manifest_loaded": _ambient_sfx_manifest_loaded,
		"asset_path": String(manifest_cue.get("path", "")),
		"role": String(manifest_cue.get("role", "")),
		"playback_source": "pending",
		"stream_length_sec": 0.0,
		"looped": false,
		"loop_mode": -1,
		"loop_begin_sample": 0,
		"loop_end_sample": 0,
		"mix_rate": 0,
		"stereo": false,
		"imported_asset_count": 0,
		"generated_fallback_count": 0,
	}

func _play_layers(layers: Array[Dictionary]) -> void:
	_prune_players()
	var generated_playback_started := false
	for index in range(layers.size()):
		if _active_players.size() >= MAX_ACTIVE_PLAYERS:
			break
		var layer: Dictionary = layers[index]
		if _play_imported_layer(layer):
			layers[index] = layer
			continue
		var stream := AudioStreamGenerator.new()
		stream.mix_rate = SAMPLE_RATE
		stream.buffer_length = maxf(0.08, float(layer.get("duration_sec", DEFAULT_SEGMENT_DURATION)))
		var player := AudioStreamPlayer.new()
		player.bus = SettingsService.effects_audio_bus_name()
		player.stream = stream
		add_child(player)
		player.play()
		var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
		if playback != null:
			_fill_ambient_waveform(playback, layer)
		_active_players.append(player)
		layer["playback_source"] = "generated_waveform"
		layer["generated_fallback_count"] = 1
		layers[index] = layer
		generated_playback_started = true
	var timer := get_tree().create_timer(DEFAULT_SEGMENT_DURATION + 0.08) if get_tree() != null and generated_playback_started else null
	if timer != null:
		timer.timeout.connect(_prune_players)

func _play_imported_layer(layer: Dictionary) -> bool:
	var cue := _ambient_sfx_manifest_cue(String(layer.get("cue_id", "")))
	if cue.is_empty():
		return false
	var path := String(cue.get("path", "")).strip_edges()
	if path == "":
		return false
	var stream: AudioStream = null
	if ResourceLoader.exists(path):
		var resource = load(path)
		if resource is AudioStream:
			stream = resource
	if stream == null and FileAccess.file_exists(path):
		var wav_stream := AudioStreamWAV.load_from_file(path)
		if wav_stream is AudioStream:
			stream = wav_stream
	if stream == null:
		return false
	var playback_stream: AudioStream = stream
	var looped := false
	var loop_mode := -1
	var loop_begin_sample := 0
	var loop_end_sample := 0
	var source_mix_rate := 0
	var source_stereo := false
	if stream is AudioStreamWAV:
		var wav_stream := (stream as AudioStreamWAV).duplicate(true) as AudioStreamWAV
		if wav_stream != null:
			wav_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav_stream.loop_begin = 0
			wav_stream.loop_end = maxi(1, int(round(wav_stream.get_length() * float(wav_stream.mix_rate))))
			playback_stream = wav_stream
			looped = true
			loop_mode = int(wav_stream.loop_mode)
			loop_begin_sample = int(wav_stream.loop_begin)
			loop_end_sample = int(wav_stream.loop_end)
			source_mix_rate = int(wav_stream.mix_rate)
			source_stereo = bool(wav_stream.stereo)
	var player := AudioStreamPlayer.new()
	player.bus = SettingsService.effects_audio_bus_name()
	player.stream = playback_stream
	player.volume_db = float(cue.get("volume_db", -27.0))
	add_child(player)
	_active_players.append(player)
	player.play()
	layer["playback_source"] = "imported_wav"
	layer["asset_path"] = path
	layer["role"] = String(cue.get("role", ""))
	layer["duration_sec"] = maxf(0.01, float(cue.get("duration_msec", 850)) / 1000.0)
	layer["volume_db"] = float(cue.get("volume_db", -27.0))
	layer["stream_length_sec"] = playback_stream.get_length()
	layer["looped"] = looped
	layer["loop_mode"] = loop_mode
	layer["loop_begin_sample"] = loop_begin_sample
	layer["loop_end_sample"] = loop_end_sample
	layer["mix_rate"] = source_mix_rate
	layer["stereo"] = source_stereo
	layer["imported_asset_count"] = 1
	layer["generated_fallback_count"] = 0
	return true

func _fill_ambient_waveform(playback: AudioStreamGeneratorPlayback, layer: Dictionary) -> void:
	var duration := float(layer.get("duration_sec", DEFAULT_SEGMENT_DURATION))
	var frame_count := maxi(1, int(SAMPLE_RATE * duration))
	var frequency := float(layer.get("frequency", 120.0))
	var gain := float(layer.get("gain", 0.03))
	var phase_offset := float(layer.get("phase_offset", 0.0))
	for frame in range(frame_count):
		var t := float(frame) / float(SAMPLE_RATE)
		var fade_in := minf(1.0, float(frame) / maxf(1.0, float(frame_count) * 0.18))
		var fade_out := minf(1.0, float(frame_count - frame) / maxf(1.0, float(frame_count) * 0.22))
		var envelope := minf(fade_in, fade_out)
		var modulation := 0.65 + (0.35 * sin(TAU * (frequency * 0.125) * (t + phase_offset)))
		var sample := sin(TAU * frequency * (t + phase_offset)) * gain * envelope * modulation
		playback.push_frame(Vector2(sample, sample))

func _append_record(record: Dictionary) -> Dictionary:
	_records.append(record.duplicate(true))
	while _records.size() > MAX_RECORDS:
		_records.pop_front()
	return record

func _terrain_at(map_data: Array, x: int, y: int) -> String:
	if y < 0 or y >= map_data.size():
		return "grass"
	var row = map_data[y]
	if row is Array and x >= 0 and x < row.size():
		return _normalize_terrain_id(row[x])
	return "grass"

func _dominant_terrain(map_data: Array) -> String:
	var counts := {}
	for row in map_data:
		if not (row is Array):
			continue
		for cell in row:
			var terrain_id := _normalize_terrain_id(cell)
			counts[terrain_id] = int(counts.get(terrain_id, 0)) + 1
	var best_id := "grass"
	var best_count := -1
	for terrain_id_value in counts.keys():
		var terrain_id := String(terrain_id_value)
		var count := int(counts.get(terrain_id, 0))
		if count > best_count or (count == best_count and terrain_id < best_id):
			best_id = terrain_id
			best_count = count
	return best_id

func _normalize_terrain_id(cell: Variant) -> String:
	var terrain_id := ""
	if cell is Dictionary:
		terrain_id = String(cell.get("terrain_id", cell.get("terrain", "")))
	else:
		terrain_id = String(cell)
	terrain_id = terrain_id.strip_edges()
	if terrain_id == "" or not TERRAIN_SPECS.has(terrain_id):
		return "grass"
	return terrain_id

func _max_enemy_pressure(enemy_states: Variant) -> int:
	var max_pressure := 0
	if not (enemy_states is Array):
		return max_pressure
	for state in enemy_states:
		if state is Dictionary:
			max_pressure = max(max_pressure, int(state.get("pressure", 0)))
	return max_pressure

func _threat_level(pressure: int) -> String:
	if pressure >= 8:
		return "high"
	if pressure >= 4:
		return "medium"
	if pressure > 0:
		return "low"
	return "calm"

func _signature_for_context(context: Dictionary) -> String:
	return "%s:%d:%d:%d:%s:%s:%s" % [
		String(context.get("scenario_id", "")),
		int(context.get("day", 0)),
		int(context.get("x", 0)),
		int(context.get("y", 0)),
		String(context.get("terrain_id", "")),
		String(context.get("dominant_terrain_id", "")),
		String(context.get("threat_level", "")),
	]

func _prune_players() -> void:
	var kept: Array[AudioStreamPlayer] = []
	for player in _active_players:
		if is_instance_valid(player) and player.is_inside_tree() and player.playing:
			kept.append(player)
		elif is_instance_valid(player):
			player.queue_free()
	_active_players = kept

func _ambient_sfx_manifest_cue(cue_id: String) -> Dictionary:
	_load_ambient_sfx_manifest()
	var cues: Dictionary = _ambient_sfx_manifest.get("cues", {}) if _ambient_sfx_manifest.get("cues", {}) is Dictionary else {}
	var cue: Dictionary = cues.get(cue_id, {}) if cues.get(cue_id, {}) is Dictionary else {}
	return cue.duplicate(true)

func _load_ambient_sfx_manifest() -> void:
	if _ambient_sfx_manifest_loaded:
		return
	_ambient_sfx_manifest_loaded = true
	_ambient_sfx_manifest = {}
	if not FileAccess.file_exists(AMBIENT_SFX_MANIFEST_PATH):
		return
	var text := FileAccess.get_file_as_string(AMBIENT_SFX_MANIFEST_PATH)
	if text.strip_edges() == "":
		return
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary:
		_ambient_sfx_manifest = parsed
