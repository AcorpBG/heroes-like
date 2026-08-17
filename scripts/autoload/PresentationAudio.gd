class_name HeroesPresentationAudio
extends Node

const SAMPLE_RATE := 22050
const MAX_ACTIVE_PLAYERS := 6
const REDUCED_REPETITION_MAX_ACTIVE_PLAYERS := 3
const MAX_RECORDS := 24
const PRESENTATION_SFX_MANIFEST_PATH := "res://content/presentation_sfx_manifest.json"
const EFFECTS_AUDIO_BUS := "Effects"
const CUE_SPECS := {
	"audio_placeholder_artifact_claim": {"frequency": 392.0, "duration": 0.42, "gain": 0.12},
	"audio_placeholder_artifact_equip": {"frequency": 246.0, "duration": 0.26, "gain": 0.10},
	"audio_placeholder_artifact_stow": {"frequency": 164.0, "duration": 0.28, "gain": 0.10},
	"audio_placeholder_resource_tick": {"frequency": 880.0, "duration": 0.24, "gain": 0.09},
	"audio_placeholder_spell_school_soft": {"frequency": 294.0, "duration": 0.48, "gain": 0.11},
	"audio_placeholder_save_confirm": {"frequency": 523.0, "duration": 0.32, "gain": 0.10},
	"audio_placeholder_load_resume": {"frequency": 330.0, "duration": 0.36, "gain": 0.11},
	"audio_placeholder_map_step": {"frequency": 196.0, "duration": 0.22, "gain": 0.09},
	"audio_placeholder_object_focus": {"frequency": 523.0, "duration": 0.26, "gain": 0.09},
	"audio_placeholder_invalid_route": {"frequency": 146.0, "duration": 0.30, "gain": 0.12},
	"audio_placeholder_blocked_object": {"frequency": 110.0, "duration": 0.34, "gain": 0.12},
	"audio_placeholder_route_open": {"frequency": 392.0, "duration": 0.42, "gain": 0.13},
	"audio_placeholder_route_closed": {"frequency": 174.0, "duration": 0.44, "gain": 0.13},
	"audio_placeholder_object_visit": {"frequency": 440.0, "duration": 0.30, "gain": 0.10},
	"audio_placeholder_capture": {"frequency": 262.0, "duration": 0.42, "gain": 0.13},
	"audio_placeholder_collect": {"frequency": 698.0, "duration": 0.28, "gain": 0.10},
	"audio_placeholder_guard_warning": {"frequency": 196.0, "duration": 0.34, "gain": 0.12},
	"audio_placeholder_town_build": {"frequency": 176.0, "duration": 0.42, "gain": 0.13},
	"audio_placeholder_recruit": {"frequency": 132.0, "duration": 0.36, "gain": 0.12},
	"audio_placeholder_town_route_response": {"frequency": 330.0, "duration": 0.38, "gain": 0.11},
	"audio_placeholder_town_market_exchange": {"frequency": 520.0, "duration": 0.36, "gain": 0.10},
	"audio_placeholder_town_spell_study": {"frequency": 392.0, "duration": 0.40, "gain": 0.11},
	"audio_placeholder_town_hero_hire": {"frequency": 440.0, "duration": 0.42, "gain": 0.12},
	"audio_placeholder_town_specialty_rank": {"frequency": 523.25, "duration": 0.40, "gain": 0.11},
	"audio_placeholder_town_unit_transfer": {"frequency": 220.0, "duration": 0.38, "gain": 0.10},
	"audio_placeholder_ui_confirm": {"frequency": 760.0, "duration": 0.12, "gain": 0.11},
}

var _records: Array[Dictionary] = []
var _active_players: Array[AudioStreamPlayer] = []
var _presentation_sfx_manifest: Dictionary = {}
var _presentation_sfx_manifest_loaded := false

func play_cue(cue_id: String, source: String = "", metadata: Dictionary = {}) -> Dictionary:
	var supported := CUE_SPECS.has(cue_id)
	var muted := SettingsService.effects_audio_muted()
	var reduced_repetition := SettingsService.reduced_repetitive_sounds_enabled()
	var effective_voice_budget := REDUCED_REPETITION_MAX_ACTIVE_PLAYERS if reduced_repetition else MAX_ACTIVE_PLAYERS
	var now := int(Time.get_ticks_msec())
	var record := {
		"cue_id": cue_id,
		"source": source,
		"metadata": metadata.duplicate(true),
		"audio_bus": EFFECTS_AUDIO_BUS,
		"sfx_manifest_path": PRESENTATION_SFX_MANIFEST_PATH,
		"supported": supported,
		"muted": muted,
		"played": false,
		"timestamp_msec": now,
		"reduced_repetitive_sounds": reduced_repetition,
		"effective_voice_budget": effective_voice_budget,
		"suppressed_reason": "unsupported_cue" if not supported else ("effects_muted" if muted else ""),
	}
	var playback := {}
	if supported and not muted:
		_trim_players_to_budget(effective_voice_budget - 1)
		playback = _play_imported_audio_cue(cue_id)
		if playback.is_empty():
			playback = _play_generated_waveform(CUE_SPECS[cue_id])
			if not playback.is_empty():
				playback["source"] = "generated_waveform"
		if not playback.is_empty():
			record["played"] = true
	record["playback_source"] = String(playback.get("source", "muted" if muted else ("unsupported" if not supported else "none")))
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
	record["sfx_manifest_loaded"] = _presentation_sfx_manifest_loaded
	record["imported_asset_count"] = 1 if String(playback.get("source", "")) == "imported_wav" else 0
	record["generated_fallback_count"] = 1 if String(playback.get("source", "")) == "generated_waveform" else 0
	record["active_player_count"] = _active_players.size()
	_records.append(record.duplicate(true))
	while _records.size() > MAX_RECORDS:
		_records.pop_front()
	return record

func validation_reset() -> void:
	_records.clear()
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
		"schema": "presentation_audio_runtime_v1",
		"record_count": _records.size(),
		"cue_counts": cue_counts,
		"active_player_count": _active_players.size(),
		"audio_bus": EFFECTS_AUDIO_BUS,
		"max_active_players": MAX_ACTIVE_PLAYERS,
		"effective_voice_budget": _effective_voice_budget(),
		"reduced_repetitive_sounds": SettingsService.reduced_repetitive_sounds_enabled(),
		"sfx_manifest_path": PRESENTATION_SFX_MANIFEST_PATH,
		"sfx_manifest_loaded": _presentation_sfx_manifest_loaded,
		"records": validation_records(),
	}

func _play_imported_audio_cue(cue_id: String) -> Dictionary:
	var cue := _presentation_sfx_manifest_cue(cue_id)
	if cue.is_empty():
		return {}
	var path := String(cue.get("path", "")).strip_edges()
	if path == "":
		return {}
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
	var duration_msec := int(cue.get("duration_msec", 100))
	var stream_length := stream.get_length()
	if stream_length > 0.0:
		duration_msec = maxi(1, int(ceil(stream_length * 1000.0)))
	var player := AudioStreamPlayer.new()
	player.bus = SettingsService.effects_audio_bus_name()
	player.stream = stream
	player.volume_db = float(cue.get("volume_db", -14.0))
	add_child(player)
	_track_player(player, float(duration_msec) / 1000.0 + 0.04)
	player.play()
	return {
		"source": "imported_wav",
		"asset_path": path,
		"role": String(cue.get("role", "")),
		"duration_msec": duration_msec,
		"volume_db": float(cue.get("volume_db", -14.0)),
		"player_created": true,
		"stream_length_sec": stream_length,
		"stream_mix_rate": stream_mix_rate,
		"stream_stereo": stream_stereo,
		"stream_format": stream_format,
		"stream_loop_mode": stream_loop_mode,
	}

func _play_generated_waveform(spec: Dictionary) -> Dictionary:
	var duration := float(spec.get("duration", 0.2))
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = SAMPLE_RATE
	stream.buffer_length = maxf(0.04, duration)
	var player := AudioStreamPlayer.new()
	player.bus = SettingsService.effects_audio_bus_name()
	player.stream = stream
	add_child(player)
	player.play()
	var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback != null:
		_fill_waveform(playback, float(spec.get("frequency", 176.0)), duration, float(spec.get("gain", 0.12)))
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
		var body := sin(TAU * frequency * t) * 0.72 + sin(TAU * frequency * 1.5 * t) * 0.28
		var sample := body * gain * envelope
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

func _presentation_sfx_manifest_cue(cue_id: String) -> Dictionary:
	_load_presentation_sfx_manifest()
	var cues: Dictionary = _presentation_sfx_manifest.get("cues", {}) if _presentation_sfx_manifest.get("cues", {}) is Dictionary else {}
	var cue: Dictionary = cues.get(cue_id, {}) if cues.get(cue_id, {}) is Dictionary else {}
	return cue.duplicate(true)

func _load_presentation_sfx_manifest() -> void:
	if _presentation_sfx_manifest_loaded:
		return
	_presentation_sfx_manifest_loaded = true
	_presentation_sfx_manifest = {}
	if not FileAccess.file_exists(PRESENTATION_SFX_MANIFEST_PATH):
		return
	var text := FileAccess.get_file_as_string(PRESENTATION_SFX_MANIFEST_PATH)
	if text.strip_edges() == "":
		return
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary:
		_presentation_sfx_manifest = parsed
