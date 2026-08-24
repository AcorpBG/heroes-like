class_name HeroesMusicAudio
extends Node

const SAMPLE_RATE := 22050
const MAX_ACTIVE_PLAYERS := 3
const MAX_RECORDS := 24
const DEFAULT_SEGMENT_DURATION := 1.35
const REPORT_SCHEMA := "music_audio_runtime_v1"
const MUSIC_RUNTIME_MANIFEST_PATH := "res://content/music_runtime_manifest.json"
const TOWN_FACTION_CUE_IDS := {
	"faction_embercourt": "music_town_embercourt_theme",
	"faction_mireclaw": "music_town_mireclaw_theme",
	"faction_sunvault": "music_town_sunvault_theme",
	"faction_thornwake": "music_town_thornwake_theme",
	"faction_brasshollow": "music_town_brasshollow_theme",
	"faction_veilmourn": "music_town_veilmourn_theme",
}
const OVERWORLD_FACTION_CUE_IDS := {
	"faction_embercourt": "music_overworld_embercourt_theme",
	"faction_mireclaw": "music_overworld_mireclaw_theme",
	"faction_sunvault": "music_overworld_sunvault_theme",
	"faction_thornwake": "music_overworld_thornwake_theme",
	"faction_brasshollow": "music_overworld_brasshollow_theme",
	"faction_veilmourn": "music_overworld_veilmourn_theme",
}
const CONTEXT_SPECS := {
	"menu": {
		"cue_id": "music_menu_theme",
		"root": 196.0,
		"gain": 0.026,
		"label": "menu horizon",
		"mode": "major",
		"pulse": 0.35,
	},
	"overworld": {
		"cue_id": "music_overworld_theme",
		"root": 174.0,
		"gain": 0.024,
		"label": "frontier march",
		"mode": "minor",
		"pulse": 0.45,
	},
	"town": {
		"cue_id": "music_town_theme",
		"root": 146.0,
		"gain": 0.023,
		"label": "town hearth",
		"mode": "major",
		"pulse": 0.52,
	},
	"battle": {
		"cue_id": "music_battle_theme",
		"root": 110.0,
		"gain": 0.032,
		"label": "battle pressure",
		"mode": "minor",
		"pulse": 1.75,
	},
	"outcome": {
		"cue_id": "music_outcome_theme",
		"root": 220.0,
		"gain": 0.022,
		"label": "aftermath cadence",
		"mode": "major",
		"pulse": 0.28,
	},
}

var _records: Array[Dictionary] = []
var _active_players: Array[AudioStreamPlayer] = []
var _current_signature := ""
var _current_context_id := ""
var _current_layers: Array[Dictionary] = []
var _music_runtime_manifest: Dictionary = {}
var _music_runtime_manifest_loaded := false

func sync_context(context_id: String, source: String = "runtime", metadata: Dictionary = {}) -> Dictionary:
	var normalized := _normalize_context_id(context_id)
	var cue_id := _cue_id_for_context(normalized, metadata)
	var signature := _signature_for_context(normalized, metadata)
	if signature == _current_signature and not _active_players.is_empty():
		return {
			"schema": REPORT_SCHEMA,
			"cue_id": cue_id,
			"context_id": normalized,
			"source": source,
			"changed": false,
			"signature": signature,
			"metadata": metadata.duplicate(true),
			"layer_count": _current_layers.size(),
			"layers": _current_layers.duplicate(true),
			"audio_bus": _music_bus(),
			"music_manifest_path": MUSIC_RUNTIME_MANIFEST_PATH,
			"music_manifest_loaded": _music_runtime_manifest_loaded,
			"active_player_count": _active_players.size(),
			"muted": _is_muted(),
			"played": not _is_muted(),
			"timestamp_msec": Time.get_ticks_msec(),
		}
	stop_music("signature_changed")
	_current_signature = signature
	_current_context_id = normalized
	_current_layers = _layers_for_context(normalized, cue_id, metadata)
	var muted := _is_muted()
	if not muted:
		_play_layers(_current_layers)
	return _append_record({
		"schema": REPORT_SCHEMA,
		"cue_id": cue_id,
		"context_id": normalized,
		"source": source,
		"changed": true,
		"signature": signature,
		"metadata": metadata.duplicate(true),
		"layer_count": _current_layers.size(),
		"layers": _current_layers.duplicate(true),
		"audio_bus": _music_bus(),
		"music_manifest_path": MUSIC_RUNTIME_MANIFEST_PATH,
		"music_manifest_loaded": _music_runtime_manifest_loaded,
		"active_player_count": _active_players.size(),
		"muted": muted,
		"played": not muted,
		"timestamp_msec": Time.get_ticks_msec(),
	})

func stop_music(reason: String = "manual") -> void:
	for player in _active_players:
		if is_instance_valid(player):
			player.queue_free()
	_active_players.clear()
	_current_signature = ""
	_current_context_id = ""
	_current_layers.clear()

func validation_reset() -> void:
	stop_music("validation_reset")
	_records.clear()

func validation_records() -> Array:
	return _records.duplicate(true)

func validation_summary() -> Dictionary:
	var cue_counts := {}
	var context_counts := {}
	for record in _records:
		var cue_id := String(record.get("cue_id", ""))
		var context_id := String(record.get("context_id", ""))
		cue_counts[cue_id] = int(cue_counts.get(cue_id, 0)) + 1
		context_counts[context_id] = int(context_counts.get(context_id, 0)) + 1
	return {
		"schema": REPORT_SCHEMA,
		"record_count": _records.size(),
		"cue_counts": cue_counts,
		"context_counts": context_counts,
		"active_player_count": _active_players.size(),
		"current_signature": _current_signature,
		"current_context_id": _current_context_id,
		"current_layers": _current_layers.duplicate(true),
		"audio_bus": _music_bus(),
		"max_active_players": MAX_ACTIVE_PLAYERS,
		"music_manifest_path": MUSIC_RUNTIME_MANIFEST_PATH,
		"music_manifest_loaded": _music_runtime_manifest_loaded,
		"records": validation_records(),
	}

func _normalize_context_id(context_id: String) -> String:
	var normalized := context_id.strip_edges().to_lower()
	if CONTEXT_SPECS.has(normalized):
		return normalized
	return "menu"

func _cue_id_for_context(context_id: String, metadata: Dictionary) -> String:
	var spec: Dictionary = CONTEXT_SPECS[context_id]
	if context_id == "overworld":
		var player_faction_id := String(metadata.get("player_faction_id", "")).strip_edges().to_lower()
		if OVERWORLD_FACTION_CUE_IDS.has(player_faction_id):
			return String(OVERWORLD_FACTION_CUE_IDS[player_faction_id])
	if context_id == "town":
		var faction_id := String(metadata.get("town_faction_id", "")).strip_edges().to_lower()
		if TOWN_FACTION_CUE_IDS.has(faction_id):
			return String(TOWN_FACTION_CUE_IDS[faction_id])
	return String(spec.get("cue_id", "music_menu_theme"))

func _layers_for_context(context_id: String, cue_id: String, metadata: Dictionary) -> Array[Dictionary]:
	var spec: Dictionary = CONTEXT_SPECS[context_id]
	var root := float(spec.get("root", 174.0))
	var gain := float(spec.get("gain", 0.024))
	var mode := String(spec.get("mode", "major"))
	var third_multiplier := 1.2599 if mode == "major" else 1.1892
	var intensity := _metadata_intensity(metadata)
	var layers: Array[Dictionary] = []
	layers.append(_layer_payload("root", cue_id, root, gain, 0.0, float(spec.get("pulse", 0.4)), String(spec.get("label", cue_id))))
	layers.append(_layer_payload("harmony", "%s_harmony" % cue_id, root * third_multiplier, gain * 0.72, 0.22, float(spec.get("pulse", 0.4)) * 0.5, "harmonic color"))
	layers.append(_layer_payload("motion", "%s_motion" % cue_id, root * (1.5 + (0.08 * intensity)), gain * 0.52, 0.47, float(spec.get("pulse", 0.4)) + intensity, "context motion"))
	return layers

func _layer_payload(layer_id: String, cue_id: String, frequency: float, gain: float, phase_offset: float, pulse_rate: float, label: String) -> Dictionary:
	var manifest_cue := _music_runtime_manifest_cue(cue_id)
	return {
		"layer_id": layer_id,
		"cue_id": cue_id,
		"label": label,
		"frequency": frequency,
		"gain": gain,
		"duration_sec": DEFAULT_SEGMENT_DURATION,
		"phase_offset": phase_offset,
		"pulse_rate": pulse_rate,
		"audio_bus": _music_bus(),
		"music_manifest_path": MUSIC_RUNTIME_MANIFEST_PATH,
		"music_manifest_loaded": _music_runtime_manifest_loaded,
		"asset_path": String(manifest_cue.get("path", "")),
		"role": String(manifest_cue.get("role", "")),
		"playback_source": "pending",
		"imported_asset_count": 0,
		"generated_fallback_count": 0,
	}

func _play_layers(layers: Array[Dictionary]) -> void:
	_prune_players()
	for index in range(layers.size()):
		if _active_players.size() >= MAX_ACTIVE_PLAYERS:
			break
		var layer: Dictionary = layers[index]
		if _play_imported_layer(layer):
			layers[index] = layer
			continue
		var stream := AudioStreamGenerator.new()
		stream.mix_rate = SAMPLE_RATE
		stream.buffer_length = maxf(0.1, float(layer.get("duration_sec", DEFAULT_SEGMENT_DURATION)))
		var player := AudioStreamPlayer.new()
		player.bus = _music_bus()
		player.stream = stream
		add_child(player)
		player.play()
		var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
		if playback != null:
			_fill_music_waveform(playback, layer)
		_active_players.append(player)
		layer["playback_source"] = "generated_waveform"
		layer["generated_fallback_count"] = 1
		layers[index] = layer
	var timer := get_tree().create_timer(DEFAULT_SEGMENT_DURATION + 0.1) if get_tree() != null and not layers.is_empty() else null
	if timer != null:
		timer.timeout.connect(_prune_players)

func _play_imported_layer(layer: Dictionary) -> bool:
	var cue := _music_runtime_manifest_cue(String(layer.get("cue_id", "")))
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
	player.bus = _music_bus()
	player.stream = playback_stream
	player.volume_db = float(cue.get("volume_db", -25.0))
	add_child(player)
	_active_players.append(player)
	player.play()
	layer["playback_source"] = "imported_wav"
	layer["asset_path"] = path
	layer["role"] = String(cue.get("role", ""))
	layer["duration_sec"] = maxf(0.01, float(cue.get("duration_msec", 1350)) / 1000.0)
	layer["volume_db"] = float(cue.get("volume_db", -25.0))
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

func _fill_music_waveform(playback: AudioStreamGeneratorPlayback, layer: Dictionary) -> void:
	var duration := float(layer.get("duration_sec", DEFAULT_SEGMENT_DURATION))
	var frame_count := maxi(1, int(SAMPLE_RATE * duration))
	var frequency := float(layer.get("frequency", 174.0))
	var gain := float(layer.get("gain", 0.024))
	var phase_offset := float(layer.get("phase_offset", 0.0))
	var pulse_rate := maxf(0.05, float(layer.get("pulse_rate", 0.4)))
	for frame in range(frame_count):
		var t := float(frame) / float(SAMPLE_RATE)
		var fade_in := minf(1.0, float(frame) / maxf(1.0, float(frame_count) * 0.16))
		var fade_out := minf(1.0, float(frame_count - frame) / maxf(1.0, float(frame_count) * 0.2))
		var envelope := minf(fade_in, fade_out)
		var shimmer := sin(TAU * (frequency * 2.0) * (t + phase_offset)) * 0.18
		var pulse := 0.72 + (0.28 * sin(TAU * pulse_rate * (t + phase_offset)))
		var sample := (sin(TAU * frequency * (t + phase_offset)) + shimmer) * gain * envelope * pulse
		playback.push_frame(Vector2(sample, sample))

func _signature_for_context(context_id: String, metadata: Dictionary) -> String:
	var parts := [context_id]
	for key in ["scenario_id", "day", "status", "encounter_id", "encounter_difficulty", "launch_mode", "threat_level", "player_faction_id", "town_placement_id", "town_id", "town_faction_id"]:
		if metadata.has(key):
			parts.append("%s=%s" % [key, str(metadata.get(key, ""))])
	return "|".join(parts)

func _metadata_intensity(metadata: Dictionary) -> float:
	var difficulty := String(metadata.get("encounter_difficulty", metadata.get("difficulty", "")))
	if difficulty == "hard":
		return 1.4
	if difficulty == "story":
		return 0.4
	if String(metadata.get("status", "")) == "defeat":
		return 0.9
	return 1.0

func _is_muted() -> bool:
	return SettingsService.master_volume_percent() <= 0 or SettingsService.music_volume_percent() <= 0

func _music_bus() -> String:
	return SettingsService.music_audio_bus_name()

func _append_record(record: Dictionary) -> Dictionary:
	_records.append(record.duplicate(true))
	while _records.size() > MAX_RECORDS:
		_records.pop_front()
	return record

func _prune_players() -> void:
	var kept: Array[AudioStreamPlayer] = []
	for player in _active_players:
		if is_instance_valid(player) and player.is_inside_tree() and player.playing:
			kept.append(player)
		elif is_instance_valid(player):
			player.queue_free()
	_active_players = kept

func _music_runtime_manifest_cue(cue_id: String) -> Dictionary:
	_load_music_runtime_manifest()
	var cues: Dictionary = _music_runtime_manifest.get("cues", {}) if _music_runtime_manifest.get("cues", {}) is Dictionary else {}
	var cue: Dictionary = cues.get(cue_id, {}) if cues.get(cue_id, {}) is Dictionary else {}
	return cue.duplicate(true)

func _load_music_runtime_manifest() -> void:
	if _music_runtime_manifest_loaded:
		return
	_music_runtime_manifest_loaded = true
	_music_runtime_manifest = {}
	if not FileAccess.file_exists(MUSIC_RUNTIME_MANIFEST_PATH):
		return
	var text := FileAccess.get_file_as_string(MUSIC_RUNTIME_MANIFEST_PATH)
	if text.strip_edges() == "":
		return
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary:
		_music_runtime_manifest = parsed
