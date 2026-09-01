class_name HeroesUiAudio
extends Node

const RuntimeAudioLoaderScript = preload("res://scripts/audio/RuntimeAudioLoader.gd")

const SAMPLE_RATE := 22050
const MAX_ACTIVE_PLAYERS := 8
const REDUCED_REPETITION_MAX_ACTIVE_PLAYERS := 4
const MAX_RECORDS := 24
const UI_SFX_MANIFEST_PATH := "res://content/ui_sfx_manifest.json"
const EFFECTS_AUDIO_BUS := "Effects"
const CUE_SPECS := {
	"ui_click": {"frequency": 520.0, "duration": 0.055, "gain": 0.10},
	"ui_select": {"frequency": 660.0, "duration": 0.06, "gain": 0.09},
	"ui_adjust": {"frequency": 440.0, "duration": 0.04, "gain": 0.07},
	"ui_tab": {"frequency": 585.0, "duration": 0.055, "gain": 0.085},
	"ui_confirm": {"frequency": 760.0, "duration": 0.09, "gain": 0.11},
	"ui_invalid": {"frequency": 180.0, "duration": 0.11, "gain": 0.10},
}
const REDUCED_REPETITION_COOLDOWN_MSEC := {
	"ui_click": 120,
	"ui_select": 160,
	"ui_adjust": 180,
	"ui_tab": 180,
	"ui_confirm": 220,
	"ui_invalid": 260,
}

var _connected_control_ids := {}
var _records: Array[Dictionary] = []
var _active_players: Array[AudioStreamPlayer] = []
var _last_started_msec_by_cue := {}
var _ui_sfx_manifest: Dictionary = {}
var _ui_sfx_manifest_loaded := false

func _ready() -> void:
	if get_tree() != null:
		get_tree().node_added.connect(_on_node_added)
	call_deferred("_scan_tree")

func play_cue(cue_id: String, source: String = "", metadata: Dictionary = {}) -> Dictionary:
	var normalized := cue_id if CUE_SPECS.has(cue_id) else "ui_click"
	var spec: Dictionary = CUE_SPECS[normalized]
	var muted := SettingsService.effects_audio_muted()
	var reduced_repetition := SettingsService.reduced_repetitive_sounds_enabled()
	var effective_voice_budget := REDUCED_REPETITION_MAX_ACTIVE_PLAYERS if reduced_repetition else MAX_ACTIVE_PLAYERS
	var repeat_cooldown_msec := int(REDUCED_REPETITION_COOLDOWN_MSEC.get(normalized, 160)) if reduced_repetition else 0
	var now := int(Time.get_ticks_msec())
	var last_started := int(_last_started_msec_by_cue.get(normalized, -1000000000))
	var suppressed_reason := ""
	if muted:
		suppressed_reason = "effects_muted"
	elif repeat_cooldown_msec > 0 and now - last_started < repeat_cooldown_msec:
		suppressed_reason = "repeat_cooldown"
	var record := {
		"cue_id": normalized,
		"source": source,
		"metadata": metadata.duplicate(true),
		"audio_bus": EFFECTS_AUDIO_BUS,
		"sfx_manifest_path": UI_SFX_MANIFEST_PATH,
		"frequency": float(spec.get("frequency", 440.0)),
		"duration_sec": float(spec.get("duration", 0.05)),
		"gain": float(spec.get("gain", 0.08)),
		"muted": muted,
		"played": false,
		"timestamp_msec": now,
		"reduced_repetitive_sounds": reduced_repetition,
		"effective_voice_budget": effective_voice_budget,
		"repeat_cooldown_msec": repeat_cooldown_msec,
		"suppressed_reason": suppressed_reason,
	}
	var playback := {}
	if suppressed_reason == "":
		_trim_players_to_budget(effective_voice_budget - 1)
		playback = _play_imported_audio_cue(normalized)
		if playback.is_empty():
			playback = _play_generated_waveform(record)
			if not playback.is_empty():
				playback["source"] = "generated_waveform"
		if not playback.is_empty():
			record["played"] = true
			_last_started_msec_by_cue[normalized] = now
	record["playback_source"] = String(playback.get("source", "muted" if muted else ("suppressed" if suppressed_reason != "" else "none")))
	record["asset_path"] = String(playback.get("asset_path", ""))
	record["role"] = String(playback.get("role", ""))
	record["volume_db"] = float(playback.get("volume_db", 0.0))
	record["duration_msec"] = int(playback.get("duration_msec", 0))
	record["player_created"] = bool(playback.get("player_created", false))
	record["stream_length_sec"] = float(playback.get("stream_length_sec", 0.0))
	record["stream_mix_rate"] = int(playback.get("stream_mix_rate", 0))
	record["stream_stereo"] = bool(playback.get("stream_stereo", false))
	record["stream_format"] = int(playback.get("stream_format", -1))
	record["stream_loop_mode"] = int(playback.get("stream_loop_mode", -1))
	record["sfx_manifest_loaded"] = _ui_sfx_manifest_loaded
	record["imported_asset_count"] = 1 if String(playback.get("source", "")) == "imported_wav" else 0
	record["generated_fallback_count"] = 1 if String(playback.get("source", "")) == "generated_waveform" else 0
	record["active_player_count"] = _active_players.size()
	_records.append(record.duplicate(true))
	while _records.size() > MAX_RECORDS:
		_records.pop_front()
	return record

func play_confirm(source: String = "manual", metadata: Dictionary = {}) -> Dictionary:
	return play_cue("ui_confirm", source, metadata)

func play_invalid(source: String = "manual", metadata: Dictionary = {}) -> Dictionary:
	return play_cue("ui_invalid", source, metadata)

func attach_control(control: Control) -> bool:
	if control == null:
		return false
	var id := control.get_instance_id()
	if _connected_control_ids.has(id):
		return false
	var connected := false
	if control is OptionButton:
		(control as OptionButton).item_selected.connect(_on_option_selected.bind(control))
		connected = true
	elif control is Button:
		(control as Button).pressed.connect(_on_button_pressed.bind(control))
		connected = true
	elif control is Range:
		(control as Range).value_changed.connect(_on_range_changed.bind(control))
		connected = true
	elif control is TabContainer:
		(control as TabContainer).tab_changed.connect(_on_tab_changed.bind(control))
		connected = true
	elif control is ItemList:
		(control as ItemList).item_selected.connect(_on_item_selected.bind(control))
		connected = true
	if connected:
		_connected_control_ids[id] = true
	return connected

func validation_reset() -> void:
	_records.clear()
	_last_started_msec_by_cue.clear()
	for player in _active_players:
		if is_instance_valid(player):
			player.queue_free()
	_active_players.clear()

func validation_records() -> Array:
	return _records.duplicate(true)

func validation_summary() -> Dictionary:
	var cue_counts := {}
	for record in _records:
		var cue_id := String(record.get("cue_id", ""))
		cue_counts[cue_id] = int(cue_counts.get(cue_id, 0)) + 1
	return {
		"schema": "ui_audio_runtime_v1",
		"record_count": _records.size(),
		"cue_counts": cue_counts,
		"active_player_count": _active_players.size(),
		"connected_control_count": _connected_control_ids.size(),
		"audio_bus": EFFECTS_AUDIO_BUS,
		"max_active_players": MAX_ACTIVE_PLAYERS,
		"effective_voice_budget": _effective_voice_budget(),
		"reduced_repetitive_sounds": SettingsService.reduced_repetitive_sounds_enabled(),
		"sfx_manifest_path": UI_SFX_MANIFEST_PATH,
		"sfx_manifest_loaded": _ui_sfx_manifest_loaded,
		"records": validation_records(),
	}

func _scan_tree() -> void:
	var root := get_tree().root if get_tree() != null else null
	if root != null:
		_scan_node(root)

func _scan_node(node: Node) -> void:
	if node is Control:
		attach_control(node as Control)
	for child in node.get_children():
		_scan_node(child)

func _on_node_added(node: Node) -> void:
	if node is Control:
		attach_control(node as Control)

func _on_button_pressed(control: Control) -> void:
	play_cue("ui_click", _control_source(control), _control_metadata(control))

func _on_option_selected(index: int, control: Control) -> void:
	var metadata := _control_metadata(control)
	metadata["index"] = index
	play_cue("ui_select", _control_source(control), metadata)

func _on_range_changed(value: float, control: Control) -> void:
	var metadata := _control_metadata(control)
	metadata["value"] = snapped(value, 0.001)
	play_cue("ui_adjust", _control_source(control), metadata)

func _on_tab_changed(tab: int, control: Control) -> void:
	var metadata := _control_metadata(control)
	metadata["tab"] = tab
	play_cue("ui_tab", _control_source(control), metadata)

func _on_item_selected(index: int, control: Control) -> void:
	var metadata := _control_metadata(control)
	metadata["index"] = index
	play_cue("ui_select", _control_source(control), metadata)

func _control_source(control: Control) -> String:
	var path: String = str(control.get_path()) if control.is_inside_tree() else String(control.name)
	return path if path != "" else control.get_class()

func _control_metadata(control: Control) -> Dictionary:
	return {
		"class": control.get_class(),
		"name": control.name,
		"disabled": bool(control.get("disabled")) if control is BaseButton else false,
	}

func _play_imported_audio_cue(cue_id: String) -> Dictionary:
	var cue := _ui_sfx_manifest_cue(cue_id)
	if cue.is_empty():
		return {}
	var path := String(cue.get("path", "")).strip_edges()
	if path == "":
		return {}
	var stream := RuntimeAudioLoaderScript.load_stream(path)
	if stream == null:
		return {}
	var stream_mix_rate := 0
	var stream_stereo := false
	var stream_format := -1
	var stream_loop_mode := -1
	if stream is AudioStreamWAV:
		var wav_metadata := stream as AudioStreamWAV
		stream_mix_rate = int(wav_metadata.mix_rate)
		stream_stereo = bool(wav_metadata.stereo)
		stream_format = int(wav_metadata.format)
		stream_loop_mode = int(wav_metadata.loop_mode)
	var duration_msec := int(cue.get("duration_msec", 80))
	var stream_length := stream.get_length()
	if stream_length > 0.0:
		duration_msec = maxi(1, int(ceil(stream_length * 1000.0)))
	var player := AudioStreamPlayer.new()
	player.bus = SettingsService.effects_audio_bus_name()
	player.stream = stream
	player.volume_db = float(cue.get("volume_db", -18.0))
	add_child(player)
	_track_player(player, float(duration_msec) / 1000.0 + 0.04)
	player.play()
	return {
		"source": "imported_wav",
		"asset_path": path,
		"role": String(cue.get("role", "")),
		"duration_msec": duration_msec,
		"volume_db": float(cue.get("volume_db", -18.0)),
		"player_created": true,
		"stream_length_sec": stream_length,
		"stream_mix_rate": stream_mix_rate,
		"stream_stereo": stream_stereo,
		"stream_format": stream_format,
		"stream_loop_mode": stream_loop_mode,
	}

func _play_generated_waveform(record: Dictionary) -> Dictionary:
	_prune_players()
	while _active_players.size() >= _effective_voice_budget():
		var player: AudioStreamPlayer = _active_players.pop_front()
		if is_instance_valid(player):
			player.queue_free()
	var duration := float(record.get("duration_sec", 0.05))
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = SAMPLE_RATE
	stream.buffer_length = maxf(0.02, duration)
	var player := AudioStreamPlayer.new()
	player.bus = SettingsService.effects_audio_bus_name()
	player.stream = stream
	add_child(player)
	player.play()
	var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback != null:
		_fill_waveform(playback, float(record.get("frequency", 440.0)), duration, float(record.get("gain", 0.08)))
	_track_player(player, duration + 0.03)
	return {
		"source": "generated_waveform",
		"duration_msec": int(ceil(duration * 1000.0)),
		"volume_db": 0.0,
		"player_created": true,
	}

func _track_player(player: AudioStreamPlayer, lifetime_sec: float) -> void:
	_prune_players()
	while _active_players.size() >= _effective_voice_budget():
		var expired: AudioStreamPlayer = _active_players.pop_front()
		if is_instance_valid(expired):
			expired.queue_free()
	_active_players.append(player)
	var timer := get_tree().create_timer(maxf(0.02, lifetime_sec)) if get_tree() != null else null
	if timer != null:
		timer.timeout.connect(_on_player_expired.bind(player))

func _effective_voice_budget() -> int:
	return REDUCED_REPETITION_MAX_ACTIVE_PLAYERS if SettingsService.reduced_repetitive_sounds_enabled() else MAX_ACTIVE_PLAYERS

func _trim_players_to_budget(budget: int) -> void:
	_prune_players()
	while _active_players.size() > maxi(0, budget):
		var expired: AudioStreamPlayer = _active_players.pop_front()
		if is_instance_valid(expired):
			expired.queue_free()

func _fill_waveform(playback: AudioStreamGeneratorPlayback, frequency: float, duration: float, gain: float) -> void:
	var frame_count := maxi(1, int(SAMPLE_RATE * duration))
	for frame in range(frame_count):
		var t := float(frame) / float(SAMPLE_RATE)
		var envelope := 1.0 - (float(frame) / float(frame_count))
		var sample := sin(TAU * frequency * t) * gain * envelope
		playback.push_frame(Vector2(sample, sample))

func _on_player_expired(player) -> void:
	if is_instance_valid(player):
		player.queue_free()
	_prune_players()

func _prune_players() -> void:
	var kept: Array[AudioStreamPlayer] = []
	for player in _active_players:
		if is_instance_valid(player) and player.is_inside_tree():
			kept.append(player)
	_active_players = kept

func _ui_sfx_manifest_cue(cue_id: String) -> Dictionary:
	_load_ui_sfx_manifest()
	var cues: Dictionary = _ui_sfx_manifest.get("cues", {}) if _ui_sfx_manifest.get("cues", {}) is Dictionary else {}
	var cue: Dictionary = cues.get(cue_id, {}) if cues.get(cue_id, {}) is Dictionary else {}
	return cue.duplicate(true)

func _load_ui_sfx_manifest() -> void:
	if _ui_sfx_manifest_loaded:
		return
	_ui_sfx_manifest_loaded = true
	_ui_sfx_manifest = {}
	if not FileAccess.file_exists(UI_SFX_MANIFEST_PATH):
		return
	var text := FileAccess.get_file_as_string(UI_SFX_MANIFEST_PATH)
	if text.strip_edges() == "":
		return
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary:
		_ui_sfx_manifest = parsed
