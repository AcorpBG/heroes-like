extends Node

const BattleBoardViewScript = preload("res://scenes/battle/BattleBoardView.gd")
const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const OUTPUT_DIR := "res://.artifacts/battle_event_animation_state_report"
const REPORT_ID := "BATTLE_EVENT_ANIMATION_STATE_REPORT"

var _errors: Array[String] = []
var _original_settings: Dictionary = {}
var _report := {
	"ok": false,
	"cases": {},
	"errors": [],
}

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_original_settings = SettingsService.settings.duplicate(true)
	SettingsService.settings["accessibility"]["reduce_motion"] = false
	SettingsService.settings["accessibility"]["reduce_flashes"] = false
	SettingsService.settings["accessibility"]["reduce_repetitive_sounds"] = false
	SettingsService.settings["accessibility"]["battle_camera_shake"] = SettingsService.BATTLE_CAMERA_SHAKE_FULL
	SettingsService.settings["audio"]["effects_volume_percent"] = 100
	SettingsService.apply_settings()
	_validate_fallback_states()
	_validate_core_vfx_asset_manifest()
	_validate_core_vfx_asset_surface()
	_validate_production_sfx_asset_surface()
	_validate_spell_vfx_asset_surface()
	_validate_state_path_vfx_asset_surface()
	_validate_defend_state()
	_validate_move_state()
	await _validate_melee_hit_state()
	_validate_retaliation_state()
	await _validate_ranged_status_state()
	_validate_death_state()
	await _validate_spell_cast_state()
	await _validate_resonant_chorus_vfx_identity()
	await _validate_reduced_flash_spell_state()
	await _validate_status_cleanse_state()
	_validate_status_round_expiry_state()
	await _validate_exit_action_state("retreat", "battle_unit_retreat", "retreat_withdraw_column")
	await _validate_exit_action_state("surrender", "battle_unit_surrender", "surrender_stand_down")
	await _validate_board_runtime_summary()
	if OS.get_environment("HEROES_BATTLE_VFX_CAPTURE") == "1":
		await _validate_imported_vfx_live_viewports()
		await _validate_spell_vfx_live_viewports()
		await _validate_state_path_vfx_live_viewports()
	await _validate_battle_audio_mix_policy()
	await _validate_board_playback_lifecycle()
	await _validate_presentation_event_stream_contract()
	await _validate_real_faction_matchup_presentation_smoke()
	await _validate_shell_presentation_event_surface()
	_report["ok"] = _errors.is_empty()
	_report["errors"] = _errors.duplicate()
	_write_json("%s/report.json" % OUTPUT_DIR, _report)
	SettingsService.settings = _original_settings.duplicate(true)
	SettingsService.apply_settings()
	if _errors.is_empty():
		print("%s %s" % [REPORT_ID, JSON.stringify(_summary_payload())])
	get_tree().quit(0 if _errors.is_empty() else 1)

func _validate_fallback_states() -> void:
	var session := _session_for_stacks(
		[
			_stack("unit_river_guard", "player", 0, "player_ready", 8, 0, 3),
			_stack("unit_bog_brute", "enemy", 0, "enemy_idle", 8, 6, 3),
		],
		"player_ready",
		"enemy_idle"
	)
	var ready_state := BattleRulesScript.animation_state_for_stack(session.battle, _stack_by_id(session.battle, "player_ready"))
	var idle_state := BattleRulesScript.animation_state_for_stack(session.battle, _stack_by_id(session.battle, "enemy_idle"))
	_expect_equal("fallback active ready", ready_state, "ready_active")
	_expect_equal("fallback enemy idle", idle_state, "idle_hold")
	_report["cases"]["fallback"] = {"ready_state": ready_state, "idle_state": idle_state}

func _validate_core_vfx_asset_manifest() -> void:
	var view := BattleBoardViewScript.new()
	view.size = Vector2(960.0, 540.0)
	add_child(view)
	var summary: Dictionary = view.validation_vfx_asset_summary()
	_expect_equal("battle vfx manifest schema", String(summary.get("schema_id", "")), "battle_vfx_manifest_v1")
	_expect_equal("battle vfx manifest path", String(summary.get("manifest_path", "")), "res://content/battle_vfx_manifest.json")
	_expect_int("battle vfx mapped cue count", int(summary.get("mapped_cue_count", -1)), 22)
	_expect_int("battle vfx unique texture count", int(summary.get("unique_texture_count", -1)), 22)
	_expect_int("battle vfx loaded texture count", int(summary.get("loaded_texture_count", -1)), 22)
	_expect_equal("battle vfx missing texture paths", JSON.stringify(summary.get("missing_texture_paths", [])), "[]")
	var core_cue_paths := {
		"vfx_placeholder_projectile_path": "res://art/battle/vfx/core_projectile_path.png",
		"vfx_placeholder_damage_tick": "res://art/battle/vfx/core_damage_impact.png",
		"vfx_placeholder_melee_arc": "res://art/battle/vfx/core_melee_arc.png",
		"vfx_placeholder_retaliation_arc": "res://art/battle/vfx/core_retaliation_arc.png",
		"vfx_placeholder_cast_anchor": "res://art/battle/vfx/core_cast_anchor.png",
		"vfx_placeholder_status_residue": "res://art/battle/vfx/core_status_residue.png",
		"vfx_placeholder_status_clear": "res://art/battle/vfx/core_status_clear.png",
		"vfx_placeholder_brace_outline": "res://art/battle/vfx/core_brace_outline.png",
	}
	var core_texture_paths: Array = core_cue_paths.values()
	_expect_int("battle core vfx semantic texture count", core_texture_paths.size(), 8)
	var unique_core_texture_paths: Dictionary = {}
	for cue_id_value in core_cue_paths.keys():
		var cue_id := String(cue_id_value)
		var cue: Dictionary = view.call("_battle_vfx_manifest_cue", cue_id)
		var expected_cue_path := String(core_cue_paths.get(cue_id, ""))
		_expect_equal("battle core vfx semantic path %s" % cue_id, String(cue.get("texture_path", "")), expected_cue_path)
		unique_core_texture_paths[expected_cue_path] = true
	_expect_int("battle core vfx one-to-one texture count", unique_core_texture_paths.size(), 8)
	for expected_path in [
		"res://art/battle/vfx/core_projectile_path.png",
		"res://art/battle/vfx/core_damage_impact.png",
		"res://art/battle/vfx/core_melee_arc.png",
		"res://art/battle/vfx/core_retaliation_arc.png",
		"res://art/battle/vfx/core_cast_anchor.png",
		"res://art/battle/vfx/core_status_residue.png",
		"res://art/battle/vfx/core_status_clear.png",
		"res://art/battle/vfx/core_brace_outline.png",
		"res://art/battle/vfx/spell_cinder_burst.png",
		"res://art/battle/vfx/spell_coal_rain.png",
		"res://art/battle/vfx/spell_sunlance_arc.png",
		"res://art/battle/vfx/spell_briar_bind.png",
		"res://art/battle/vfx/spell_graft_mend.png",
		"res://art/battle/vfx/spell_prism_bastion.png",
		"res://art/battle/vfx/spell_resonant_chorus.png",
		"res://art/battle/vfx/spell_command_ward.png",
		"res://art/battle/vfx/state_idle_shadow.png",
		"res://art/battle/vfx/state_active_ring.png",
		"res://art/battle/vfx/state_stack_fade.png",
		"res://art/battle/vfx/state_surrender_marker.png",
		"res://art/battle/vfx/path_move_ghost.png",
		"res://art/battle/vfx/path_withdraw_ghost.png",
	]:
		_expect_array_contains("battle vfx imported texture", summary.get("loaded_texture_paths", []), expected_path)
	view.queue_free()
	_report["cases"]["core_vfx_assets"] = summary

func _validate_core_vfx_asset_surface() -> void:
	var cue_paths := {
		"vfx_placeholder_projectile_path": "res://art/battle/vfx/core_projectile_path.png",
		"vfx_placeholder_damage_tick": "res://art/battle/vfx/core_damage_impact.png",
		"vfx_placeholder_melee_arc": "res://art/battle/vfx/core_melee_arc.png",
		"vfx_placeholder_retaliation_arc": "res://art/battle/vfx/core_retaliation_arc.png",
		"vfx_placeholder_cast_anchor": "res://art/battle/vfx/core_cast_anchor.png",
		"vfx_placeholder_status_residue": "res://art/battle/vfx/core_status_residue.png",
		"vfx_placeholder_status_clear": "res://art/battle/vfx/core_status_clear.png",
		"vfx_placeholder_brace_outline": "res://art/battle/vfx/core_brace_outline.png",
	}
	var render_modes := {
		"vfx_placeholder_projectile_path": "projectile",
		"vfx_placeholder_damage_tick": "impact",
		"vfx_placeholder_melee_arc": "slash",
		"vfx_placeholder_retaliation_arc": "slash",
		"vfx_placeholder_cast_anchor": "ward",
		"vfx_placeholder_status_residue": "ward",
		"vfx_placeholder_status_clear": "ward",
		"vfx_placeholder_brace_outline": "ward",
	}
	var cue_ids: Array = cue_paths.keys()
	var session := _basic_session("unit_river_guard", "unit_bog_brute", 3, 3, 7, 3)
	var view := BattleBoardViewScript.new()
	view.size = Vector2(960.0, 540.0)
	add_child(view)
	view.set_battle_state(session)
	_install_validation_vfx_cues(view, cue_ids)
	var playback: Dictionary = view.validation_vfx_playback_summary()
	_expect_int("core semantic vfx live cue draw count", int(playback.get("active_vfx_draw_count", -1)), cue_ids.size())
	_expect_int("core semantic vfx imported asset draw count", int(playback.get("imported_asset_draw_count", -1)), cue_ids.size())
	_expect_int("core semantic vfx procedural fallback draw count", int(playback.get("procedural_fallback_draw_count", -1)), 0)
	for cue_id_value in cue_ids:
		var cue_id := String(cue_id_value)
		var entry := _vfx_entry_for_cue(playback, cue_id)
		_expect_equal("core semantic vfx imported %s" % cue_id, str(bool(entry.get("asset_loaded", false))), "true")
		_expect_equal("core semantic vfx asset path %s" % cue_id, String(entry.get("asset_path", "")), String(cue_paths.get(cue_id, "")))
		_expect_equal("core semantic vfx render mode %s" % cue_id, String(entry.get("asset_render_mode", "")), String(render_modes.get(cue_id, "")))
	view.queue_free()
	var fallback_view := BattleBoardViewScript.new()
	fallback_view.size = Vector2(960.0, 540.0)
	add_child(fallback_view)
	fallback_view.set_battle_state(session)
	fallback_view.set("_battle_vfx_manifest_loaded", true)
	fallback_view.set("_battle_vfx_manifest", {"schema_id": "battle_vfx_manifest_v1", "cues": {}})
	_install_validation_vfx_cues(fallback_view, ["vfx_placeholder_projectile_path"])
	var fallback_playback: Dictionary = fallback_view.validation_vfx_playback_summary()
	var fallback_entry := _vfx_entry_for_cue(fallback_playback, "vfx_placeholder_projectile_path")
	_expect_equal("core semantic vfx missing mapping fallback kind", String(fallback_entry.get("kind", "")), "projectile_path")
	_expect_equal("core semantic vfx missing mapping asset absent", str(bool(fallback_entry.get("asset_loaded", true))), "false")
	_expect_int("core semantic vfx missing mapping procedural count", int(fallback_playback.get("procedural_fallback_draw_count", 0)), 1)
	fallback_view.queue_redraw()
	fallback_view.queue_free()
	_report["cases"]["core_vfx_semantic_surface"] = {
		"imported": playback,
		"procedural_fallback": fallback_playback,
	}

func _validate_spell_vfx_asset_surface() -> void:
	var cue_paths := {
		"vfx_spell_cinder_burst": "res://art/battle/vfx/spell_cinder_burst.png",
		"vfx_spell_coal_rain": "res://art/battle/vfx/spell_coal_rain.png",
		"vfx_spell_sunlance_arc": "res://art/battle/vfx/spell_sunlance_arc.png",
		"vfx_spell_briar_bind": "res://art/battle/vfx/spell_briar_bind.png",
		"vfx_spell_graft_mend": "res://art/battle/vfx/spell_graft_mend.png",
		"vfx_spell_prism_bastion": "res://art/battle/vfx/spell_prism_bastion.png",
		"vfx_spell_resonant_chorus": "res://art/battle/vfx/spell_resonant_chorus.png",
		"vfx_spell_command_ward": "res://art/battle/vfx/spell_command_ward.png",
	}
	var cue_ids: Array = cue_paths.keys()
	var session := _basic_session("unit_river_guard", "unit_bog_brute", 3, 3, 7, 3)
	var view := BattleBoardViewScript.new()
	view.size = Vector2(960.0, 540.0)
	add_child(view)
	view.set_battle_state(session)
	_install_validation_vfx_cues(view, cue_ids)
	var playback: Dictionary = view.validation_vfx_playback_summary()
	_expect_int("spell vfx live cue draw count", int(playback.get("active_vfx_draw_count", -1)), cue_ids.size())
	_expect_int("spell vfx imported asset draw count", int(playback.get("imported_asset_draw_count", -1)), cue_ids.size())
	_expect_int("spell vfx procedural fallback draw count", int(playback.get("procedural_fallback_draw_count", -1)), 0)
	for cue_id_value in cue_ids:
		var cue_id := String(cue_id_value)
		var entry := _vfx_entry_for_cue(playback, cue_id)
		_expect_equal("spell vfx imported %s" % cue_id, str(bool(entry.get("asset_loaded", false))), "true")
		_expect_equal("spell vfx asset path %s" % cue_id, String(entry.get("asset_path", "")), String(cue_paths.get(cue_id, "")))
		var expected_render_mode := "spell_projectile" if cue_id == "vfx_spell_sunlance_arc" else "spell_target"
		_expect_equal("spell vfx render mode %s" % cue_id, String(entry.get("asset_render_mode", "")), expected_render_mode)
	var resonant_metrics := _vfx_image_metrics("res://art/battle/vfx/spell_resonant_chorus.png")
	var prism_metrics := _vfx_image_metrics("res://art/battle/vfx/spell_prism_bastion.png")
	_expect_equal("resonant chorus vfx image loaded", str(bool(resonant_metrics.get("loaded", false))), "true")
	_expect_equal("resonant chorus vfx image size", JSON.stringify(resonant_metrics.get("size", [])), "[384,384]")
	_expect_equal("resonant chorus vfx transparent corners", str(bool(resonant_metrics.get("transparent_corners", false))), "true")
	var resonant_alpha_coverage := float(resonant_metrics.get("alpha_coverage", 0.0))
	if resonant_alpha_coverage < 0.20 or resonant_alpha_coverage > 0.80:
		_error("Resonant Chorus VFX alpha coverage is outside the isolated-effect range: %s." % resonant_metrics)
	if String(resonant_metrics.get("sha256", "")) == "" or String(resonant_metrics.get("sha256", "")) == String(prism_metrics.get("sha256", "")):
		_error("Resonant Chorus VFX must retain a distinct nonempty asset hash: resonant=%s prism=%s." % [resonant_metrics, prism_metrics])
	view.queue_free()
	var fallback_view := BattleBoardViewScript.new()
	fallback_view.size = Vector2(960.0, 540.0)
	add_child(fallback_view)
	fallback_view.set_battle_state(session)
	fallback_view.set("_battle_vfx_manifest_loaded", true)
	fallback_view.set("_battle_vfx_manifest", {"schema_id": "battle_vfx_manifest_v1", "cues": {}})
	_install_validation_vfx_cues(fallback_view, ["vfx_spell_cinder_burst"])
	var fallback_playback: Dictionary = fallback_view.validation_vfx_playback_summary()
	var fallback_entry := _vfx_entry_for_cue(fallback_playback, "vfx_spell_cinder_burst")
	_expect_equal("spell vfx missing mapping fallback kind", String(fallback_entry.get("kind", "")), "spell_cinder_burst")
	_expect_equal("spell vfx missing mapping asset absent", str(bool(fallback_entry.get("asset_loaded", true))), "false")
	_expect_int("spell vfx missing mapping procedural count", int(fallback_playback.get("procedural_fallback_draw_count", 0)), 1)
	fallback_view.queue_redraw()
	fallback_view.queue_free()
	_report["cases"]["spell_vfx_assets"] = {
		"imported": playback,
		"procedural_fallback": fallback_playback,
		"resonant_metrics": resonant_metrics,
		"prism_metrics": prism_metrics,
	}

func _validate_production_sfx_asset_surface() -> void:
	var expected_audio_ids := [
		"audio_placeholder_ranged_release",
		"audio_placeholder_status_apply",
		"audio_placeholder_melee_release",
		"audio_placeholder_hit",
		"audio_placeholder_unit_rout",
		"audio_placeholder_cast",
		"audio_placeholder_unit_step",
		"audio_placeholder_defend",
		"audio_placeholder_retaliation",
		"audio_placeholder_retreat_order",
		"audio_placeholder_surrender_order",
		"audio_placeholder_turn_ready",
		"audio_placeholder_status_clear",
		"audio_placeholder_idle_soft",
		"audio_spell_cinder_burst",
		"audio_spell_coal_rain",
		"audio_spell_sunlance_arc",
		"audio_spell_briar_bind",
		"audio_spell_graft_mend",
		"audio_spell_prism_bastion",
		"audio_spell_resonant_chorus",
		"audio_spell_command_ward",
	]
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://content/battle_sfx_manifest.json"))
	if not (parsed is Dictionary):
		_error("Battle production SFX manifest did not parse as a Dictionary: %s" % parsed)
		return
	var manifest: Dictionary = parsed
	_expect_equal("battle production sfx manifest schema", String(manifest.get("schema", "")), "battle_runtime_sfx_manifest_v1")
	_expect_int("battle production sfx sample rate", int(manifest.get("sample_rate_hz", 0)), 44100)
	_expect_int("battle production sfx channel count", int(manifest.get("channel_count", 0)), 2)
	_expect_int("battle production sfx sample width", int(manifest.get("sample_width_bits", 0)), 16)
	_expect_equal("battle production sfx asset tier", String(manifest.get("asset_tier", "")), "production_layered_v1")
	_expect_equal("battle production sfx final approval remains open", str(bool(manifest.get("final_sound_design", true))), "false")
	var cues: Dictionary = manifest.get("cues", {}) if manifest.get("cues", {}) is Dictionary else {}
	var observed_audio_ids: Array = cues.keys()
	observed_audio_ids.sort()
	expected_audio_ids.sort()
	_expect_equal("battle production sfx exact cue ids", JSON.stringify(observed_audio_ids), JSON.stringify(expected_audio_ids))
	var view := BattleBoardViewScript.new()
	add_child(view)
	var playbacks := {}
	for audio_id_value in expected_audio_ids:
		var audio_id := String(audio_id_value)
		var cue: Dictionary = cues.get(audio_id, {}) if cues.get(audio_id, {}) is Dictionary else {}
		var path := String(cue.get("path", ""))
		if not ResourceLoader.exists(path):
			_error("Battle production SFX resource does not exist for %s: %s" % [audio_id, path])
			continue
		var stream = load(path)
		if not (stream is AudioStreamWAV):
			_error("Battle production SFX resource is not AudioStreamWAV for %s: %s" % [audio_id, stream])
			continue
		_expect_int("battle production sfx live sample rate %s" % audio_id, int(stream.mix_rate), 44100)
		_expect_equal("battle production sfx live stereo %s" % audio_id, str(bool(stream.stereo)), "true")
		view.validation_reset_audio_mix()
		var playback: Dictionary = view.validation_play_audio_cue(audio_id, "production_%s" % audio_id, 1)
		_expect_equal("battle production sfx imported source %s" % audio_id, String(playback.get("source", "")), "imported_wav")
		_expect_equal("battle production sfx asset path %s" % audio_id, String(playback.get("asset_path", "")), path)
		_expect_equal("battle production sfx role %s" % audio_id, String(playback.get("role", "")), String(cue.get("role", "")))
		_expect_int("battle production sfx duration %s" % audio_id, int(playback.get("duration_msec", 0)), int(cue.get("duration_msec", 0)))
		_expect_equal("battle production sfx priority %s" % audio_id, String(playback.get("priority_class", "")), String(cue.get("priority_class", "")))
		_expect_int("battle production sfx cooldown %s" % audio_id, int(playback.get("repeat_cooldown_msec", 0)), int(cue.get("repeat_cooldown_msec", 0)))
		_expect_equal("battle production sfx played %s" % audio_id, str(bool(playback.get("played", false))), "true")
		playbacks[audio_id] = playback
	view.validation_reset_audio_mix()
	view.set("_battle_sfx_manifest_loaded", true)
	view.set("_battle_sfx_manifest", {"schema": "battle_runtime_sfx_manifest_v1", "cues": {}})
	var fallback: Dictionary = view.validation_play_audio_cue("audio_placeholder_hit", "production_fallback", 2)
	_expect_equal("battle production sfx missing mapping fallback source", String(fallback.get("source", "")), "generated_waveform")
	_expect_equal("battle production sfx missing mapping fallback played", str(bool(fallback.get("played", false))), "true")
	view.validation_reset_audio_mix()
	view.queue_free()
	_report["cases"]["production_sfx_assets"] = {
		"cue_count": expected_audio_ids.size(),
		"playbacks": playbacks,
		"generated_fallback": fallback,
	}

func _validate_state_path_vfx_asset_surface() -> void:
	var cue_paths := {
		"vfx_placeholder_idle_shadow": "res://art/battle/vfx/state_idle_shadow.png",
		"vfx_placeholder_active_ring": "res://art/battle/vfx/state_active_ring.png",
		"vfx_placeholder_stack_fade": "res://art/battle/vfx/state_stack_fade.png",
		"vfx_placeholder_surrender_marker": "res://art/battle/vfx/state_surrender_marker.png",
		"vfx_placeholder_battle_path_ghost": "res://art/battle/vfx/path_move_ghost.png",
		"vfx_placeholder_withdraw_path": "res://art/battle/vfx/path_withdraw_ghost.png",
	}
	var cue_ids: Array = cue_paths.keys()
	var session := _basic_session("unit_river_guard", "unit_bog_brute", 3, 3, 7, 3)
	var view := BattleBoardViewScript.new()
	view.size = Vector2(960.0, 540.0)
	add_child(view)
	view.set_battle_state(session)
	_install_validation_vfx_cues(view, cue_ids)
	var playback: Dictionary = view.validation_vfx_playback_summary()
	_expect_int("state path vfx live cue draw count", int(playback.get("active_vfx_draw_count", -1)), cue_ids.size())
	_expect_int("state path vfx imported asset draw count", int(playback.get("imported_asset_draw_count", -1)), cue_ids.size())
	_expect_int("state path vfx procedural fallback draw count", int(playback.get("procedural_fallback_draw_count", -1)), 0)
	for cue_id_value in cue_ids:
		var cue_id := String(cue_id_value)
		var entry := _vfx_entry_for_cue(playback, cue_id)
		_expect_equal("state path vfx imported %s" % cue_id, str(bool(entry.get("asset_loaded", false))), "true")
		_expect_equal("state path vfx asset path %s" % cue_id, String(entry.get("asset_path", "")), String(cue_paths.get(cue_id, "")))
		var expected_render_mode := "state_center"
		if cue_id in ["vfx_placeholder_battle_path_ghost", "vfx_placeholder_withdraw_path"]:
			expected_render_mode = "path_follow"
		elif cue_id == "vfx_placeholder_surrender_marker":
			expected_render_mode = "state_marker"
		_expect_equal("state path vfx render mode %s" % cue_id, String(entry.get("asset_render_mode", "")), expected_render_mode)
	view.queue_free()
	var fallback_view := BattleBoardViewScript.new()
	fallback_view.size = Vector2(960.0, 540.0)
	add_child(fallback_view)
	fallback_view.set_battle_state(session)
	fallback_view.set("_battle_vfx_manifest_loaded", true)
	fallback_view.set("_battle_vfx_manifest", {"schema_id": "battle_vfx_manifest_v1", "cues": {}})
	_install_validation_vfx_cues(fallback_view, ["vfx_placeholder_stack_fade"])
	var fallback_playback: Dictionary = fallback_view.validation_vfx_playback_summary()
	var fallback_entry := _vfx_entry_for_cue(fallback_playback, "vfx_placeholder_stack_fade")
	_expect_equal("state path vfx missing mapping fallback kind", String(fallback_entry.get("kind", "")), "stack_fade")
	_expect_equal("state path vfx missing mapping asset absent", str(bool(fallback_entry.get("asset_loaded", true))), "false")
	_expect_int("state path vfx missing mapping procedural count", int(fallback_playback.get("procedural_fallback_draw_count", 0)), 1)
	fallback_view.queue_redraw()
	fallback_view.queue_free()
	_report["cases"]["state_path_vfx_assets"] = {
		"imported": playback,
		"procedural_fallback": fallback_playback,
	}

func _validate_defend_state() -> void:
	var session := _basic_session("unit_river_guard", "unit_bog_brute", 4, 3, 5, 3)
	var result := BattleRulesScript.perform_player_action(session, "defend")
	var state := _state_for(session, "player_0")
	_expect_ok("defend action", result)
	_expect_equal("defend animation state", state, "defend_brace")
	_expect_event("defend queue", session.battle, "player_0", "battle_unit_defend", "defend_brace")
	var board_summary := _board_summary_for_session(session)
	var vfx_playback: Dictionary = board_summary.get("vfx_playback", {}) if board_summary.get("vfx_playback", {}) is Dictionary else {}
	var brace_vfx := _vfx_entry_for(vfx_playback, "brace_outline")
	_expect_equal("defend brace vfx cue", String(brace_vfx.get("cue_id", "")), "vfx_placeholder_brace_outline")
	_expect_equal("defend brace vfx battle id", String(brace_vfx.get("battle_id", "")), "player_0")
	_expect_equal("defend brace imported vfx", str(bool(brace_vfx.get("asset_loaded", false))), "true")
	_expect_equal("defend brace vfx asset path", String(brace_vfx.get("asset_path", "")), "res://art/battle/vfx/core_brace_outline.png")
	_report["cases"]["defend"] = {
		"state": state,
		"events": BattleRulesScript.animation_event_states(session.battle),
		"queue": BattleRulesScript.animation_event_queue(session.battle),
		"board_vfx": vfx_playback,
	}

func _validate_move_state() -> void:
	var session := _basic_session("unit_river_guard", "unit_bog_brute", 0, 3, 7, 3)
	var destinations: Array = BattleRulesScript.legal_destinations_for_active_stack(session.battle)
	if destinations.is_empty():
		_error("Move case has no legal destinations.")
		return
	var destination: Dictionary = destinations[0]
	var result := BattleRulesScript.move_active_stack_to_hex(session, int(destination.get("q", 0)), int(destination.get("r", 0)))
	var state := _state_for(session, "player_0")
	_expect_ok("move action", result)
	_expect_equal("move animation state", state, "move_path_step")
	_expect_event("move queue", session.battle, "player_0", "battle_unit_move", "move_path_step")
	var move_event := _event_record_for(session.battle, "player_0", "battle_unit_move")
	_expect_equal("move event from q", str(int(move_event.get("from_q", -1))), "0")
	_expect_equal("move event from r", str(int(move_event.get("from_r", -1))), "3")
	_expect_equal("move event to q", str(int(move_event.get("to_q", -1))), str(int(destination.get("q", -1))))
	_expect_equal("move event to r", str(int(move_event.get("to_r", -1))), str(int(destination.get("r", -1))))
	var board_summary := _board_summary_for_session(session)
	var vfx_playback: Dictionary = board_summary.get("vfx_playback", {}) if board_summary.get("vfx_playback", {}) is Dictionary else {}
	var path := _vfx_entry_for(vfx_playback, "path_ghost")
	_expect_equal("move path ghost cue", String(path.get("cue_id", "")), "vfx_placeholder_battle_path_ghost")
	_expect_equal("move path ghost imported vfx", str(bool(path.get("asset_loaded", false))), "true")
	_expect_equal("move path ghost imported asset", String(path.get("asset_path", "")), "res://art/battle/vfx/path_move_ghost.png")
	if int(path.get("start_q", -1)) == int(path.get("target_q", -1)) and int(path.get("start_r", -1)) == int(path.get("target_r", -1)):
		_error("Move path ghost did not span distinct source and destination cells: %s" % path)
	var moving_stack := _summary_stack_entry(board_summary, "player_0")
	_expect_equal("move token presentation motion active", str(bool(moving_stack.get("presentation_motion_active", false))), "true")
	_expect_equal("move token presentation event", String(moving_stack.get("presentation_motion_event_id", "")), "battle_unit_move")
	_expect_equal("move token presentation from q", str(int(moving_stack.get("presentation_motion_from_q", -1))), "0")
	_expect_equal("move token presentation from r", str(int(moving_stack.get("presentation_motion_from_r", -1))), "3")
	_expect_equal("move token presentation to q", str(int(moving_stack.get("presentation_motion_to_q", -1))), str(int(destination.get("q", -1))))
	_expect_equal("move token presentation to r", str(int(moving_stack.get("presentation_motion_to_r", -1))), str(int(destination.get("r", -1))))
	if float(moving_stack.get("presentation_motion_progress", 1.0)) >= 1.0:
		_error("Move token presentation progress was already complete during active playback: %s." % moving_stack)
	var presentation_x := float(moving_stack.get("presentation_x", 0.0))
	var start_x := float(path.get("start_x", 0.0))
	var end_x := float(path.get("end_x", 0.0))
	if presentation_x < minf(start_x, end_x) - 0.5 or presentation_x > maxf(start_x, end_x) + 0.5:
		_error("Move token presentation center left the event path: stack=%s path=%s." % [moving_stack, path])
	if absf(presentation_x - end_x) <= 1.0:
		_error("Move token presentation snapped directly to destination instead of animating along the event path: stack=%s path=%s." % [moving_stack, path])
	_report["cases"]["move"] = {
		"state": state,
		"destination": destination,
		"events": BattleRulesScript.animation_event_states(session.battle),
		"queue": BattleRulesScript.animation_event_queue(session.battle),
		"board_vfx": vfx_playback,
		"board_stack": moving_stack,
	}

func _validate_melee_hit_state() -> void:
	var session := _basic_session("unit_river_guard", "unit_bog_brute", 4, 3, 5, 3)
	_set_stack_field(session.battle, "enemy_0", "retaliations_left", 0)
	_set_stack_field(session.battle, "enemy_0", "total_health", 999)
	var result := BattleRulesScript.perform_player_action(session, "strike")
	var attacker_state := _state_for(session, "player_0")
	var target_state := _state_for(session, "enemy_0")
	_expect_ok("melee strike action", result)
	_expect_equal("melee attacker animation state", attacker_state, "melee_windup_release")
	_expect_equal("melee target animation state", target_state, "hit_stagger")
	_expect_event("melee attacker queue", session.battle, "player_0", "battle_unit_melee_attack", "melee_windup_release")
	_expect_event("melee target queue", session.battle, "enemy_0", "battle_unit_hit", "hit_stagger")
	await get_tree().create_timer(0.08).timeout
	var board_summary := _board_summary_for_session(session)
	var attacker_stack := _summary_stack_entry(board_summary, "player_0")
	var target_stack := _summary_stack_entry(board_summary, "enemy_0")
	_expect_equal("melee attacker presentation active", str(bool(attacker_stack.get("presentation_motion_active", false))), "true")
	_expect_equal("melee attacker presentation role", String(attacker_stack.get("presentation_motion_role", "")), "melee_lunge")
	_expect_equal("melee attacker presentation target", String(attacker_stack.get("presentation_motion_target_battle_id", "")), "enemy_0")
	_expect_equal("hit target presentation active", str(bool(target_stack.get("presentation_motion_active", false))), "true")
	_expect_equal("hit target presentation role", String(target_stack.get("presentation_motion_role", "")), "hit_stagger")
	_expect_equal("hit target presentation source", String(target_stack.get("presentation_motion_source_battle_id", "")), "player_0")
	var vfx_playback: Dictionary = board_summary.get("vfx_playback", {}) if board_summary.get("vfx_playback", {}) is Dictionary else {}
	var melee_arc := _vfx_entry_for(vfx_playback, "melee_arc")
	_expect_equal("melee imported vfx", str(bool(melee_arc.get("asset_loaded", false))), "true")
	_expect_equal("melee vfx asset path", String(melee_arc.get("asset_path", "")), "res://art/battle/vfx/core_melee_arc.png")
	if float(attacker_stack.get("presentation_x", 0.0)) <= float(melee_arc.get("start_x", 0.0)) + 0.05:
		_error("Melee attacker token did not lunge toward the target: attacker=%s melee_arc=%s." % [attacker_stack, melee_arc])
	if float(target_stack.get("presentation_x", 0.0)) <= float(melee_arc.get("end_x", 0.0)) + 0.5:
		_error("Melee target token did not stagger away from the source: target=%s melee_arc=%s." % [target_stack, melee_arc])
	_report["cases"]["melee_hit"] = {
		"attacker_state": attacker_state,
		"target_state": target_state,
		"events": BattleRulesScript.animation_event_states(session.battle),
		"queue": BattleRulesScript.animation_event_queue(session.battle),
		"board_vfx": vfx_playback,
		"attacker_stack": attacker_stack,
		"target_stack": target_stack,
	}

func _validate_retaliation_state() -> void:
	var session := _basic_session("unit_river_guard", "unit_bog_brute", 4, 3, 5, 3)
	_set_stack_field(session.battle, "player_0", "total_health", 999)
	_set_stack_field(session.battle, "enemy_0", "total_health", 999)
	_set_stack_field(session.battle, "enemy_0", "retaliations_left", 1)
	var result := BattleRulesScript.perform_player_action(session, "strike")
	var retaliator_state := _state_for(session, "enemy_0")
	var target_state := _state_for(session, "player_0")
	_expect_ok("retaliation source strike action", result)
	_expect_equal("retaliator animation state", retaliator_state, "retaliation_release")
	_expect_equal("retaliation target animation state", target_state, "hit_stagger")
	_expect_event("retaliator queue", session.battle, "enemy_0", "battle_retaliation", "retaliation_release")
	_expect_event("retaliation target hit queue", session.battle, "player_0", "battle_unit_hit", "hit_stagger")
	var retaliation_event := _event_record_for(session.battle, "enemy_0", "battle_retaliation")
	_expect_equal("retaliation event target", String(retaliation_event.get("target_battle_id", "")), "player_0")
	var board_summary := _board_summary_for_session(session)
	var retaliator_stack := _summary_stack_entry(board_summary, "enemy_0")
	var target_stack := _summary_stack_entry(board_summary, "player_0")
	_expect_equal("retaliator presentation active", str(bool(retaliator_stack.get("presentation_motion_active", false))), "true")
	_expect_equal("retaliator presentation event", String(retaliator_stack.get("presentation_motion_event_id", "")), "battle_retaliation")
	_expect_equal("retaliator presentation role", String(retaliator_stack.get("presentation_motion_role", "")), "melee_lunge")
	_expect_equal("retaliator presentation target", String(retaliator_stack.get("presentation_motion_target_battle_id", "")), "player_0")
	_expect_equal("retaliation target presentation role", String(target_stack.get("presentation_motion_role", "")), "hit_stagger")
	_expect_equal("retaliation target presentation source", String(target_stack.get("presentation_motion_source_battle_id", "")), "enemy_0")
	var cue_playback: Dictionary = board_summary.get("cue_playback", {}) if board_summary.get("cue_playback", {}) is Dictionary else {}
	var retaliator_cue := _cue_record_for(cue_playback, "enemy_0")
	_expect_array_contains("retaliator cue vfx", retaliator_cue.get("selected_vfx_cue_ids", []), "vfx_placeholder_retaliation_arc")
	_expect_array_contains("retaliator cue audio", retaliator_cue.get("selected_audio_cue_ids", []), "audio_placeholder_retaliation")
	if int(retaliator_cue.get("sequence_delay_msec", 0)) <= 0:
		_error("Retaliation cue did not carry a sequence delay after the initiating hit: %s" % retaliator_cue)
	var vfx_playback: Dictionary = board_summary.get("vfx_playback", {}) if board_summary.get("vfx_playback", {}) is Dictionary else {}
	var retaliation_arc := _vfx_entry_for(vfx_playback, "retaliation_arc")
	_expect_equal("retaliation vfx cue", String(retaliation_arc.get("cue_id", "")), "vfx_placeholder_retaliation_arc")
	_expect_equal("retaliation vfx source", String(retaliation_arc.get("battle_id", "")), "enemy_0")
	_expect_equal("retaliation vfx target", String(retaliation_arc.get("target_battle_id", "")), "player_0")
	_expect_equal("retaliation imported vfx", str(bool(retaliation_arc.get("asset_loaded", false))), "true")
	_expect_equal("retaliation vfx asset path", String(retaliation_arc.get("asset_path", "")), "res://art/battle/vfx/core_retaliation_arc.png")
	var audio_playback: Dictionary = board_summary.get("audio_playback", {}) if board_summary.get("audio_playback", {}) is Dictionary else {}
	var retaliator_audio := _audio_record_for(audio_playback, "enemy_0")
	_expect_array_contains("retaliation audio cue", retaliator_audio.get("selected_audio_cue_ids", []), "audio_placeholder_retaliation")
	var motion_roles: Dictionary = board_summary.get("presentation_motion_roles", {}) if board_summary.get("presentation_motion_roles", {}) is Dictionary else {}
	if int(motion_roles.get("melee_lunge", 0)) < 1 or int(motion_roles.get("hit_stagger", 0)) < 1:
		_error("Retaliation presentation roles were not counted in the board summary: %s" % board_summary)
	_report["cases"]["retaliation"] = {
		"retaliator_state": retaliator_state,
		"target_state": target_state,
		"events": BattleRulesScript.animation_event_states(session.battle),
		"queue": BattleRulesScript.animation_event_queue(session.battle),
		"board_stack": retaliator_stack,
		"target_stack": target_stack,
		"board_cue": cue_playback,
		"board_vfx": vfx_playback,
		"board_audio": audio_playback,
		"presentation_motion_roles": motion_roles,
	}

func _validate_ranged_status_state() -> void:
	var session := _basic_session("unit_mire_slinger", "unit_bog_brute", 1, 3, 7, 3)
	_set_stack_field(session.battle, "enemy_0", "total_health", 999)
	var result := BattleRulesScript.perform_player_action(session, "shoot")
	var attacker_state := _state_for(session, "player_0")
	var target_state := _state_for(session, "enemy_0")
	_expect_ok("ranged shoot action", result)
	_expect_equal("ranged attacker animation state", attacker_state, "ranged_aim_release")
	_expect_equal("ranged target status animation state", target_state, "status_applied")
	_expect_event("ranged attacker queue", session.battle, "player_0", "battle_unit_ranged_attack", "ranged_aim_release")
	_expect_event("ranged target status queue", session.battle, "enemy_0", "battle_status_applied", "status_applied")
	await get_tree().create_timer(0.08).timeout
	var board_summary := _board_summary_for_session(session)
	var attacker_stack := _summary_stack_entry(board_summary, "player_0")
	var target_stack := _summary_stack_entry(board_summary, "enemy_0")
	var motion_count := int(board_summary.get("presentation_motion_count", 0))
	var motion_roles: Dictionary = board_summary.get("presentation_motion_roles", {}) if board_summary.get("presentation_motion_roles", {}) is Dictionary else {}
	_expect_equal("ranged attacker presentation role", String(attacker_stack.get("presentation_motion_role", "")), "ranged_recoil")
	_expect_equal("ranged attacker presentation target", String(attacker_stack.get("presentation_motion_target_battle_id", "")), "enemy_0")
	_expect_equal("ranged target presentation role", String(target_stack.get("presentation_motion_role", "")), "status_pulse")
	_expect_equal("ranged target presentation source", String(target_stack.get("presentation_motion_source_battle_id", "")), "player_0")
	if motion_count < 2:
		_error("Ranged/status presentation motion count was too low: %s." % board_summary)
	if int(motion_roles.get("ranged_recoil", 0)) < 1 or int(motion_roles.get("status_pulse", 0)) < 1:
		_error("Ranged/status presentation roles were not counted in board summary: %s." % board_summary)
	var case_payload := {
		"attacker_state": attacker_state,
		"target_state": target_state,
		"events": BattleRulesScript.animation_event_states(session.battle),
		"queue": BattleRulesScript.animation_event_queue(session.battle),
	}
	case_payload["attacker_presentation_role"] = String(attacker_stack.get("presentation_motion_role", ""))
	case_payload["attacker_presentation_target"] = String(attacker_stack.get("presentation_motion_target_battle_id", ""))
	case_payload["target_presentation_role"] = String(target_stack.get("presentation_motion_role", ""))
	case_payload["target_presentation_source"] = String(target_stack.get("presentation_motion_source_battle_id", ""))
	case_payload["presentation_motion_count"] = motion_count
	case_payload["presentation_motion_roles"] = motion_roles
	_report["cases"]["ranged_status"] = case_payload

func _validate_death_state() -> void:
	var session := _session_for_stacks(
		[
			_stack("unit_river_guard", "player", 0, "player_0", 8, 4, 3),
			_stack("unit_bog_brute", "enemy", 0, "enemy_0", 1, 5, 3),
			_stack("unit_bog_brute", "enemy", 1, "enemy_1", 8, 7, 3),
		],
		"player_0",
		"enemy_0"
	)
	_set_stack_field(session.battle, "enemy_0", "retaliations_left", 0)
	_set_stack_field(session.battle, "enemy_0", "total_health", 1)
	var result := BattleRulesScript.perform_player_action(session, "strike")
	var target_state := _state_for(session, "enemy_0")
	_expect_ok("death strike action", result)
	_expect_equal("death target animation state", target_state, "death_rout_remove")
	_expect_event("death target queue", session.battle, "enemy_0", "battle_unit_death", "death_rout_remove")
	var board_summary := _board_summary_for_session(session)
	var observed_states := _observed_animation_states(board_summary)
	var death_stack := _summary_stack_entry(board_summary, "enemy_0")
	var vfx_playback: Dictionary = board_summary.get("vfx_playback", {}) if board_summary.get("vfx_playback", {}) is Dictionary else {}
	var fade := _vfx_entry_for(vfx_playback, "stack_fade")
	_expect_equal("death board target animation state", String(observed_states.get("enemy_0", "")), "death_rout_remove")
	if int(death_stack.get("alive_count", -1)) != 0:
		_error("Death board summary should retain the defeated stack with alive_count 0: %s" % death_stack)
	if not bool(death_stack.get("event_playback_visible", false)):
		_error("Death board summary did not mark the defeated stack as event-playback visible: %s" % death_stack)
	_expect_equal("death target presentation role", String(death_stack.get("presentation_motion_role", "")), "death_fall_back")
	_expect_equal("death target presentation source", String(death_stack.get("presentation_motion_source_battle_id", "")), "player_0")
	_expect_equal("death fade vfx cue", String(fade.get("cue_id", "")), "vfx_placeholder_stack_fade")
	_expect_equal("death fade vfx battle id", String(fade.get("battle_id", "")), "enemy_0")
	_expect_equal("death fade imported vfx", str(bool(fade.get("asset_loaded", false))), "true")
	_expect_equal("death fade imported asset", String(fade.get("asset_path", "")), "res://art/battle/vfx/state_stack_fade.png")
	_report["cases"]["death"] = {
		"target_state": target_state,
		"events": BattleRulesScript.animation_event_states(session.battle),
		"queue": BattleRulesScript.animation_event_queue(session.battle),
		"board_states": observed_states,
		"board_stack": death_stack,
		"board_vfx": vfx_playback,
	}

func _validate_spell_cast_state() -> void:
	var session := _basic_session("unit_river_guard", "unit_bog_brute", 4, 3, 6, 3)
	session.battle["turn_order"] = ["player_0", "player_0"]
	session.battle["player_commander_state"] = _spellcaster_state()
	_set_stack_field(session.battle, "enemy_0", "total_health", 999)
	var result := BattleRulesScript.cast_player_spell(session, "spell_cinder_burst")
	var caster_state := _state_for(session, "player_0")
	var target_state := _state_for(session, "enemy_0")
	_expect_ok("spell cast action", result)
	_expect_equal("spell caster animation state", caster_state, "cast_support_anchor")
	_expect_equal("spell target animation state", target_state, "status_applied")
	_expect_event("spell caster queue", session.battle, "player_0", "battle_unit_cast", "cast_support_anchor")
	_expect_event("spell target queue", session.battle, "enemy_0", "battle_status_applied", "status_applied")
	await get_tree().create_timer(0.08).timeout
	var board_summary := _board_summary_for_session(session)
	var caster_stack := _summary_stack_entry(board_summary, "player_0")
	var target_stack := _summary_stack_entry(board_summary, "enemy_0")
	var motion_count := int(board_summary.get("presentation_motion_count", 0))
	var motion_roles: Dictionary = board_summary.get("presentation_motion_roles", {}) if board_summary.get("presentation_motion_roles", {}) is Dictionary else {}
	_expect_equal("spell caster presentation role", String(caster_stack.get("presentation_motion_role", "")), "cast_anchor")
	_expect_equal("spell caster presentation target", String(caster_stack.get("presentation_motion_target_battle_id", "")), "enemy_0")
	_expect_equal("spell target presentation role", String(target_stack.get("presentation_motion_role", "")), "status_pulse")
	_expect_equal("spell target presentation source", String(target_stack.get("presentation_motion_source_battle_id", "")), "player_0")
	if motion_count < 2:
		_error("Spell/status presentation motion count was too low: %s." % board_summary)
	if int(motion_roles.get("cast_anchor", 0)) < 1 or int(motion_roles.get("status_pulse", 0)) < 1:
		_error("Spell/status presentation roles were not counted in board summary: %s." % board_summary)
	var caster_event := _event_record_for(session.battle, "player_0", "battle_unit_cast")
	var target_event := _event_record_for(session.battle, "enemy_0", "battle_status_applied")
	_expect_equal("spell caster event spell id", String(caster_event.get("spell_id", "")), "spell_cinder_burst")
	_expect_equal("spell target event spell id", String(target_event.get("spell_id", "")), "spell_cinder_burst")
	var cue_playback: Dictionary = board_summary.get("cue_playback", {}) if board_summary.get("cue_playback", {}) is Dictionary else {}
	var caster_cue := _cue_record_for(cue_playback, "player_0")
	_expect_array_contains("spell caster cue vfx", caster_cue.get("selected_vfx_cue_ids", []), "vfx_spell_cinder_burst")
	_expect_array_contains("spell caster cue audio", caster_cue.get("selected_audio_cue_ids", []), "audio_spell_cinder_burst")
	_expect_array_contains("spell caster generic vfx fallback", caster_cue.get("selected_vfx_cue_ids", []), "vfx_placeholder_cast_anchor")
	_expect_array_contains("spell caster generic audio fallback", caster_cue.get("selected_audio_cue_ids", []), "audio_placeholder_cast")
	var vfx_playback: Dictionary = board_summary.get("vfx_playback", {}) if board_summary.get("vfx_playback", {}) is Dictionary else {}
	var cast_anchor_vfx := _vfx_entry_for(vfx_playback, "cast_anchor")
	_expect_equal("cast anchor imported vfx", str(bool(cast_anchor_vfx.get("asset_loaded", false))), "true")
	_expect_equal("cast anchor vfx asset path", String(cast_anchor_vfx.get("asset_path", "")), "res://art/battle/vfx/core_cast_anchor.png")
	var spell_vfx := _vfx_entry_for(vfx_playback, "spell_cinder_burst")
	_expect_equal("spell-specific vfx cue", String(spell_vfx.get("cue_id", "")), "vfx_spell_cinder_burst")
	_expect_equal("spell-specific imported vfx", str(bool(spell_vfx.get("asset_loaded", false))), "true")
	_expect_equal("spell-specific imported asset", String(spell_vfx.get("asset_path", "")), "res://art/battle/vfx/spell_cinder_burst.png")
	var audio_playback: Dictionary = board_summary.get("audio_playback", {}) if board_summary.get("audio_playback", {}) is Dictionary else {}
	var caster_audio := _audio_record_for(audio_playback, "player_0")
	_expect_array_contains("spell caster runtime audio", caster_audio.get("selected_audio_cue_ids", []), "audio_spell_cinder_burst")
	if String(_audio_asset_path_for(caster_audio, "audio_spell_cinder_burst")).find("spell_cinder_burst.wav") < 0:
		_error("Spell-specific audio did not use the imported Cinder Burst runtime WAV asset: %s" % caster_audio)
	var case_payload := {
		"caster_state": caster_state,
		"target_state": target_state,
		"events": BattleRulesScript.animation_event_states(session.battle),
		"queue": BattleRulesScript.animation_event_queue(session.battle),
	}
	case_payload["caster_presentation_role"] = String(caster_stack.get("presentation_motion_role", ""))
	case_payload["caster_presentation_target"] = String(caster_stack.get("presentation_motion_target_battle_id", ""))
	case_payload["target_presentation_role"] = String(target_stack.get("presentation_motion_role", ""))
	case_payload["target_presentation_source"] = String(target_stack.get("presentation_motion_source_battle_id", ""))
	case_payload["presentation_motion_count"] = motion_count
	case_payload["presentation_motion_roles"] = motion_roles
	case_payload["spell_specific_caster_cue"] = caster_cue
	case_payload["spell_specific_vfx"] = spell_vfx
	case_payload["spell_specific_audio"] = caster_audio
	_report["cases"]["spell_cast"] = case_payload

func _validate_resonant_chorus_vfx_identity() -> void:
	SettingsService.ensure_settings()
	var original_reduce_motion := SettingsService.reduced_motion_enabled()
	var original_reduce_flashes := SettingsService.reduced_flashes_enabled()
	var spell_before: Dictionary = ContentService.get_spell("spell_resonant_chorus").duplicate(true)
	var normal: Dictionary = await _resonant_chorus_policy_case(false, false)
	var reduced_motion: Dictionary = await _resonant_chorus_policy_case(true, false)
	var reduced_flash: Dictionary = await _resonant_chorus_policy_case(false, true)
	SettingsService.settings["accessibility"]["reduce_motion"] = original_reduce_motion
	SettingsService.settings["accessibility"]["reduce_flashes"] = original_reduce_flashes
	var spell_after: Dictionary = ContentService.get_spell("spell_resonant_chorus").duplicate(true)
	_expect_equal("resonant chorus content immutable", JSON.stringify(spell_after), JSON.stringify(spell_before))
	_expect_equal("resonant chorus normal action matches reduced-motion action", JSON.stringify(normal.get("result", {})), JSON.stringify(reduced_motion.get("result", {})))
	_expect_equal("resonant chorus normal action matches reduced-flash action", JSON.stringify(normal.get("result", {})), JSON.stringify(reduced_flash.get("result", {})))
	_expect_equal("resonant chorus normal authority matches reduced-motion authority", JSON.stringify(normal.get("authority_after_cast", {})), JSON.stringify(reduced_motion.get("authority_after_cast", {})))
	_expect_equal("resonant chorus normal authority matches reduced-flash authority", JSON.stringify(normal.get("authority_after_cast", {})), JSON.stringify(reduced_flash.get("authority_after_cast", {})))
	var normal_cue: Dictionary = normal.get("cue", {}) if normal.get("cue", {}) is Dictionary else {}
	var normal_vfx: Dictionary = normal.get("vfx", {}) if normal.get("vfx", {}) is Dictionary else {}
	var normal_audio: Dictionary = normal.get("audio", {}) if normal.get("audio", {}) is Dictionary else {}
	var normal_audio_playback: Dictionary = normal.get("audio_playback", {}) if normal.get("audio_playback", {}) is Dictionary else {}
	_expect_equal("resonant chorus normal strong-flash policy", str(bool(normal_cue.get("allows_strong_flash", false))), "true")
	_expect_array_contains("resonant chorus normal distinct vfx", normal_cue.get("selected_vfx_cue_ids", []), "vfx_spell_resonant_chorus")
	if normal_cue.get("selected_vfx_cue_ids", []).has("vfx_spell_prism_bastion"):
		_error("Resonant Chorus normal playback retained Prism Bastion visual identity: %s." % normal_cue)
	_expect_equal("resonant chorus normal vfx cue", String(normal_vfx.get("cue_id", "")), "vfx_spell_resonant_chorus")
	_expect_equal("resonant chorus normal vfx kind", String(normal_vfx.get("kind", "")), "spell_resonant_chorus")
	_expect_equal("resonant chorus normal vfx imported", str(bool(normal_vfx.get("asset_loaded", false))), "true")
	_expect_equal("resonant chorus normal vfx asset", String(normal_vfx.get("asset_path", "")), "res://art/battle/vfx/spell_resonant_chorus.png")
	_expect_equal("resonant chorus normal vfx render mode", String(normal_vfx.get("asset_render_mode", "")), "spell_target")
	_expect_array_contains("resonant chorus normal distinct audio", normal_audio.get("selected_audio_cue_ids", []), "audio_spell_resonant_chorus")
	if normal_audio.get("selected_audio_cue_ids", []).has("audio_spell_prism_bastion"):
		_error("Resonant Chorus normal playback retained Prism Bastion audio identity: %s." % normal_audio)
	var normal_resonant_voice := _audio_voice_for(normal_audio_playback, "audio_spell_resonant_chorus")
	_expect_equal("resonant chorus normal imported audio source", String(normal_resonant_voice.get("source", "")), "imported_wav")
	var board := BattleBoardViewScript.new()
	_expect_equal("Prism Bastion visual identity unchanged", String(board.call("_spell_specific_vfx_cue_id", "spell_prism_bastion", "cleanse_effect")), "vfx_spell_prism_bastion")
	_expect_equal("Prism Bastion audio identity unchanged", String(board.call("_spell_specific_audio_cue_id", "spell_prism_bastion", "cleanse_effect")), "audio_spell_prism_bastion")
	_expect_equal("Resonant Chorus distinct audio identity", String(board.call("_spell_specific_audio_cue_id", "spell_resonant_chorus", "effect")), "audio_spell_resonant_chorus")
	board.free()
	for policy_case in [reduced_motion, reduced_flash]:
		var cue: Dictionary = policy_case.get("cue", {}) if policy_case.get("cue", {}) is Dictionary else {}
		var selected_vfx: Array = cue.get("selected_vfx_cue_ids", []) if cue.get("selected_vfx_cue_ids", []) is Array else []
		if selected_vfx.has("vfx_spell_resonant_chorus") or selected_vfx.has("vfx_spell_prism_bastion"):
			_error("Reduced-policy Resonant Chorus playback retained a strong spell-specific visual: %s." % policy_case)
		var audio: Dictionary = policy_case.get("audio", {}) if policy_case.get("audio", {}) is Dictionary else {}
		_expect_array_contains("reduced-policy Resonant Chorus distinct audio", audio.get("selected_audio_cue_ids", []), "audio_spell_resonant_chorus")
		if audio.get("selected_audio_cue_ids", []).has("audio_spell_prism_bastion"):
			_error("Reduced-policy Resonant Chorus playback retained Prism Bastion audio identity: %s." % audio)
		var audio_playback: Dictionary = policy_case.get("audio_playback", {}) if policy_case.get("audio_playback", {}) is Dictionary else {}
		var resonant_voice := _audio_voice_for(audio_playback, "audio_spell_resonant_chorus")
		_expect_equal("reduced-policy Resonant Chorus imported audio source", String(resonant_voice.get("source", "")), "imported_wav")
	_report["cases"]["resonant_chorus_vfx_identity"] = {
		"spell_content": spell_after,
		"normal": normal,
		"reduced_motion": reduced_motion,
		"reduced_flash": reduced_flash,
	}

func _resonant_chorus_policy_case(reduce_motion: bool, reduce_flashes: bool) -> Dictionary:
	SettingsService.settings["accessibility"]["reduce_motion"] = reduce_motion
	SettingsService.settings["accessibility"]["reduce_flashes"] = reduce_flashes
	var session := _basic_session("unit_river_guard", "unit_bog_brute", 4, 3, 6, 3)
	session.battle["turn_order"] = ["player_0", "player_0"]
	session.battle["player_commander_state"] = _spellcaster_state(["spell_resonant_chorus"])
	var result := BattleRulesScript.cast_player_spell(session, "spell_resonant_chorus")
	_expect_ok("resonant chorus policy action", result)
	var cast_event := _event_record_for(session.battle, "player_0", "battle_unit_cast")
	_expect_equal("resonant chorus public cast event spell id", String(cast_event.get("spell_id", "")), "spell_resonant_chorus")
	var authority_after_cast: Dictionary = session.to_dict()
	var summary := await _board_summary_for_session_after_audio(session)
	_expect_equal("resonant chorus presentation preserves session authority", JSON.stringify(session.to_dict()), JSON.stringify(authority_after_cast))
	var cue_playback: Dictionary = summary.get("cue_playback", {}) if summary.get("cue_playback", {}) is Dictionary else {}
	var cue := _cue_record_for(cue_playback, "player_0")
	var vfx_playback: Dictionary = summary.get("vfx_playback", {}) if summary.get("vfx_playback", {}) is Dictionary else {}
	var vfx := _vfx_entry_for_cue(vfx_playback, "vfx_spell_resonant_chorus") if not reduce_motion and not reduce_flashes else {}
	var audio_playback: Dictionary = summary.get("audio_playback", {}) if summary.get("audio_playback", {}) is Dictionary else {}
	var audio := _audio_record_for(audio_playback, "player_0")
	return {
		"reduce_motion": reduce_motion,
		"reduce_flashes": reduce_flashes,
		"result": result.duplicate(true),
		"authority_after_cast": authority_after_cast,
		"cue": cue,
		"vfx": vfx,
		"audio": audio,
		"audio_playback": audio_playback,
		"vfx_playback": vfx_playback,
	}

func _validate_reduced_flash_spell_state() -> void:
	SettingsService.ensure_settings()
	var original_reduce_motion := SettingsService.reduced_motion_enabled()
	var original_reduce_flashes := SettingsService.reduced_flashes_enabled()
	SettingsService.settings["accessibility"]["reduce_motion"] = false
	SettingsService.settings["accessibility"]["reduce_flashes"] = true
	var session := _basic_session("unit_river_guard", "unit_bog_brute", 4, 3, 6, 3)
	session.battle["turn_order"] = ["player_0", "player_0"]
	session.battle["player_commander_state"] = _spellcaster_state()
	_set_stack_field(session.battle, "enemy_0", "total_health", 999)
	var result := BattleRulesScript.cast_player_spell(session, "spell_cinder_burst")
	_expect_ok("reduced-flash spell cast action", result)
	var view := BattleBoardViewScript.new()
	view.size = Vector2(960.0, 540.0)
	add_child(view)
	view.set_battle_state(session)
	await get_tree().process_frame
	await get_tree().create_timer(0.08).timeout
	var summary: Dictionary = view.validation_unit_art_summary()
	view.queue_free()
	await get_tree().process_frame
	SettingsService.settings["accessibility"]["reduce_motion"] = original_reduce_motion
	SettingsService.settings["accessibility"]["reduce_flashes"] = original_reduce_flashes
	var cue_playback: Dictionary = summary.get("cue_playback", {}) if summary.get("cue_playback", {}) is Dictionary else {}
	var caster_cue := _cue_record_for(cue_playback, "player_0")
	var selected_vfx: Array = caster_cue.get("selected_vfx_cue_ids", []) if caster_cue.get("selected_vfx_cue_ids", []) is Array else []
	var selected_audio: Array = caster_cue.get("selected_audio_cue_ids", []) if caster_cue.get("selected_audio_cue_ids", []) is Array else []
	_expect_equal("reduced-flash caster animation state", String(caster_cue.get("selected_animation_state", "")), "cast_support_anchor")
	_expect_equal("reduced-flash caster mode", String(caster_cue.get("mode", "")), "normal")
	_expect_equal("reduced-flash strong-flash policy", str(bool(caster_cue.get("allows_strong_flash", true))), "false")
	_expect_array_contains("reduced-flash static caster cue", selected_vfx, "cast_icon_anchor")
	if selected_vfx.has("vfx_spell_cinder_burst") or selected_vfx.has("vfx_placeholder_cast_anchor"):
		_error("Reduced-flash battle playback retained a strong spell overlay: %s" % caster_cue)
	_expect_array_contains("reduced-flash spell audio", selected_audio, "audio_spell_cinder_burst")
	_expect_array_contains("reduced-flash generic audio", selected_audio, "audio_placeholder_cast")
	var caster_stack := _summary_stack_entry(summary, "player_0")
	_expect_equal("reduced-flash caster motion role", String(caster_stack.get("presentation_motion_role", "")), "cast_anchor")
	_report["cases"]["reduced_flash_spell"] = {
		"cue": caster_cue,
		"stack": caster_stack,
		"vfx_playback": summary.get("vfx_playback", {}),
		"audio_playback": summary.get("audio_playback", {}),
	}

func _validate_status_cleanse_state() -> void:
	var session := _basic_session("unit_river_guard", "unit_bog_brute", 4, 3, 6, 3)
	session.battle["player_commander_state"] = _spellcaster_state(["spell_prism_bastion"])
	_set_stack_effects(session.battle, "player_0", [_status_effect("status_staggered", "Staggered", 3)])
	var result := BattleRulesScript.cast_player_spell(session, "spell_prism_bastion")
	_expect_ok("status cleanse spell action", result)
	var state := _state_for(session, "player_0")
	_expect_equal("status cleanse animation state", state, "status_expired")
	_expect_event("status cleanse queue", session.battle, "player_0", "battle_status_expired", "status_expired")
	var player_stack := _stack_by_id(session.battle, "player_0")
	if _stack_has_effect(player_stack, "status_staggered"):
		_error("Status cleanse did not remove the staggered effect: %s" % player_stack)
	await get_tree().create_timer(0.08).timeout
	var board_summary := _board_summary_for_session(session)
	var observed_states := _observed_animation_states(board_summary)
	_expect_equal("status cleanse board state", String(observed_states.get("player_0", "")), "status_expired")
	var cleansed_stack := _summary_stack_entry(board_summary, "player_0")
	_expect_equal("status cleanse presentation role", String(cleansed_stack.get("presentation_motion_role", "")), "status_clear")
	var vfx_playback: Dictionary = board_summary.get("vfx_playback", {}) if board_summary.get("vfx_playback", {}) is Dictionary else {}
	var clear_vfx := _vfx_entry_for(vfx_playback, "status_clear")
	_expect_equal("status cleanse vfx cue", String(clear_vfx.get("cue_id", "")), "vfx_placeholder_status_clear")
	_expect_equal("status cleanse imported vfx", str(bool(clear_vfx.get("asset_loaded", false))), "true")
	_expect_equal("status cleanse vfx asset path", String(clear_vfx.get("asset_path", "")), "res://art/battle/vfx/core_status_clear.png")
	var audio_playback: Dictionary = board_summary.get("audio_playback", {}) if board_summary.get("audio_playback", {}) is Dictionary else {}
	var clear_audio := _audio_record_for(audio_playback, "player_0")
	_expect_array_contains("status cleanse audio cue", clear_audio.get("selected_audio_cue_ids", []), "audio_placeholder_status_clear")
	var camera_playback: Dictionary = board_summary.get("camera_playback", {}) if board_summary.get("camera_playback", {}) is Dictionary else {}
	var focus_counts: Dictionary = camera_playback.get("focus_kind_counts", {}) if camera_playback.get("focus_kind_counts", {}) is Dictionary else {}
	if int(focus_counts.get("status", 0)) < 1:
		_error("Status cleanse did not create a status camera focus record: %s" % camera_playback)
	_report["cases"]["status_cleanse"] = {
		"state": state,
		"queue": BattleRulesScript.animation_event_queue(session.battle),
		"board_states": observed_states,
		"board_stack": cleansed_stack,
		"board_vfx": vfx_playback,
		"board_audio": audio_playback,
		"board_camera": camera_playback,
	}

func _validate_status_round_expiry_state() -> void:
	var session := _basic_session("unit_river_guard", "unit_bog_brute", 4, 3, 6, 3)
	_set_stack_effects(session.battle, "player_0", [_status_effect("status_harried", "Harried", 1)])
	BattleRulesScript.advance_turn(session.battle)
	var state := _state_for(session, "player_0")
	_expect_equal("status round expiry animation state", state, "status_expired")
	_expect_event("status round expiry queue", session.battle, "player_0", "battle_status_expired", "status_expired")
	var player_stack := _stack_by_id(session.battle, "player_0")
	if _stack_has_effect(player_stack, "status_harried"):
		_error("Round expiry did not remove harried effect: %s" % player_stack)
	_report["cases"]["status_round_expiry"] = {
		"state": state,
		"round": int(session.battle.get("round", 0)),
		"queue": BattleRulesScript.animation_event_queue(session.battle),
		"events": BattleRulesScript.animation_event_states(session.battle),
	}

func _validate_exit_action_state(action_id: String, event_id: String, expected_state: String) -> void:
	var session := _basic_session("unit_river_guard", "unit_bog_brute", 4, 3, 6, 3)
	var result := BattleRulesScript.perform_player_action(session, action_id)
	_expect_ok("%s exit action" % action_id, result)
	_expect_equal("%s exit result state" % action_id, String(result.get("state", "")), action_id)
	var snapshot: Dictionary = result.get("battle_exit_animation_snapshot", {}) if result.get("battle_exit_animation_snapshot", {}) is Dictionary else {}
	if snapshot.is_empty():
		_error("%s did not preserve a battle_exit_animation_snapshot before clearing battle." % action_id)
		return
	_expect_equal("%s exit presentation mode" % action_id, String(snapshot.get("presentation_mode", "")), "battle_exit_animation")
	_expect_equal("%s exit presentation outcome" % action_id, String(snapshot.get("presentation_outcome", "")), action_id)
	var player_state := BattleRulesScript.animation_state_for_stack(snapshot, _stack_by_id(snapshot, "player_0"))
	_expect_equal("%s player exit animation state" % action_id, player_state, expected_state)
	_expect_event("%s player exit queue" % action_id, snapshot, "player_0", event_id, expected_state)

	var view := BattleBoardViewScript.new()
	view.size = Vector2(960.0, 540.0)
	add_child(view)
	view.set_battle_presentation_snapshot(snapshot)
	await get_tree().process_frame
	await get_tree().create_timer(0.08).timeout
	var summary: Dictionary = view.validation_unit_art_summary()
	view.queue_free()
	await get_tree().process_frame
	var observed_states := _observed_animation_states(summary)
	_expect_equal("%s board exit animation state" % action_id, String(observed_states.get("player_0", "")), expected_state)
	var playback: Dictionary = summary.get("animation_playback", {}) if summary.get("animation_playback", {}) is Dictionary else {}
	if int(playback.get("active_playback_count", 0)) < 1:
		_error("%s board exit playback did not keep the exit animation active: %s" % [action_id, playback])
	var exiting_stack := _summary_stack_entry(summary, "player_0")
	var expected_role := "retreat_withdraw" if action_id == "retreat" else "surrender_stand_down"
	_expect_equal("%s board exit presentation active" % action_id, str(bool(exiting_stack.get("presentation_motion_active", false))), "true")
	_expect_equal("%s board exit presentation event" % action_id, String(exiting_stack.get("presentation_motion_event_id", "")), event_id)
	_expect_equal("%s board exit presentation role" % action_id, String(exiting_stack.get("presentation_motion_role", "")), expected_role)
	var vfx_playback: Dictionary = summary.get("vfx_playback", {}) if summary.get("vfx_playback", {}) is Dictionary else {}
	if action_id == "retreat":
		var retreat_vfx := _vfx_entry_for(vfx_playback, "path_ghost")
		_expect_equal("retreat path vfx cue", String(retreat_vfx.get("cue_id", "")), "vfx_placeholder_withdraw_path")
		_expect_equal("retreat path imported vfx", str(bool(retreat_vfx.get("asset_loaded", false))), "true")
		_expect_equal("retreat path imported asset", String(retreat_vfx.get("asset_path", "")), "res://art/battle/vfx/path_withdraw_ghost.png")
	else:
		var surrender_vfx := _vfx_entry_for(vfx_playback, "surrender_marker")
		_expect_equal("surrender marker vfx cue", String(surrender_vfx.get("cue_id", "")), "vfx_placeholder_surrender_marker")
		_expect_equal("surrender marker vfx battle id", String(surrender_vfx.get("battle_id", "")), "player_0")
		_expect_equal("surrender marker imported vfx", str(bool(surrender_vfx.get("asset_loaded", false))), "true")
		_expect_equal("surrender marker imported asset", String(surrender_vfx.get("asset_path", "")), "res://art/battle/vfx/state_surrender_marker.png")
	var motion_roles: Dictionary = summary.get("presentation_motion_roles", {}) if summary.get("presentation_motion_roles", {}) is Dictionary else {}
	if int(motion_roles.get(expected_role, 0)) < 1:
		_error("%s board exit presentation role was not counted in the board summary: %s" % [action_id, summary])
	_report["cases"][action_id] = {
		"result_state": String(result.get("state", "")),
		"snapshot_policy": String(snapshot.get("presentation_policy", "")),
		"player_state": player_state,
		"events": BattleRulesScript.animation_event_states(snapshot),
		"queue": BattleRulesScript.animation_event_queue(snapshot),
		"board_states": observed_states,
		"board_playback": playback,
		"board_vfx": vfx_playback,
		"board_stack": exiting_stack,
		"presentation_motion_roles": motion_roles,
	}

func _validate_board_runtime_summary() -> void:
	var session := _basic_session("unit_mire_slinger", "unit_bog_brute", 1, 3, 7, 3)
	_set_stack_field(session.battle, "enemy_0", "total_health", 999)
	var result := BattleRulesScript.perform_player_action(session, "shoot")
	_expect_ok("board summary source action", result)
	var view := BattleBoardViewScript.new()
	view.size = Vector2(960.0, 540.0)
	add_child(view)
	view.set_battle_state(session)
	await get_tree().process_frame
	await get_tree().create_timer(0.16).timeout
	var original_shake_mode := SettingsService.battle_camera_shake_mode_id()
	SettingsService.settings["accessibility"]["battle_camera_shake"] = SettingsService.BATTLE_CAMERA_SHAKE_FULL
	var summary: Dictionary = view.validation_unit_art_summary()
	var camera_mode_summaries := {}
	for shake_mode in [
		SettingsService.BATTLE_CAMERA_SHAKE_FULL,
		SettingsService.BATTLE_CAMERA_SHAKE_REDUCED,
		SettingsService.BATTLE_CAMERA_SHAKE_OFF,
	]:
		SettingsService.settings["accessibility"]["battle_camera_shake"] = shake_mode
		camera_mode_summaries[shake_mode] = view.validation_camera_playback_summary()
	SettingsService.settings["accessibility"]["battle_camera_shake"] = original_shake_mode
	var original_effects_volume := SettingsService.effects_volume_percent()
	SettingsService.settings["audio"]["effects_volume_percent"] = 0
	SettingsService.apply_settings()
	var muted_audio_summary: Dictionary = view.validation_audio_playback_summary()
	SettingsService.settings["audio"]["effects_volume_percent"] = original_effects_volume
	SettingsService.apply_settings()
	view.queue_free()
	await get_tree().process_frame
	var observed_states := {}
	for entry in summary.get("stacks", []):
		if entry is Dictionary:
			observed_states[String(entry.get("battle_id", ""))] = String(entry.get("animation_state", ""))
	_expect_equal("board runtime ranged attacker state", String(observed_states.get("player_0", "")), "ranged_aim_release")
	_expect_equal("board runtime status target state", String(observed_states.get("enemy_0", "")), "status_applied")
	var cue_playback := _validate_active_cue_dispatch(summary)
	var vfx_playback := _validate_active_vfx_presentation(summary)
	var audio_playback := _validate_active_audio_playback(summary)
	if not bool(muted_audio_summary.get("muted", false)):
		_error("Zero Effects volume must mute battle audio playback: %s" % muted_audio_summary)
	var camera_playback := _validate_active_camera_presentation(summary)
	_validate_camera_shake_accessibility(camera_mode_summaries)
	_report["cases"]["board_runtime"] = {"observed_states": observed_states, "summary": summary}
	_report["cases"]["board_cue_dispatch"] = {
		"active_cue_playback": cue_playback,
	}
	_report["cases"]["board_vfx_presentation"] = {
		"active_vfx_playback": vfx_playback,
	}
	_report["cases"]["board_audio_playback"] = {
		"active_audio_playback": audio_playback,
		"muted_audio_playback": muted_audio_summary,
	}
	_report["cases"]["board_camera_presentation"] = {
		"active_camera_playback": camera_playback,
		"shake_modes": camera_mode_summaries,
	}

func _validate_imported_vfx_live_viewports() -> void:
	var original_window_size := get_window().size
	var results := {}
	for viewport_size in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		get_window().size = viewport_size
		await get_tree().process_frame
		await get_tree().process_frame
		_expect_equal("battle vfx requested viewport", str(get_window().size), str(viewport_size))
		var session := _basic_session("unit_mire_slinger", "unit_bog_brute", 1, 3, 7, 3)
		_set_stack_field(session.battle, "enemy_0", "total_health", 999)
		var result := BattleRulesScript.perform_player_action(session, "shoot")
		_expect_ok("battle vfx live viewport shoot", result)
		var view := BattleBoardViewScript.new()
		view.position = Vector2.ZERO
		view.size = Vector2(viewport_size)
		add_child(view)
		view.set_battle_state(session)
		await get_tree().process_frame
		await get_tree().create_timer(0.22).timeout
		view.queue_redraw()
		await get_tree().process_frame
		var summary: Dictionary = view.validation_unit_art_summary()
		var vfx_playback: Dictionary = summary.get("vfx_playback", {}) if summary.get("vfx_playback", {}) is Dictionary else {}
		if int(vfx_playback.get("imported_asset_draw_count", 0)) < 2:
			_error("Battle VFX live viewport did not draw imported projectile and status assets at %s: %s" % [viewport_size, vfx_playback])
		var projectile := _vfx_entry_for(vfx_playback, "projectile_path")
		var status := _vfx_entry_for(vfx_playback, "status_residue")
		_expect_equal("battle vfx viewport projectile imported", str(bool(projectile.get("asset_loaded", false))), "true")
		_expect_equal("battle vfx viewport status imported", str(bool(status.get("asset_loaded", false))), "true")
		var viewport_texture: Texture2D = get_viewport().get_texture()
		if viewport_texture == null:
			_error("Battle VFX live viewport capture requires a windowed render texture at %s." % viewport_size)
			view.queue_free()
			get_window().size = original_window_size
			return
		var image: Image = viewport_texture.get_image()
		if image == null:
			_error("Battle VFX live viewport capture returned no image at %s." % viewport_size)
			view.queue_free()
			get_window().size = original_window_size
			return
		_expect_int("battle vfx capture width", image.get_width(), viewport_size.x)
		_expect_int("battle vfx capture height", image.get_height(), viewport_size.y)
		var capture_path := "%s/core_vfx_%dx%d.png" % [OUTPUT_DIR, viewport_size.x, viewport_size.y]
		var save_error := image.save_png(ProjectSettings.globalize_path(capture_path))
		_expect_int("battle vfx capture save", save_error, OK)
		results["%dx%d" % [viewport_size.x, viewport_size.y]] = {
			"capture_path": capture_path,
			"logical_view_size": [view.size.x, view.size.y],
			"imported_asset_draw_count": int(vfx_playback.get("imported_asset_draw_count", 0)),
			"procedural_fallback_draw_count": int(vfx_playback.get("procedural_fallback_draw_count", 0)),
			"projectile_asset_path": String(projectile.get("asset_path", "")),
			"status_asset_path": String(status.get("asset_path", "")),
		}
		view.queue_free()
		await get_tree().process_frame
	get_window().size = original_window_size
	await get_tree().process_frame
	_report["cases"]["core_vfx_live_viewports"] = results

func _validate_spell_vfx_live_viewports() -> void:
	var original_window_size := get_window().size
	var cue_by_viewport := {
		"1280x720": "vfx_spell_resonant_chorus",
		"1920x1080": "vfx_spell_prism_bastion",
	}
	var results := {}
	for viewport_size in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		get_window().size = viewport_size
		await get_tree().process_frame
		await get_tree().process_frame
		_expect_equal("spell vfx requested viewport", str(get_window().size), str(viewport_size))
		var session := _basic_session("unit_river_guard", "unit_bog_brute", 3, 3, 7, 3)
		var view := BattleBoardViewScript.new()
		view.position = Vector2.ZERO
		view.size = Vector2(viewport_size)
		add_child(view)
		view.set_battle_state(session)
		var viewport_key := "%dx%d" % [viewport_size.x, viewport_size.y]
		var cue_id := String(cue_by_viewport.get(viewport_key, ""))
		_install_validation_vfx_cues(view, [cue_id])
		await get_tree().process_frame
		view.queue_redraw()
		await get_tree().process_frame
		var playback: Dictionary = view.validation_vfx_playback_summary()
		_expect_int("spell vfx viewport imported draw count", int(playback.get("imported_asset_draw_count", 0)), 1)
		var spell_entry := _vfx_entry_for_cue(playback, cue_id)
		_expect_equal("spell vfx viewport asset loaded", str(bool(spell_entry.get("asset_loaded", false))), "true")
		var viewport_texture: Texture2D = get_viewport().get_texture()
		if viewport_texture == null:
			_error("Spell VFX live viewport capture requires a windowed render texture at %s." % viewport_size)
			view.queue_free()
			get_window().size = original_window_size
			return
		var image: Image = viewport_texture.get_image()
		if image == null:
			_error("Spell VFX live viewport capture returned no image at %s." % viewport_size)
			view.queue_free()
			get_window().size = original_window_size
			return
		_expect_int("spell vfx capture width", image.get_width(), viewport_size.x)
		_expect_int("spell vfx capture height", image.get_height(), viewport_size.y)
		var capture_path := "%s/spell_vfx_%dx%d.png" % [OUTPUT_DIR, viewport_size.x, viewport_size.y]
		var save_error := image.save_png(ProjectSettings.globalize_path(capture_path))
		_expect_int("spell vfx capture save", save_error, OK)
		results[viewport_key] = {
			"capture_path": capture_path,
			"cue_id": cue_id,
			"asset_path": String(spell_entry.get("asset_path", "")),
			"logical_view_size": [view.size.x, view.size.y],
		}
		view.queue_free()
		await get_tree().process_frame
	get_window().size = original_window_size
	await get_tree().process_frame
	_report["cases"]["spell_vfx_live_viewports"] = results

func _validate_state_path_vfx_live_viewports() -> void:
	var original_window_size := get_window().size
	var cue_by_viewport := {
		"1280x720": "vfx_placeholder_battle_path_ghost",
		"1920x1080": "vfx_placeholder_surrender_marker",
	}
	var results := {}
	for viewport_size in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		get_window().size = viewport_size
		await get_tree().process_frame
		await get_tree().process_frame
		_expect_equal("state path vfx requested viewport", str(get_window().size), str(viewport_size))
		var session := _basic_session("unit_river_guard", "unit_bog_brute", 3, 3, 7, 3)
		var view := BattleBoardViewScript.new()
		view.position = Vector2.ZERO
		view.size = Vector2(viewport_size)
		add_child(view)
		view.set_battle_state(session)
		var viewport_key := "%dx%d" % [viewport_size.x, viewport_size.y]
		var cue_id := String(cue_by_viewport.get(viewport_key, ""))
		_install_validation_vfx_cues(view, [cue_id])
		await get_tree().process_frame
		view.queue_redraw()
		await get_tree().process_frame
		var playback: Dictionary = view.validation_vfx_playback_summary()
		_expect_int("state path vfx viewport imported draw count", int(playback.get("imported_asset_draw_count", 0)), 1)
		var state_entry := _vfx_entry_for_cue(playback, cue_id)
		_expect_equal("state path vfx viewport asset loaded", str(bool(state_entry.get("asset_loaded", false))), "true")
		var viewport_texture: Texture2D = get_viewport().get_texture()
		if viewport_texture == null:
			_error("State/path VFX live viewport capture requires a windowed render texture at %s." % viewport_size)
			view.queue_free()
			get_window().size = original_window_size
			return
		var image: Image = viewport_texture.get_image()
		if image == null:
			_error("State/path VFX live viewport capture returned no image at %s." % viewport_size)
			view.queue_free()
			get_window().size = original_window_size
			return
		_expect_int("state path vfx capture width", image.get_width(), viewport_size.x)
		_expect_int("state path vfx capture height", image.get_height(), viewport_size.y)
		var capture_path := "%s/state_path_vfx_%dx%d.png" % [OUTPUT_DIR, viewport_size.x, viewport_size.y]
		var save_error := image.save_png(ProjectSettings.globalize_path(capture_path))
		_expect_int("state path vfx capture save", save_error, OK)
		results[viewport_key] = {
			"capture_path": capture_path,
			"cue_id": cue_id,
			"asset_path": String(state_entry.get("asset_path", "")),
			"logical_view_size": [view.size.x, view.size.y],
		}
		view.queue_free()
		await get_tree().process_frame
	get_window().size = original_window_size
	await get_tree().process_frame
	_report["cases"]["state_path_vfx_live_viewports"] = results

func _install_validation_vfx_cues(view: Control, cue_ids: Array) -> void:
	var now := int(Time.get_ticks_msec())
	view.set("_stack_animation_playback_until_msec", {"player_0": now + 5000})
	view.set("_stack_animation_cue_playback_records", {
		"player_0": {
			"battle_id": "player_0",
			"event_id": "battle_unit_cast",
			"serial": 9100,
			"cue_id": "cast_support_anchor",
			"selected_vfx_cue_ids": cue_ids.duplicate(),
			"selected_audio_cue_ids": [],
			"source_battle_id": "player_0",
			"target_battle_id": "enemy_0",
			"from_q": 3,
			"from_r": 3,
			"to_q": 7,
			"to_r": 3,
			"started_at_msec": now - 120,
			"max_duration_ms": 760,
			"sequence_delay_msec": 0,
		}
	})

func _validate_board_playback_lifecycle() -> void:
	var session := _basic_session("unit_mire_slinger", "unit_bog_brute", 1, 3, 7, 3)
	_set_stack_field(session.battle, "enemy_0", "total_health", 999)
	var result := BattleRulesScript.perform_player_action(session, "shoot")
	_expect_ok("board lifecycle source action", result)
	var view := BattleBoardViewScript.new()
	view.size = Vector2(960.0, 540.0)
	add_child(view)
	view.set_battle_state(session)
	await get_tree().process_frame
	await get_tree().create_timer(0.16).timeout
	var active_summary: Dictionary = view.validation_unit_art_summary()
	var active_states := _observed_animation_states(active_summary)
	var active_playback: Dictionary = active_summary.get("animation_playback", {}) if active_summary.get("animation_playback", {}) is Dictionary else {}
	var active_cue: Dictionary = active_summary.get("cue_playback", {}) if active_summary.get("cue_playback", {}) is Dictionary else {}
	var active_vfx: Dictionary = active_summary.get("vfx_playback", {}) if active_summary.get("vfx_playback", {}) is Dictionary else {}
	var active_audio: Dictionary = active_summary.get("audio_playback", {}) if active_summary.get("audio_playback", {}) is Dictionary else {}
	var active_camera: Dictionary = active_summary.get("camera_playback", {}) if active_summary.get("camera_playback", {}) is Dictionary else {}
	_expect_equal("lifecycle active ranged state", String(active_states.get("player_0", "")), "ranged_aim_release")
	_expect_equal("lifecycle active status state", String(active_states.get("enemy_0", "")), "status_applied")
	if int(active_playback.get("active_playback_count", 0)) < 2:
		_error("Playback lifecycle did not keep both source and target events active: %s" % active_playback)
	if int(active_cue.get("active_cue_record_count", 0)) < 2:
		_error("Cue lifecycle did not keep both source and target cue records active: %s" % active_cue)
	if int(active_vfx.get("active_vfx_draw_count", 0)) < 2:
		_error("VFX lifecycle did not keep source and target draw entries active: %s" % active_vfx)
	if int(active_audio.get("active_audio_record_count", 0)) < 2:
		_error("Audio lifecycle did not keep source and target audio records active: %s" % active_audio)
	if int(active_camera.get("active_camera_record_count", 0)) < 2:
		_error("Camera lifecycle did not keep source and target presentation records active: %s" % active_camera)
	await get_tree().create_timer(0.90).timeout
	var expired_summary: Dictionary = view.validation_unit_art_summary()
	var expired_states := _observed_animation_states(expired_summary)
	var expired_playback: Dictionary = expired_summary.get("animation_playback", {}) if expired_summary.get("animation_playback", {}) is Dictionary else {}
	var expired_cue: Dictionary = expired_summary.get("cue_playback", {}) if expired_summary.get("cue_playback", {}) is Dictionary else {}
	var expired_vfx: Dictionary = expired_summary.get("vfx_playback", {}) if expired_summary.get("vfx_playback", {}) is Dictionary else {}
	var expired_audio: Dictionary = expired_summary.get("audio_playback", {}) if expired_summary.get("audio_playback", {}) is Dictionary else {}
	var expired_camera: Dictionary = expired_summary.get("camera_playback", {}) if expired_summary.get("camera_playback", {}) is Dictionary else {}
	_expect_equal("lifecycle expired source fallback", String(expired_states.get("player_0", "")), "ready_active")
	_expect_equal("lifecycle expired target fallback", String(expired_states.get("enemy_0", "")), "idle_hold")
	if int(expired_playback.get("active_playback_count", -1)) != 0:
		_error("Playback lifecycle did not expire event states: %s" % expired_playback)
	if int(expired_cue.get("active_cue_record_count", -1)) != 0:
		_error("Cue lifecycle did not expire cue records: %s" % expired_cue)
	if int(expired_vfx.get("active_vfx_draw_count", -1)) != 0:
		_error("VFX lifecycle did not expire draw entries: %s" % expired_vfx)
	if int(expired_audio.get("active_audio_record_count", -1)) != 0:
		_error("Audio lifecycle did not expire audio records: %s" % expired_audio)
	if int(expired_camera.get("active_camera_record_count", -1)) != 0:
		_error("Camera lifecycle did not expire presentation records: %s" % expired_camera)
	view.queue_free()
	await get_tree().process_frame
	_report["cases"]["board_playback_lifecycle"] = {
		"active_states": active_states,
		"expired_states": expired_states,
		"active_playback": active_playback,
		"expired_playback": expired_playback,
		"active_cue_playback": active_cue,
		"expired_cue_playback": expired_cue,
		"active_vfx_playback": active_vfx,
		"expired_vfx_playback": expired_vfx,
		"active_audio_playback": active_audio,
		"expired_audio_playback": expired_audio,
		"active_camera_playback": active_camera,
		"expired_camera_playback": expired_camera,
	}

func _validate_battle_audio_mix_policy() -> void:
	var view := BattleBoardViewScript.new()
	view.size = Vector2(960.0, 540.0)
	add_child(view)
	await get_tree().process_frame
	var original_effects_volume := SettingsService.effects_volume_percent()
	var original_reduced_repetition := SettingsService.reduced_repetitive_sounds_enabled()
	SettingsService.settings["audio"]["effects_volume_percent"] = 100
	SettingsService.settings["accessibility"]["reduce_repetitive_sounds"] = false
	SettingsService.apply_settings()

	view.validation_reset_audio_mix()
	var first_idle: Dictionary = view.validation_play_audio_cue("audio_placeholder_idle_soft", "mix_idle_1", 1)
	var repeated_idle: Dictionary = view.validation_play_audio_cue("audio_placeholder_idle_soft", "mix_idle_2", 2)
	_expect_equal("audio mix first idle source", String(first_idle.get("source", "")), "imported_wav")
	_expect_equal("audio mix first idle priority", String(first_idle.get("priority_class", "")), "low")
	_expect_equal("audio mix repeated idle source", String(repeated_idle.get("source", "")), "suppressed")
	_expect_equal("audio mix repeated idle reason", String(repeated_idle.get("suppressed_reason", "")), "repeat_cooldown")
	var duplicate_summary: Dictionary = view.validation_audio_playback_summary()
	_expect_int("audio mix duplicate active voices", int(duplicate_summary.get("active_player_count", 0)), 1)
	_expect_int("audio mix duplicate suppressed count", int(duplicate_summary.get("mix_counters", {}).get("suppressed", 0)), 1)

	view.validation_reset_audio_mix()
	var fill_ids := [
		"audio_placeholder_idle_soft",
		"audio_placeholder_hit",
		"audio_placeholder_status_apply",
		"audio_placeholder_status_clear",
		"audio_placeholder_defend",
		"audio_placeholder_turn_ready",
		"audio_placeholder_melee_release",
		"audio_placeholder_ranged_release",
	]
	for index in range(fill_ids.size()):
		var fill_result: Dictionary = view.validation_play_audio_cue(String(fill_ids[index]), "mix_fill_%d" % index, index + 10)
		if not bool(fill_result.get("played", false)):
			_error("Audio mix could not fill voice %d with %s: %s" % [index, fill_ids[index], fill_result])
	var full_summary: Dictionary = view.validation_audio_playback_summary()
	_expect_int("audio mix full voice budget", int(full_summary.get("active_player_count", 0)), 8)
	var critical_result: Dictionary = view.validation_play_audio_cue("audio_spell_cinder_burst", "mix_critical", 30)
	_expect_equal("audio mix critical source", String(critical_result.get("source", "")), "imported_wav")
	_expect_equal("audio mix critical priority", String(critical_result.get("priority_class", "")), "critical")
	_expect_equal("audio mix critical eviction", String(critical_result.get("evicted_audio_id", "")), "audio_placeholder_idle_soft")
	var post_eviction_summary: Dictionary = view.validation_audio_playback_summary()
	_expect_int("audio mix post-eviction voice budget", int(post_eviction_summary.get("active_player_count", 0)), 8)
	_expect_int("audio mix eviction count", int(post_eviction_summary.get("mix_counters", {}).get("evicted", 0)), 1)
	var low_budget_result: Dictionary = view.validation_play_audio_cue("audio_placeholder_unit_step", "mix_low_budget", 31)
	_expect_equal("audio mix low budget source", String(low_budget_result.get("source", "")), "suppressed")
	_expect_equal("audio mix low budget reason", String(low_budget_result.get("suppressed_reason", "")), "voice_budget")

	view.validation_reset_audio_mix()
	SettingsService.settings["audio"]["effects_volume_percent"] = 0
	SettingsService.apply_settings()
	var muted_result: Dictionary = view.validation_play_audio_cue("audio_spell_cinder_burst", "mix_muted", 40)
	var muted_summary: Dictionary = view.validation_audio_playback_summary()
	_expect_equal("audio mix muted source", String(muted_result.get("source", "")), "suppressed")
	_expect_equal("audio mix muted reason", String(muted_result.get("suppressed_reason", "")), "effects_muted")
	_expect_int("audio mix muted active voices", int(muted_summary.get("active_player_count", 0)), 0)

	SettingsService.settings["audio"]["effects_volume_percent"] = 100
	SettingsService.settings["accessibility"]["reduce_repetitive_sounds"] = true
	SettingsService.apply_settings()
	view.validation_reset_audio_mix()
	var reduced_idle: Dictionary = view.validation_play_audio_cue("audio_placeholder_idle_soft", "mix_reduced_idle", 50)
	for reduced_fill in ["audio_placeholder_hit", "audio_placeholder_status_apply", "audio_placeholder_status_clear"]:
		var reduced_fill_result: Dictionary = view.validation_play_audio_cue(String(reduced_fill), "mix_reduced_fill_%s" % reduced_fill, 51)
		if not bool(reduced_fill_result.get("played", false)):
			_error("Reduced audio mix could not fill %s: %s" % [reduced_fill, reduced_fill_result])
	var reduced_full_summary: Dictionary = view.validation_audio_playback_summary()
	_expect_int("reduced audio mix voice budget", int(reduced_full_summary.get("effective_voice_budget", 0)), 4)
	_expect_int("reduced audio mix active voices", int(reduced_full_summary.get("active_player_count", 0)), 4)
	_expect_int("reduced audio mix doubled cooldown", int(reduced_idle.get("repeat_cooldown_msec", 0)), int(first_idle.get("repeat_cooldown_msec", 0)) * 2)
	var reduced_critical: Dictionary = view.validation_play_audio_cue("audio_spell_cinder_burst", "mix_reduced_critical", 60)
	_expect_equal("reduced audio mix critical source", String(reduced_critical.get("source", "")), "imported_wav")
	_expect_equal("reduced audio mix critical eviction", String(reduced_critical.get("evicted_audio_id", "")), "audio_placeholder_idle_soft")
	var reduced_post_critical: Dictionary = view.validation_audio_playback_summary()
	_expect_int("reduced audio mix post-critical voices", int(reduced_post_critical.get("active_player_count", 0)), 4)
	var reduced_low_budget: Dictionary = view.validation_play_audio_cue("audio_placeholder_unit_step", "mix_reduced_low", 61)
	_expect_equal("reduced audio mix low budget reason", String(reduced_low_budget.get("suppressed_reason", "")), "voice_budget")

	SettingsService.settings["audio"]["effects_volume_percent"] = original_effects_volume
	SettingsService.settings["accessibility"]["reduce_repetitive_sounds"] = original_reduced_repetition
	SettingsService.apply_settings()
	view.validation_reset_audio_mix()
	view.queue_free()
	await get_tree().process_frame
	_report["cases"]["battle_audio_mix_policy"] = {
		"duplicate": duplicate_summary,
		"full_budget": full_summary,
		"critical_result": critical_result,
		"post_eviction": post_eviction_summary,
		"low_budget_result": low_budget_result,
		"muted_result": muted_result,
		"muted_summary": muted_summary,
		"reduced_full_budget": reduced_full_summary,
		"reduced_critical": reduced_critical,
		"reduced_post_critical": reduced_post_critical,
		"reduced_low_budget": reduced_low_budget,
	}

func _validate_active_cue_dispatch(summary: Dictionary) -> Dictionary:
	var cue_playback: Dictionary = summary.get("cue_playback", {}) if summary.get("cue_playback", {}) is Dictionary else {}
	if int(cue_playback.get("active_cue_record_count", 0)) < 2:
		_error("Cue dispatch did not keep both source and target cue records active: %s" % cue_playback)
	if int(cue_playback.get("vfx_record_count", 0)) < 2 or int(cue_playback.get("audio_record_count", 0)) < 2:
		_error("Cue dispatch did not resolve VFX/audio ids for both records: %s" % cue_playback)
	var player_cue := _cue_record_for(cue_playback, "player_0")
	var enemy_cue := _cue_record_for(cue_playback, "enemy_0")
	_expect_equal("player cue event id", String(player_cue.get("event_id", "")), "battle_unit_ranged_attack")
	_expect_equal("enemy cue event id", String(enemy_cue.get("event_id", "")), "battle_status_applied")
	_expect_equal("player cue target", String(player_cue.get("target_battle_id", "")), "enemy_0")
	_expect_equal("enemy cue source", String(enemy_cue.get("source_battle_id", "")), "player_0")
	var player_start := int(player_cue.get("started_at_msec", 0))
	var enemy_start := int(enemy_cue.get("started_at_msec", 0))
	if player_start <= 0 or enemy_start <= player_start:
		_error("Cue dispatch did not sequence target reaction after source action: player=%s enemy=%s." % [player_cue, enemy_cue])
	if int(enemy_cue.get("sequence_delay_msec", 0)) <= 0:
		_error("Target reaction cue did not carry a positive sequence delay: %s." % enemy_cue)
	_expect_array_contains("player cue vfx", player_cue.get("selected_vfx_cue_ids", []), "vfx_placeholder_projectile_path")
	_expect_array_contains("player cue audio", player_cue.get("selected_audio_cue_ids", []), "audio_placeholder_ranged_release")
	_expect_array_contains("enemy cue vfx", enemy_cue.get("selected_vfx_cue_ids", []), "vfx_placeholder_status_residue")
	_expect_array_contains("enemy cue audio", enemy_cue.get("selected_audio_cue_ids", []), "audio_placeholder_status_apply")
	return cue_playback

func _validate_active_vfx_presentation(summary: Dictionary) -> Dictionary:
	var vfx_playback: Dictionary = summary.get("vfx_playback", {}) if summary.get("vfx_playback", {}) is Dictionary else {}
	if int(vfx_playback.get("active_vfx_draw_count", 0)) < 2:
		_error("VFX presentation did not materialize both source and target draw entries: %s" % vfx_playback)
	if int(vfx_playback.get("projectile_draw_count", 0)) < 1 or int(vfx_playback.get("status_draw_count", 0)) < 1:
		_error("VFX presentation did not include projectile and status draw entries: %s" % vfx_playback)
	var projectile := _vfx_entry_for(vfx_playback, "projectile_path")
	var status := _vfx_entry_for(vfx_playback, "status_residue")
	_expect_equal("projectile vfx cue", String(projectile.get("cue_id", "")), "vfx_placeholder_projectile_path")
	_expect_equal("projectile imported vfx", str(bool(projectile.get("asset_loaded", false))), "true")
	_expect_equal("projectile vfx asset path", String(projectile.get("asset_path", "")), "res://art/battle/vfx/core_projectile_path.png")
	_expect_equal("projectile vfx source", String(projectile.get("battle_id", "")), "player_0")
	_expect_equal("projectile vfx target", String(projectile.get("target_battle_id", "")), "enemy_0")
	_expect_equal("status vfx cue", String(status.get("cue_id", "")), "vfx_placeholder_status_residue")
	_expect_equal("status imported vfx", str(bool(status.get("asset_loaded", false))), "true")
	_expect_equal("status vfx asset path", String(status.get("asset_path", "")), "res://art/battle/vfx/core_status_residue.png")
	_expect_equal("status vfx target battle id", String(status.get("battle_id", "")), "enemy_0")
	_expect_equal("status vfx source", String(status.get("source_battle_id", "")), "player_0")
	if int(projectile.get("start_q", -1)) == int(projectile.get("target_q", -1)) and int(projectile.get("start_r", -1)) == int(projectile.get("target_r", -1)):
		_error("Projectile VFX did not span distinct source and target cells: %s" % projectile)
	if int(vfx_playback.get("imported_asset_draw_count", 0)) < 2:
		_error("VFX presentation did not render both active cue records through imported assets: %s" % vfx_playback)
	return vfx_playback

func _validate_active_audio_playback(summary: Dictionary) -> Dictionary:
	var audio_playback: Dictionary = summary.get("audio_playback", {}) if summary.get("audio_playback", {}) is Dictionary else {}
	if int(audio_playback.get("active_audio_record_count", 0)) < 2:
		_error("Audio playback did not materialize both source and target audio records: %s" % audio_playback)
	if int(audio_playback.get("imported_asset_count", 0)) + int(audio_playback.get("generated_waveform_count", 0)) + int(audio_playback.get("scheduled_record_count", 0)) < 2:
		_error("Audio playback did not load, synthesize, or schedule both source and target cue sounds: %s" % audio_playback)
	if int(audio_playback.get("imported_asset_count", 0)) + int(audio_playback.get("scheduled_record_count", 0)) < 2:
		_error("Audio playback should prefer committed battle SFX assets while preserving scheduled target reactions: %s" % audio_playback)
	var player_audio := _audio_record_for(audio_playback, "player_0")
	var enemy_audio := _audio_record_for(audio_playback, "enemy_0")
	_expect_array_contains("player audio runtime cue", player_audio.get("selected_audio_cue_ids", []), "audio_placeholder_ranged_release")
	_expect_array_contains("enemy audio runtime cue", enemy_audio.get("selected_audio_cue_ids", []), "audio_placeholder_status_apply")
	if int(player_audio.get("imported_asset_count", 0)) < 1:
		_error("Source audio cue should load a committed runtime SFX asset immediately: %s" % player_audio)
	if String(_audio_asset_path_for(player_audio, "audio_placeholder_ranged_release")).find("ranged_release.wav") < 0:
		_error("Source audio cue did not report the ranged release runtime asset path: %s" % player_audio)
	if int(enemy_audio.get("imported_asset_count", 0)) < 1 and not bool(enemy_audio.get("scheduled", false)):
		_error("Target audio cue should load a committed runtime SFX asset after sequencing delay: %s" % enemy_audio)
	if bool(enemy_audio.get("scheduled", false)) and int(enemy_audio.get("sequence_delay_msec", 0)) <= 0:
		_error("Scheduled target audio cue should carry a positive sequence delay: %s" % enemy_audio)
	if String(audio_playback.get("audio_bus", "")) != "Effects":
		_error("Audio playback should route battle cues through Effects bus: %s" % audio_playback)
	if String(audio_playback.get("sfx_manifest_path", "")) != "res://content/battle_sfx_manifest.json":
		_error("Audio playback did not report the battle SFX manifest path: %s" % audio_playback)
	return audio_playback

func _validate_active_camera_presentation(summary: Dictionary) -> Dictionary:
	var camera_playback: Dictionary = summary.get("camera_playback", {}) if summary.get("camera_playback", {}) is Dictionary else {}
	if int(camera_playback.get("active_camera_record_count", 0)) < 2:
		_error("Camera presentation did not materialize both source and target event records: %s" % camera_playback)
	if int(camera_playback.get("shake_record_count", 0)) < 2:
		_error("Camera presentation did not mark ranged/status records with impact shake: %s" % camera_playback)
	var focus_counts: Dictionary = camera_playback.get("focus_kind_counts", {}) if camera_playback.get("focus_kind_counts", {}) is Dictionary else {}
	if int(focus_counts.get("source_target", 0)) < 1 or int(focus_counts.get("status", 0)) < 1:
		_error("Camera presentation did not classify source-target and status focus kinds: %s" % camera_playback)
	if String(camera_playback.get("strongest_event_id", "")) == "":
		_error("Camera presentation did not identify a strongest active event: %s" % camera_playback)
	if float(camera_playback.get("strongest_shake_strength", 0.0)) <= 0.0:
		_error("Camera presentation did not expose positive shake strength: %s" % camera_playback)
	var max_offset := float(camera_playback.get("max_offset_px", 0.0))
	if max_offset <= 0.0:
		_error("Camera presentation did not expose a positive max offset: %s" % camera_playback)
	if absf(float(camera_playback.get("offset_x", 0.0))) > max_offset + 0.01 or absf(float(camera_playback.get("offset_y", 0.0))) > max_offset + 0.01:
		_error("Camera presentation offset exceeded its bounded max: %s" % camera_playback)
	return camera_playback

func _validate_camera_shake_accessibility(mode_summaries: Dictionary) -> void:
	var full: Dictionary = mode_summaries.get(SettingsService.BATTLE_CAMERA_SHAKE_FULL, {})
	var reduced: Dictionary = mode_summaries.get(SettingsService.BATTLE_CAMERA_SHAKE_REDUCED, {})
	var off: Dictionary = mode_summaries.get(SettingsService.BATTLE_CAMERA_SHAKE_OFF, {})
	var full_strength := float(full.get("strongest_shake_strength", 0.0))
	var reduced_strength := float(reduced.get("strongest_shake_strength", 0.0))
	if String(full.get("configured_shake_mode", "")) != SettingsService.BATTLE_CAMERA_SHAKE_FULL or not is_equal_approx(float(full.get("configured_shake_scale", -1.0)), 1.0):
		_error("Full battle-shake mode did not expose its live scale: %s" % full)
	if full_strength <= 0.0:
		_error("Full battle-shake mode did not retain positive camera motion: %s" % full)
	if String(reduced.get("configured_shake_mode", "")) != SettingsService.BATTLE_CAMERA_SHAKE_REDUCED or not is_equal_approx(float(reduced.get("configured_shake_scale", -1.0)), 0.35):
		_error("Reduced battle-shake mode did not expose its live scale: %s" % reduced)
	if not is_equal_approx(reduced_strength, snappedf(full_strength * 0.35, 0.001)):
		_error("Reduced battle shake %.3f did not equal 35 percent of Full %.3f." % [reduced_strength, full_strength])
	if String(off.get("configured_shake_mode", "")) != SettingsService.BATTLE_CAMERA_SHAKE_OFF or float(off.get("configured_shake_scale", -1.0)) != 0.0:
		_error("Off battle-shake mode did not expose zero scale: %s" % off)
	if int(off.get("shake_record_count", -1)) != 0 or float(off.get("strongest_shake_strength", -1.0)) != 0.0 or float(off.get("offset_x", -1.0)) != 0.0 or float(off.get("offset_y", -1.0)) != 0.0:
		_error("Off battle-shake mode still displaced the live board: %s" % off)

func _validate_shell_presentation_event_surface() -> void:
	var session := _basic_session("unit_river_guard", "unit_bog_brute", 4, 3, 5, 3)
	_set_stack_field(session.battle, "enemy_0", "retaliations_left", 0)
	_set_stack_field(session.battle, "enemy_0", "total_health", 999)
	var result := BattleRulesScript.perform_player_action(session, "strike")
	_expect_ok("shell presentation strike action", result)
	var rules_payload := BattleRulesScript.latest_animation_event_presentation_payload(session)
	_expect_equal("shell presentation payload source", String(rules_payload.get("source", "")), "battle_animation_events")
	if not String(rules_payload.get("visible_text", "")).begins_with("Action cue:"):
		_error("Rules presentation payload did not expose an action cue: %s" % rules_payload)
		return

	SessionState.set_active_session(session)
	var frame := Control.new()
	frame.name = "BattleEventPresentationShellFrame"
	frame.size = Vector2(1024.0, 640.0)
	add_child(frame)
	var shell = load("res://scenes/battle/BattleShell.tscn").instantiate()
	frame.add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame
	if not shell.has_method("validation_snapshot"):
		_error("Battle shell does not expose validation_snapshot for presentation event validation.")
		frame.queue_free()
		return
	if shell.has_method("validation_set_battle_resolution_routing_enabled"):
		shell.call("validation_set_battle_resolution_routing_enabled", false)
	if shell.has_method("_refresh"):
		shell.call("_refresh")
	await get_tree().process_frame
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var shell_payload: Dictionary = snapshot.get("battle_presentation_event", {}) if snapshot.get("battle_presentation_event", {}) is Dictionary else {}
	_expect_equal("shell presentation source", String(shell_payload.get("source", "")), "battle_animation_events")
	_expect_equal("shell presentation event id", String(shell_payload.get("event_id", "")), String(rules_payload.get("event_id", "")))
	for token in ["Action cue:", "Battle Presentation Event", "River Guard", "Bog Brute"]:
		var combined := "\n".join([
			String(snapshot.get("event_visible_text", "")),
			String(snapshot.get("event_tooltip_text", "")),
			String(snapshot.get("battle_presentation_event_visible_text", "")),
			String(snapshot.get("battle_presentation_event_tooltip_text", "")),
		])
		if not combined.contains(token):
			_error("Shell presentation event surface lost %s in %s." % [token, snapshot])
			break
	_report["cases"]["shell_presentation_event"] = {
		"rules_payload": rules_payload,
		"shell_payload": shell_payload,
		"event_visible_text": String(snapshot.get("event_visible_text", "")),
		"event_tooltip_text": String(snapshot.get("event_tooltip_text", "")),
		"presentation_events": snapshot.get("battle_presentation_events", []),
		"presentation_stream_text": String(snapshot.get("battle_presentation_stream_text", "")),
		"presentation_speed": String(snapshot.get("battle_presentation_speed", "")),
	}
	frame.queue_free()
	await get_tree().process_frame

func _validate_presentation_event_stream_contract() -> void:
	var strike_session := _basic_session("unit_river_guard", "unit_bog_brute", 4, 3, 5, 3)
	_set_stack_field(strike_session.battle, "player_0", "total_health", 999)
	_set_stack_field(strike_session.battle, "enemy_0", "total_health", 999)
	_set_stack_field(strike_session.battle, "enemy_0", "retaliations_left", 1)
	var strike_result := BattleRulesScript.perform_player_action(strike_session, "strike")
	_expect_ok("presentation stream strike", strike_result)
	var strike_types := _presentation_event_types(strike_session.battle)
	for expected_type in ["strike", "damage", "retaliation"]:
		if expected_type not in strike_types:
			_error("Presentation strike stream is missing %s in %s." % [expected_type, BattleRulesScript.battle_presentation_event_stream(strike_session.battle)])
	var strike_stream_text := BattleRulesScript.describe_battle_presentation_stream(strike_session, 6)
	for token in ["strikes", "damage", "retaliates"]:
		if not strike_stream_text.to_lower().contains(token):
			_error("Presentation strike stream text lost %s in %s." % [token, strike_stream_text])

	var spell_session := _basic_session("unit_river_guard", "unit_bog_brute", 4, 3, 6, 3)
	spell_session.battle["turn_order"] = ["player_0", "player_0"]
	spell_session.battle["player_commander_state"] = _spellcaster_state()
	_set_stack_field(spell_session.battle, "enemy_0", "total_health", 999)
	_set_stack_field(spell_session.battle, "enemy_0", "spell_resistance_pct", 40)
	var spell_result := BattleRulesScript.cast_player_spell(spell_session, "spell_cinder_burst")
	_expect_ok("presentation stream spell", spell_result)
	var spell_types := _presentation_event_types(spell_session.battle)
	for expected_type in ["cast", "spell_damage", "resist"]:
		if expected_type not in spell_types:
			_error("Presentation spell stream is missing %s in %s." % [expected_type, BattleRulesScript.battle_presentation_event_stream(spell_session.battle)])
	var latest_spell_event := BattleRulesScript.latest_battle_presentation_event_payload(spell_session)
	if int(latest_spell_event.get("serial", 0)) <= 0:
		_error("Latest presentation payload did not expose a positive serial: %s." % latest_spell_event)

	var speed_session := _basic_session("unit_river_guard", "unit_bog_brute", 0, 3, 7, 3)
	var speed_result := BattleRulesScript.set_battle_presentation_speed(speed_session, BattleRulesScript.PRESENTATION_SPEED_FAST)
	_expect_ok("presentation speed set", speed_result)
	var destinations: Array = BattleRulesScript.legal_destinations_for_active_stack(speed_session.battle)
	if destinations.is_empty():
		_error("Presentation speed case has no legal move destination.")
	else:
		var destination: Dictionary = destinations[0]
		var move_result := BattleRulesScript.move_active_stack_to_hex(speed_session, int(destination.get("q", 0)), int(destination.get("r", 0)))
		_expect_ok("presentation speed move", move_result)
		var board_summary := _board_summary_for_session(speed_session)
		var playback: Dictionary = board_summary.get("animation_playback", {}) if board_summary.get("animation_playback", {}) is Dictionary else {}
		_expect_equal("presentation speed board mode", String(playback.get("presentation_speed", "")), BattleRulesScript.PRESENTATION_SPEED_FAST)
		if int(playback.get("effective_playback_duration_msec", 9999)) >= int(playback.get("playback_duration_msec", 0)):
			_error("Fast presentation speed did not reduce playback duration: %s." % playback)
	_report["cases"]["presentation_event_stream"] = {
		"strike_types": strike_types,
		"spell_types": spell_types,
		"strike_stream_text": strike_stream_text,
		"spell_events": BattleRulesScript.battle_presentation_event_stream(spell_session.battle),
	}

func _validate_real_faction_matchup_presentation_smoke() -> void:
	var original_speed := SettingsService.battle_playback_speed_id()
	SettingsService.ensure_settings()
	SettingsService.settings["gameplay"]["battle_playback_speed"] = SettingsService.BATTLE_PLAYBACK_SPEED_FAST
	var cases := [
		{
			"id": "thornwake_veilmourn",
			"player_unit": "unit_thornwake_barkmantle_rams",
			"enemy_unit": "unit_veilmourn_undertow_harpooners",
		},
		{
			"id": "brasshollow_embercourt",
			"player_unit": "unit_brasshollow_boiler_rivetcasters",
			"enemy_unit": "unit_embercourt_ash_oath_bailiffs",
		},
	]
	var results := {}
	for case in cases:
		var case_id := String(case.get("id", ""))
		var session := _basic_session(String(case.get("player_unit", "")), String(case.get("enemy_unit", "")), 4, 3, 5, 3)
		session.battle["turn_order"] = ["player_0", "player_0"]
		_set_stack_field(session.battle, "player_0", "total_health", 999)
		_set_stack_field(session.battle, "enemy_0", "total_health", 999)
		_set_stack_field(session.battle, "enemy_0", "retaliations_left", 0)
		var speed_result := BattleRulesScript.set_battle_presentation_speed(session, BattleRulesScript.PRESENTATION_SPEED_INSTANT)
		_expect_ok("%s speed set" % case_id, speed_result)
		var result := BattleRulesScript.perform_player_action(session, "strike")
		_expect_ok("%s strike" % case_id, result)
		var event_types := _presentation_event_types(session.battle)
		for expected_type in ["strike", "damage"]:
			if expected_type not in event_types:
				_error("%s real-faction stream missing %s in %s." % [case_id, expected_type, BattleRulesScript.battle_presentation_event_stream(session.battle)])
		var stream_text := BattleRulesScript.describe_battle_presentation_stream(session, 4)
		if not stream_text.to_lower().contains("damage"):
			_error("%s real-faction shell stream does not read as damage: %s." % [case_id, stream_text])
		SessionState.set_active_session(session)
		var frame := Control.new()
		frame.name = "%sBattlePresentationSmokeFrame" % case_id
		frame.size = Vector2(1024.0, 640.0)
		add_child(frame)
		var shell = load("res://scenes/battle/BattleShell.tscn").instantiate()
		frame.add_child(shell)
		await get_tree().process_frame
		await get_tree().process_frame
		if shell.has_method("validation_set_battle_resolution_routing_enabled"):
			shell.call("validation_set_battle_resolution_routing_enabled", false)
		if shell.has_method("_refresh"):
			shell.call("_refresh")
		await get_tree().process_frame
		var snapshot: Dictionary = shell.call("validation_snapshot") if shell.has_method("validation_snapshot") else {}
		var shell_stream := String(snapshot.get("battle_presentation_stream_text", ""))
		if shell_stream == "" or not shell_stream.to_lower().contains("damage"):
			_error("%s shell did not consume the real-faction presentation stream: %s." % [case_id, snapshot])
		_expect_equal("%s shell speed" % case_id, String(snapshot.get("battle_presentation_speed", "")), BattleRulesScript.PRESENTATION_SPEED_FAST)
		if case_id == "thornwake_veilmourn":
			shell.call("_set_battle_presentation_speed", BattleRulesScript.PRESENTATION_SPEED_INSTANT)
			await get_tree().process_frame
			var changed_snapshot: Dictionary = shell.call("validation_snapshot")
			_expect_equal("battle control live speed", String(changed_snapshot.get("battle_presentation_speed", "")), BattleRulesScript.PRESENTATION_SPEED_INSTANT)
			_expect_equal("battle control stored speed", SettingsService.battle_playback_speed_id(), SettingsService.BATTLE_PLAYBACK_SPEED_INSTANT)
			SettingsService.set_battle_playback_speed_id(SettingsService.BATTLE_PLAYBACK_SPEED_FAST)
		results[case_id] = {
			"event_types": event_types,
			"stream_text": stream_text,
			"shell_stream": shell_stream,
			"speed": String(snapshot.get("battle_presentation_speed", "")),
		}
		frame.queue_free()
		await get_tree().process_frame
	SettingsService.set_battle_playback_speed_id(original_speed)
	_report["cases"]["real_faction_presentation_smoke"] = results

func _basic_session(player_unit_id: String, enemy_unit_id: String, player_q: int, player_r: int, enemy_q: int, enemy_r: int) -> SessionStateStoreScript.SessionData:
	return _session_for_stacks(
		[
			_stack(player_unit_id, "player", 0, "player_0", 8, player_q, player_r),
			_stack(enemy_unit_id, "enemy", 0, "enemy_0", 8, enemy_q, enemy_r),
		],
		"player_0",
		"enemy_0"
	)

func _session_for_stacks(stacks: Array, active_id: String, selected_id: String) -> SessionStateStoreScript.SessionData:
	var session := SessionStateStoreScript.SessionData.new(
		"battle-event-animation-state-report",
		"battle-event-animation-state-report",
		"hero_report",
		1,
		{},
		"normal",
		SessionStateStoreScript.LAUNCH_MODE_SKIRMISH
	)
	session.battle = {
		"round": 1,
		"max_rounds": 99,
		"distance": 1,
		"terrain": "plains",
		"battlefield_tags": [],
		"combat_seed": 12345,
		"stacks": stacks,
		"turn_order": [active_id],
		"turn_index": 0,
		"active_stack_id": active_id,
		"selected_target_id": selected_id,
		"recent_events": [],
		"retreat_allowed": true,
		"surrender_allowed": true,
		"player_commander_state": {},
		"enemy_hero": {},
		BattleRulesScript.FIELD_OBJECTIVES_KEY: [],
		BattleRulesScript.STACK_ANIMATION_STATES_KEY: {},
		BattleRulesScript.ANIMATION_EVENT_SERIAL_KEY: 0,
	}
	BattleRulesScript._ensure_battle_hex_state(session.battle)
	return session

func _stack(unit_id: String, side: String, index: int, battle_id: String, count: int, q: int, r: int) -> Dictionary:
	var stack: Dictionary = BattleRulesScript._build_battle_stack(
		unit_id,
		count,
		side,
		index,
		{"source_type": "battle_event_animation_state_report"}
	)
	stack["battle_id"] = battle_id
	stack["side"] = side
	stack["hex"] = {"q": q, "r": r}
	return stack

func _spellcaster_state(known_spell_ids: Array = ["spell_cinder_burst"]) -> Dictionary:
	return {
		"name": "Report Caster",
		"command": {"power": 2, "knowledge": 8},
		"spellbook": {
			"known_spell_ids": known_spell_ids,
			"mana": {"current": 40, "max": 40},
		},
	}

func _set_stack_effects(battle: Dictionary, battle_id: String, effects: Array) -> void:
	var stacks: Array = battle.get("stacks", []) if battle.get("stacks", []) is Array else []
	for index in range(stacks.size()):
		var stack = stacks[index]
		if stack is Dictionary and String(stack.get("battle_id", "")) == battle_id:
			stack["effects"] = effects.duplicate(true)
			stacks[index] = stack
			battle["stacks"] = stacks
			return
	_error("Missing stack %s while setting status effects." % battle_id)

func _status_effect(effect_id: String, label: String, expires_after_round: int) -> Dictionary:
	return {
		"effect_id": effect_id,
		"label": label,
		"kind": effect_id,
		"amount": 1,
		"modifiers": {"initiative": -1},
		"expires_after_round": expires_after_round,
		"source_type": "battle_event_animation_state_report",
		"source_id": effect_id,
		"spell_id": "",
	}

func _stack_has_effect(stack: Dictionary, effect_id: String) -> bool:
	for effect in stack.get("effects", []):
		if effect is Dictionary and String(effect.get("effect_id", "")) == effect_id:
			return true
	return false

func _stack_by_id(battle: Dictionary, battle_id: String) -> Dictionary:
	return BattleRulesScript._get_stack_by_id(battle, battle_id)

func _state_for(session: SessionStateStoreScript.SessionData, battle_id: String) -> String:
	return BattleRulesScript.animation_state_for_stack(session.battle, _stack_by_id(session.battle, battle_id))

func _board_summary_for_session(session: SessionStateStoreScript.SessionData) -> Dictionary:
	var view := BattleBoardViewScript.new()
	view.size = Vector2(960.0, 540.0)
	add_child(view)
	view.set_battle_state(session)
	var summary: Dictionary = view.validation_unit_art_summary()
	view.queue_free()
	return summary

func _board_summary_for_session_after_audio(session: SessionStateStoreScript.SessionData) -> Dictionary:
	var view := BattleBoardViewScript.new()
	view.size = Vector2(960.0, 540.0)
	add_child(view)
	view.set_battle_state(session)
	var scheduled_summary: Dictionary = view.validation_unit_art_summary()
	var summary: Dictionary = scheduled_summary.duplicate(true)
	var audio_summary: Dictionary = scheduled_summary.get("audio_playback", {}) if scheduled_summary.get("audio_playback", {}) is Dictionary else {}
	for _attempt in range(12):
		await get_tree().create_timer(0.04).timeout
		audio_summary = view.validation_audio_playback_summary()
		if int(audio_summary.get("scheduled_record_count", 0)) == 0:
			break
	summary["audio_playback"] = audio_summary
	view.queue_free()
	return summary

func _set_stack_field(battle: Dictionary, battle_id: String, key: String, value: Variant) -> void:
	var stacks: Array = battle.get("stacks", []) if battle.get("stacks", []) is Array else []
	for index in range(stacks.size()):
		var stack = stacks[index]
		if stack is Dictionary and String(stack.get("battle_id", "")) == battle_id:
			stack[key] = value
			stacks[index] = stack
			battle["stacks"] = stacks
			BattleRulesScript._ensure_battle_hex_state(battle)
			return

func _observed_animation_states(summary: Dictionary) -> Dictionary:
	var observed_states := {}
	for entry in summary.get("stacks", []):
		if entry is Dictionary:
			observed_states[String(entry.get("battle_id", ""))] = String(entry.get("animation_state", ""))
	return observed_states

func _presentation_event_types(battle: Dictionary) -> Array:
	var types := []
	for event in BattleRulesScript.battle_presentation_event_stream(battle):
		if not (event is Dictionary):
			continue
		var event_type := String(event.get("event_type", ""))
		if event_type != "" and event_type not in types:
			types.append(event_type)
	return types

func _cue_record_for(cue_playback: Dictionary, battle_id: String) -> Dictionary:
	var records: Dictionary = cue_playback.get("active_records", {}) if cue_playback.get("active_records", {}) is Dictionary else {}
	return records.get(battle_id, {}) if records.get(battle_id, {}) is Dictionary else {}

func _summary_stack_entry(summary: Dictionary, battle_id: String) -> Dictionary:
	var stacks: Array = summary.get("stacks", []) if summary.get("stacks", []) is Array else []
	for entry in stacks:
		if entry is Dictionary and String(entry.get("battle_id", "")) == battle_id:
			return entry
	_error("Missing board stack entry for %s in %s." % [battle_id, summary])
	return {}

func _vfx_entry_for(vfx_playback: Dictionary, kind: String) -> Dictionary:
	var entries: Array = vfx_playback.get("active_draw_entries", []) if vfx_playback.get("active_draw_entries", []) is Array else []
	for entry in entries:
		if entry is Dictionary and String(entry.get("kind", "")) == kind:
			return entry
	_error("Missing VFX draw entry kind %s in %s." % [kind, vfx_playback])
	return {}

func _vfx_entry_for_cue(vfx_playback: Dictionary, cue_id: String) -> Dictionary:
	var entries: Array = vfx_playback.get("active_draw_entries", []) if vfx_playback.get("active_draw_entries", []) is Array else []
	for entry in entries:
		if entry is Dictionary and String(entry.get("cue_id", "")) == cue_id:
			return entry
	_error("Missing VFX draw entry cue %s in %s." % [cue_id, vfx_playback])
	return {}

func _vfx_image_metrics(texture_path: String) -> Dictionary:
	var image := Image.load_from_file(ProjectSettings.globalize_path(texture_path))
	if image == null or image.is_empty():
		return {"loaded": false, "size": [], "transparent_corners": false, "alpha_coverage": 0.0, "sha256": ""}
	var width := image.get_width()
	var height := image.get_height()
	var visible_pixels := 0
	for y in range(height):
		for x in range(width):
			if image.get_pixel(x, y).a > 0.01:
				visible_pixels += 1
	var corners := [
		image.get_pixel(0, 0).a,
		image.get_pixel(width - 1, 0).a,
		image.get_pixel(0, height - 1).a,
		image.get_pixel(width - 1, height - 1).a,
	]
	return {
		"loaded": true,
		"size": [width, height],
		"transparent_corners": corners.all(func(alpha): return float(alpha) <= 0.01),
		"alpha_coverage": snappedf(float(visible_pixels) / float(maxi(width * height, 1)), 0.0001),
		"sha256": FileAccess.get_sha256(texture_path),
	}

func _audio_record_for(audio_playback: Dictionary, battle_id: String) -> Dictionary:
	var records: Dictionary = audio_playback.get("active_records", {}) if audio_playback.get("active_records", {}) is Dictionary else {}
	return records.get(battle_id, {}) if records.get(battle_id, {}) is Dictionary else {}

func _audio_asset_path_for(audio_record: Dictionary, audio_id: String) -> String:
	var records: Array = audio_record.get("asset_playbacks", []) if audio_record.get("asset_playbacks", []) is Array else []
	for record in records:
		if not (record is Dictionary):
			continue
		if String(record.get("audio_id", "")) == audio_id:
			return String(record.get("asset_path", ""))
	return ""

func _audio_voice_for(audio_playback: Dictionary, audio_id: String) -> Dictionary:
	var voices: Array = audio_playback.get("active_voice_mix", []) if audio_playback.get("active_voice_mix", []) is Array else []
	for voice in voices:
		if voice is Dictionary and String(voice.get("audio_id", "")) == audio_id:
			return voice
	_error("Missing active audio voice %s in %s." % [audio_id, audio_playback])
	return {}

func _expect_event(label: String, battle: Dictionary, battle_id: String, event_id: String, state: String) -> void:
	for event in BattleRulesScript.animation_event_queue(battle):
		if not (event is Dictionary):
			continue
		if (
			String(event.get("battle_id", "")) == battle_id
			and String(event.get("event_id", "")) == event_id
			and String(event.get("state", "")) == state
		):
			return
	_error("%s missing event %s/%s for %s in %s." % [label, event_id, state, battle_id, BattleRulesScript.animation_event_queue(battle)])

func _event_record_for(battle: Dictionary, battle_id: String, event_id: String) -> Dictionary:
	for event in BattleRulesScript.animation_event_queue(battle):
		if event is Dictionary and String(event.get("battle_id", "")) == battle_id and String(event.get("event_id", "")) == event_id:
			return event
	_error("Missing event record %s for %s in %s." % [event_id, battle_id, BattleRulesScript.animation_event_queue(battle)])
	return {}

func _expect_ok(label: String, result: Dictionary) -> void:
	if not bool(result.get("ok", false)):
		_error("%s failed: %s" % [label, result])

func _expect_equal(label: String, actual: String, expected: String) -> void:
	if actual != expected:
		_error("%s expected %s but got %s." % [label, expected, actual])

func _expect_int(label: String, actual: int, expected: int) -> void:
	if actual != expected:
		_error("%s expected %d but got %d." % [label, expected, actual])

func _expect_array_contains(label: String, values: Variant, expected: String) -> void:
	if not (values is Array):
		_error("%s expected an array containing %s but got %s." % [label, expected, values])
		return
	if expected not in values:
		_error("%s expected %s in %s." % [label, expected, values])

func _write_json(path: String, payload: Dictionary) -> void:
	var file := FileAccess.open(ProjectSettings.globalize_path(path), FileAccess.WRITE)
	if file == null:
		_error("Failed to open %s for writing." % path)
		return
	file.store_string(JSON.stringify(payload, "\t"))

func _summary_payload() -> Dictionary:
	var cases: Dictionary = _report.get("cases", {}) if _report.get("cases", {}) is Dictionary else {}
	return {
		"ok": bool(_report.get("ok", false)),
		"case_count": cases.size(),
		"cases": cases.keys(),
	}

func _error(message: String) -> void:
	_errors.append(message)
	push_error(message)
