class_name HeroesUiAudio
extends Node

const SAMPLE_RATE := 22050
const MAX_ACTIVE_PLAYERS := 8
const MAX_RECORDS := 24
const CUE_SPECS := {
	"ui_click": {"frequency": 520.0, "duration": 0.055, "gain": 0.10},
	"ui_select": {"frequency": 660.0, "duration": 0.06, "gain": 0.09},
	"ui_adjust": {"frequency": 440.0, "duration": 0.04, "gain": 0.07},
	"ui_tab": {"frequency": 585.0, "duration": 0.055, "gain": 0.085},
	"ui_confirm": {"frequency": 760.0, "duration": 0.09, "gain": 0.11},
	"ui_invalid": {"frequency": 180.0, "duration": 0.11, "gain": 0.10},
}

var _connected_control_ids := {}
var _records: Array[Dictionary] = []
var _active_players: Array[AudioStreamPlayer] = []

func _ready() -> void:
	if get_tree() != null:
		get_tree().node_added.connect(_on_node_added)
	call_deferred("_scan_tree")

func play_cue(cue_id: String, source: String = "", metadata: Dictionary = {}) -> Dictionary:
	var normalized := cue_id if CUE_SPECS.has(cue_id) else "ui_click"
	var spec: Dictionary = CUE_SPECS[normalized]
	var muted := SettingsService.master_volume_percent() <= 0
	var record := {
		"cue_id": normalized,
		"source": source,
		"metadata": metadata.duplicate(true),
		"audio_bus": "Master",
		"frequency": float(spec.get("frequency", 440.0)),
		"duration_sec": float(spec.get("duration", 0.05)),
		"gain": float(spec.get("gain", 0.08)),
		"muted": muted,
		"played": not muted,
		"timestamp_msec": Time.get_ticks_msec(),
	}
	if not muted:
		_play_generated_waveform(record)
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
		"audio_bus": "Master",
		"max_active_players": MAX_ACTIVE_PLAYERS,
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

func _play_generated_waveform(record: Dictionary) -> void:
	_prune_players()
	while _active_players.size() >= MAX_ACTIVE_PLAYERS:
		var player: AudioStreamPlayer = _active_players.pop_front()
		if is_instance_valid(player):
			player.queue_free()
	var duration := float(record.get("duration_sec", 0.05))
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = SAMPLE_RATE
	stream.buffer_length = maxf(0.02, duration)
	var player := AudioStreamPlayer.new()
	player.bus = "Master"
	player.stream = stream
	add_child(player)
	player.play()
	var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback != null:
		_fill_waveform(playback, float(record.get("frequency", 440.0)), duration, float(record.get("gain", 0.08)))
	_active_players.append(player)
	var timer := get_tree().create_timer(duration + 0.03) if get_tree() != null else null
	if timer != null:
		timer.timeout.connect(_on_player_expired.bind(player))

func _fill_waveform(playback: AudioStreamGeneratorPlayback, frequency: float, duration: float, gain: float) -> void:
	var frame_count := maxi(1, int(SAMPLE_RATE * duration))
	for frame in range(frame_count):
		var t := float(frame) / float(SAMPLE_RATE)
		var envelope := 1.0 - (float(frame) / float(frame_count))
		var sample := sin(TAU * frequency * t) * gain * envelope
		playback.push_frame(Vector2(sample, sample))

func _on_player_expired(player: AudioStreamPlayer) -> void:
	if is_instance_valid(player):
		player.queue_free()
	_prune_players()

func _prune_players() -> void:
	var kept: Array[AudioStreamPlayer] = []
	for player in _active_players:
		if is_instance_valid(player) and player.is_inside_tree():
			kept.append(player)
	_active_players = kept
