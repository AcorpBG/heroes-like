#!/usr/bin/env python3
"""All-spell art routing and 44 real casts, using source and immutable releases."""
import sys
import combat_vfx_regression as vfx

ROOT = vfx.ROOT
OUTPUT = ROOT / '.artifacts/spell-variety-20260917'
run_probe = vfx.run_probe
probe_environment = vfx.probe_environment
COMPILED_OWNERS = vfx.COMPILED_OWNERS

# Reuse the established isolated runner, real fixture and phase-capture helper.
SCRIPT = (vfx.SCRIPT.split('func _ready()')[0]
          + vfx.SCRIPT[vfx.SCRIPT.index('func pure_checks()'):vfx.SCRIPT.index('func case_session(')]
          + vfx.SCRIPT[vfx.SCRIPT.index('func sample('):vfx.SCRIPT.index('func run()')]
          + r'''
var changed_spells := []
var families_seen := []
var profiles_seen := []
var captured_families := []
var actual_casts := 0
func _ready() -> void: call_deferred("run")
func resolution_for(spell: Dictionary) -> String:
	match String(spell.effect.type):
		"damage_enemy": return "damage"
		"recover_ally": return "recover_effect"
		"cleanse_ally": return "cleanse_effect"
	return "effect"
func check_catalog(board: Control, manifest: Dictionary) -> void:
	var spells: Array = ContentService.load_json("res://content/spells.json").items
	var battle_ids := []
	for spell in spells:
		if spell.context != "battle": continue
		var spell_id := String(spell.id)
		battle_ids.append(spell_id)
		var expected := "vfx_" + spell_id
		var actual: String = board._spell_specific_vfx_cue_id(spell_id, resolution_for(spell))
		check(manifest.spell_cues.get(spell_id, "") == expected and actual == expected, "missing/wrong exact routing: " + spell_id)
		var cue: Dictionary = manifest.cues.get(actual, {})
		check(cue.get("spell_id", "") == spell_id, "cue owner mismatch: " + spell_id)
		check(board._battle_vfx_texture_for_path(cue.get("texture_path", "")) != null, "missing imported texture: " + spell_id)
		if not cue.has("effect_family"): continue
		changed_spells.append(spell_id)
		var family := String(cue.effect_family)
		var profile := String(cue.motion_profile)
		if family not in families_seen: families_seen.append(family)
		if profile not in profiles_seen: profiles_seen.append(profile)
		check(profile in Motion.SPELL_PROFILES, "unsupported motion: " + spell_id)
		var event := {"event_id":"battle_unit_cast", "spell_id":spell_id, "resolution_type":"effect"}
		var ids: Array = board._spell_specific_vfx_cue_ids_for_event(event, ["vfx_placeholder_cast_anchor", "vfx_placeholder_status_residue"])
		check(ids == [expected], "shared cast halos obscure new art: " + spell_id)
		var entry := {"progress":0.2,"hex_radius":40.0,"start_x":20.0,"start_y":50.0,"end_x":250.0,"end_y":150.0,"center_x":20.0,"center_y":50.0}
		var snapshots := []
		for phase in [0.2, 0.5, 0.8]:
			entry.progress = phase
			var layers := Motion.layers(cue, entry, {})
			snapshots.append(layers)
			check(not layers.is_empty() and layers.size() <= 3, "unbounded/empty family motion: " + spell_id)
			for layer in layers:
				check(layer.center.distance_to(Vector2(250,150-40*0.62)) < 40.0, "effect moved off target: " + spell_id)
				check(layer.extent <= 40.0 * 3.6 and layer.alpha > 0.0 and layer.alpha < 0.80, "family obscures board or has zero-alpha work: " + spell_id)
			var translated: Dictionary = entry.duplicate(true)
			translated.end_x += 300.0
			translated.end_y += 80.0
			var moved := Motion.layers(cue, translated, {})
			check(moved.size() == layers.size(), "target translation changed layer count")
			for index in range(layers.size()):
				check(moved[index].center.is_equal_approx(layers[index].center + Vector2(300,80)), "spell is caster/canvas anchored: " + spell_id)
		check(snapshots[0] != snapshots[1] and snapshots[1] != snapshots[2], "static normal spell playback: " + spell_id)
		entry.progress = 0.45
		var normal := Motion.layers(cue,entry,{})
		var quiet := Motion.layers(cue,entry,{"reduced_motion":true})
		check(quiet.size()==1 and quiet[0].role=="reduced_static", "quiet mode moves family art")
		check(quiet[0].center.is_equal_approx(Vector2(250,150-40*0.62)), "quiet mode loses target")
		check(Motion.layers(cue,entry,{}) == normal, "presentation randomness: " + spell_id)
	check(battle_ids.size()==97 and manifest.spell_cues.size()==battle_ids.size(), "spell catalogue is not fully covered")
	check(changed_spells.size()==44 and families_seen.size()==21 and profiles_seen.size()==7, "variety coverage drift")
	check(board._spell_specific_vfx_cue_id("unknown_spell", "damage")=="", "unknown damage falsely claims authored art")
	# Existing spell-specific identities and their base cue composition stay intact.
	var old_event := {"event_id":"battle_unit_cast", "spell_id":"spell_cinder_burst", "resolution_type":"damage"}
	check(board._spell_specific_vfx_cue_ids_for_event(old_event,["vfx_placeholder_cast_anchor"])==["vfx_spell_cinder_burst","vfx_placeholder_cast_anchor"], "existing effect composition changed")
func spell_fixture(spell_id: String):
	var session = fixture()
	session.battle.player_commander_state = {"id":"spell_variety_caster","name":"Spell variety caster","command":{"power":2,"knowledge":12},"spellbook":{"known_spell_ids":[spell_id],"mana":{"current":80,"max":80}}}
	return session
func run() -> void:
	out = OS.get_environment("BATTLE_READABILITY_OUT")
	pure_checks()
	SettingsService.set_battle_playback_speed_id(OS.get_environment("BATTLE_READABILITY_SPEED"))
	SettingsService.set_reduced_motion_enabled(false)
	SettingsService.set_reduced_flashes_enabled(false)
	SettingsService.set_presentation_mode("windowed")
	SettingsService.set_presentation_resolution(OS.get_environment("TOWN_OVERLAY_RESOLUTION"))
	var initial = SessionState.set_active_session(fixture())
	var shell = load("res://scenes/battle/BattleShell.tscn").instantiate()
	add_child(shell)
	for i in range(8): await get_tree().process_frame
	var parts := OS.get_environment("TOWN_OVERLAY_RESOLUTION").split("x")
	var requested := Vector2i(int(parts[0]),int(parts[1]))
	if DisplayServer.get_name() != "headless": DisplayServer.window_set_size(requested)
	get_tree().root.size = requested
	get_tree().root.content_scale_size = requested
	for i in range(4): await get_tree().process_frame
	var board: Control = shell._battle_board_view
	var manifest: Dictionary = ContentService.load_json("res://content/battle_vfx_manifest.json")
	check_catalog(board,manifest)
	for spell_id in changed_spells:
		var spell: Dictionary = ContentService.get_spell(spell_id)
		var live = spell_fixture(spell_id)
		var target_id: String = live.battle.stacks[1].battle_id if spell.effect.type=="control_enemy" else live.battle.stacks[0].battle_id
		SessionState.set_active_session(live)
		shell._session = live
		shell._refresh()
		board.finish_action_playback(live)
		# Shell refresh normalizes the newly installed fixture. Both casting
		# paths must start from that same normalized state, not an earlier copy.
		var direct = Store.new_session_data()
		direct.from_dict(live.to_dict().duplicate(true))
		var result: Dictionary = BattleRules.perform_presented_action(live,"cast_spell:"+spell_id,{"target_id":target_id})
		var ordinary: Dictionary = BattleRules.cast_player_spell(direct,spell_id,target_id)
		check(result.ok and ordinary.ok,"actual cast failed: "+spell_id+" "+str(result.get("message","")))
		check(live.to_dict()==direct.to_dict(),"presentation changes gameplay/save/RNG: "+spell_id)
		if not result.ok: continue
		actual_casts += 1
		var committed: Dictionary = live.to_dict().duplicate(true)
		var cue_id := "vfx_" + String(spell_id)
		var spec: Dictionary = manifest.cues[cue_id]
		var matched := false
		for frame in result.get("playback_frames",[]):
			var layers: Array = sample(board,frame,0.45)
			var selected := layers.filter(func(layer):return layer.cue_id==cue_id)
			check(not layers.any(func(layer):return layer.cue_id=="vfx_spell_command_ward"),"normal cast exposes Command Ward: "+spell_id)
			if selected.is_empty(): continue
			matched = true
			var entries: Array = board._vfx_draw_entries(board._current_hex_layout(),board._stack_cells())
			for entry in entries:
				if entry.cue_id==cue_id:
					check(entry.target_battle_id==target_id and entry.asset_loaded,"runtime target/art mismatch: "+spell_id)
			if spec.effect_family not in captured_families:
				captured_families.append(spec.effect_family)
				for phase in [0.2,0.5,0.8]:
					sample(board,frame,phase)
					await capture(String(spec.effect_family)+"-"+str(int(phase*100)),requested)
			SettingsService.set_reduced_motion_enabled(true)
			var reduced: Array = sample(board,frame,0.5)
			check(reduced.all(func(layer):return layer.role=="reduced_static"),"live reduced mode moves effect")
			SettingsService.set_reduced_motion_enabled(false)
			break
		check(matched,"actual cast missing new family art: "+spell_id)
		check(live.to_dict()==committed,"phase/capture changed authority: "+spell_id)
		board.finish_action_playback(live)
		check(board._combat_vfx_layers(board._current_hex_layout(),board._stack_cells()).is_empty(),"effect survives playback completion")
	check(actual_casts==44 and captured_families.size()==21,"actual-cast/family coverage incomplete")
	# Fast/Instant are presentation policies, not additional gameplay actions.
	SettingsService.set_battle_playback_speed_id("instant")
	var instant = SessionState.set_active_session(spell_fixture(changed_spells[0]))
	shell._session = instant
	BattleRules.set_battle_presentation_speed(instant,"instant")
	shell._refresh()
	var skipped: Dictionary = shell._perform_action("cast_spell:"+String(changed_spells[0]))
	check(skipped.ok and not shell._action_playback_in_progress,"instant spell delayed/blocked: " + str(skipped.get("message", "")))
	check(board._combat_vfx_layers(board._current_hex_layout(),board._stack_cells()).is_empty(),"instant cast leaves effects")
	shell.queue_free()
	for i in range(3): await get_tree().process_frame
	print("BATTLE_READABILITY_REPORT "+JSON.stringify({"ok":failures.is_empty(),"checks":checks,"failures":failures,"catalog_battle_spells":97,"actual_casts":actual_casts,"families":families_seen,"profiles":profiles_seen,"captured_families":captured_families,"max_layers":max_layers,"runtime_cues":runtime_cues,"runtime_roles":runtime_roles,"resolution":[requested.x,requested.y]}))
	get_tree().quit(0 if failures.is_empty() else 1)
''')


def main():
    if '--platform' in sys.argv:
        import packaged_menu_and_turn_readability_regression as package
        package.ui = sys.modules[__name__]
        return package.main()
    vfx.runner.OUTPUT = OUTPUT
    vfx.runner.SCRIPT = SCRIPT
    vfx.runner.run_probe = run_probe
    vfx.runner.probe_environment = probe_environment
    return vfx.runner.main()


if __name__ == '__main__':
    raise SystemExit(main())
