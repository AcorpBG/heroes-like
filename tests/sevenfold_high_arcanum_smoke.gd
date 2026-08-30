extends Node

const MapViewScript = preload("res://scenes/overworld/OverworldMapView.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const REPORT_ID := "SEVENFOLD_HIGH_ARCANUM_SMOKE"
const OUTPUT_DIR := "res://.artifacts/sevenfold_high_arcanum_smoke"
const SCENARIO_ID := "third-hearths-confluence"
const ATLAS_PATH := "res://art/overworld/runtime/objects/resource_sites/sevenfold_high_arcanum_atlas.png"
const CASES := [
	{"site_id":"site_lastroad_bell_spire","placement_id":"third_arcanum_lastroad","spell_id":"spell_beacon_bell_lance_25","flag":"high_arcanum_lastroad_bell_sounded","command_key":"attack","asset_id":"resource_site_high_arcanum_lastroad_bell_spire","region":Rect2(0,0,48,48),"target_side":"enemy","resolution_type":"damage"},
	{"site_id":"site_siltheart_drum_cairn","placement_id":"third_arcanum_siltheart","spell_id":"spell_mire_silt_frenzy_20","flag":"high_arcanum_siltheart_drum_struck","command_key":"defense","asset_id":"resource_site_high_arcanum_siltheart_drum_cairn","region":Rect2(48,0,48,48),"target_side":"player","resolution_type":"effect"},
	{"site_id":"site_aurora_facet_orrery","placement_id":"third_arcanum_aurora","spell_id":"spell_lens_mirror_facet_20","flag":"high_arcanum_aurora_facets_aligned","command_key":"knowledge","asset_id":"resource_site_high_arcanum_aurora_facet_orrery","region":Rect2(96,0,48,48),"target_side":"player","resolution_type":"effect"},
	{"site_id":"site_bloombark_covenant_tree","placement_id":"third_arcanum_bloombark","spell_id":"spell_root_bloom_bark_20","flag":"high_arcanum_bloombark_covenant_bound","command_key":"defense","asset_id":"resource_site_high_arcanum_bloombark_covenant_tree","region":Rect2(144,0,48,48),"target_side":"player","resolution_type":"effect"},
	{"site_id":"site_slagbound_clamp_forge","placement_id":"third_arcanum_slagbound","spell_id":"spell_furnace_slag_clamp_15","flag":"high_arcanum_slagbound_clamp_set","command_key":"power","asset_id":"resource_site_high_arcanum_slagbound_clamp_forge","region":Rect2(192,0,48,48),"target_side":"enemy","resolution_type":"effect"},
	{"site_id":"site_mourning_tide_obelisk","placement_id":"third_arcanum_mourning","spell_id":"spell_veil_mourning_fogbind_20","flag":"high_arcanum_mourning_tide_rung","command_key":"knowledge","asset_id":"resource_site_high_arcanum_mourning_tide_obelisk","region":Rect2(240,0,48,48),"target_side":"enemy","resolution_type":"effect"},
	{"site_id":"site_sevencount_verdict_table","placement_id":"third_arcanum_sevencount","spell_id":"spell_old_measure_tally_tally_20","flag":"high_arcanum_sevencount_verdict_rendered","command_key":"power","asset_id":"resource_site_high_arcanum_sevencount_verdict_table","region":Rect2(288,0,48,48),"target_side":"enemy","resolution_type":"damage"},
]

var _errors: Array[String] = []
var _rows: Array = []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var scenario := ContentService.get_scenario(SCENARIO_ID)
	_expect(not scenario.is_empty(), "Third Hearths Confluence is not shipped.")
	_expect(scenario.get("resource_nodes", []).size() == 17, "Third Hearths must own ten prior nodes plus all seven high-arcanum landmarks.")
	var view = MapViewScript.new()
	view.size = Vector2(1280, 720)
	add_child(view)
	await get_tree().process_frame
	for case_value in CASES:
		await _validate_case(view, case_value)
	var atlas := Image.load_from_file(ProjectSettings.globalize_path(ATLAS_PATH))
	_expect(not atlas.is_empty() and atlas.get_size() == Vector2i(336, 48), "Sevenfold High Arcanum atlas is missing or malformed.")
	if not atlas.is_empty():
		atlas.save_png("%s/sevenfold_high_arcanum_strip.png" % OUTPUT_DIR)
	var report := {
		"ok": _errors.is_empty(),
		"scenario_id": SCENARIO_ID,
		"case_count": CASES.size(),
		"claim_count": _rows.size(),
		"battle_resolution_count": _rows.filter(func(row): return bool(row.get("battle_resolved", false))).size(),
		"save_version": SessionStateStoreScript.SAVE_VERSION,
		"single_consolidated_smoke": true,
		"visual_capture": "%s/sevenfold_high_arcanum_strip.png" % OUTPUT_DIR,
		"rows": _rows,
		"errors": _errors,
	}
	_write_json("%s/report.json" % OUTPUT_DIR, report)
	if _errors.is_empty():
		print("%s %s" % [REPORT_ID, JSON.stringify({"ok":true,"case_count":7,"battle_resolution_count":7,"save_version":SessionStateStoreScript.SAVE_VERSION,"single_consolidated_smoke":true})])
	view.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if _errors.is_empty() else 1)

func _validate_case(view: Control, case: Dictionary) -> void:
	var session = ScenarioFactory.create_session(SCENARIO_ID, "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state(session)
	var placement_id := String(case.get("placement_id", ""))
	var site_id := String(case.get("site_id", ""))
	var spell_id := String(case.get("spell_id", ""))
	_remove_known_spell(session, spell_id)
	var node_result := _node_result(session, placement_id)
	var node: Dictionary = node_result.get("node", {})
	var site := ContentService.get_resource_site(site_id)
	_expect(not node.is_empty() and String(node.get("site_id", "")) == site_id, "%s placement is missing." % site_id)
	_expect(String(site.get("runtime_boundary", {}).get("status", "")) == "high_arcanum_live", "%s is not live." % site_id)
	_expect(String(site.get("learn_spell_id", "")) == spell_id, "%s teaches the wrong spell." % site_id)
	var ready_id := String(view.call("_resource_asset_id", node))
	var ready_texture = view.call("_object_texture_for_asset", ready_id)
	_expect(ready_id == String(case.get("asset_id", "")), "%s lost exact landmark art." % site_id)
	_expect(ready_texture is AtlasTexture and ready_texture.atlas.resource_path == ATLAS_PATH and ready_texture.region == case.get("region"), "%s atlas region changed." % site_id)
	var before := _snapshot(session, case)
	var first := OverworldRules._collect_resource_node_result(session, node_result, true)
	_expect(bool(first.get("ok", false)), "%s first claim failed: %s" % [site_id, JSON.stringify(first)])
	if not bool(first.get("ok", false)):
		return
	var after := _snapshot(session, case)
	_expect(int(after.get("experience", 0)) - int(before.get("experience", 0)) == 140, "%s experience reward changed." % site_id)
	var command_key := String(case.get("command_key", ""))
	_expect(int(after.get("command", {}).get(command_key, 0)) - int(before.get("command", {}).get(command_key, 0)) == 1, "%s command lesson changed." % site_id)
	_expect(spell_id not in before.get("known_spell_ids", []) and spell_id in after.get("known_spell_ids", []), "%s did not teach its spell." % site_id)
	_expect(bool(session.flags.get(String(case.get("flag", "")), false)), "%s did not set its claim flag." % site_id)
	var claimed: Dictionary = _node_result(session, placement_id).get("node", {})
	_expect(bool(claimed.get("collected", false)), "%s did not persist collected state." % site_id)
	var authority_after := session.to_dict()
	var repeat := OverworldRules._collect_resource_node_result(session, _node_result(session, placement_id), true)
	_expect(not bool(repeat.get("ok", true)) and session.to_dict() == authority_after, "%s repeat claim mutated authority." % site_id)
	var restored := SessionStateStoreScript.SessionData.new()
	restored.from_dict(session.to_dict())
	_expect(restored.to_dict() == session.to_dict(), "%s save-version-9 round trip changed authority." % site_id)
	var resolution := _resolve_spell(restored.overworld.get("hero", {}), spell_id, String(case.get("target_side", "enemy")))
	_expect(bool(resolution.get("ok", false)) and String(resolution.get("resolution_type", "")) == String(case.get("resolution_type", "")), "%s battle resolution changed: %s" % [spell_id, JSON.stringify(resolution)])
	var spell := ContentService.get_spell(spell_id)
	_expect(not String(spell.get("description", "")).contains("another tactical choice"), "%s still exposes placeholder copy." % spell_id)
	var icon_path := SpellRules.spell_icon_path(spell_id)
	_expect(icon_path != "" and load(icon_path) is Texture2D, "%s lost its specific icon." % spell_id)
	_rows.append({"site_id":site_id,"placement_id":placement_id,"spell_id":spell_id,"asset_id":ready_id,"claim_flag":String(case.get("flag", "")),"repeat_blocked":true,"save_round_trip_exact":true,"battle_resolved":bool(resolution.get("ok", false)),"resolution_type":String(resolution.get("resolution_type", "")),"description_specific":true})

func _remove_known_spell(session, spell_id: String) -> void:
	var hero: Dictionary = session.overworld.get("hero", {})
	var spellbook: Dictionary = hero.get("spellbook", {})
	var known: Array = spellbook.get("known_spell_ids", []).duplicate(true)
	known.erase(spell_id)
	spellbook["known_spell_ids"] = known
	spellbook["mana"] = {"current": 60, "max": 60}
	hero["spellbook"] = spellbook
	session.overworld["hero"] = hero

func _snapshot(session, case: Dictionary) -> Dictionary:
	var hero: Dictionary = session.overworld.get("hero", {})
	return {"experience":int(hero.get("experience",0)),"command":hero.get("command",{}).duplicate(true),"known_spell_ids":hero.get("spellbook",{}).get("known_spell_ids",[]).duplicate(true),"flag":bool(session.flags.get(String(case.get("flag","")),false))}

func _resolve_spell(hero: Dictionary, spell_id: String, target_side: String) -> Dictionary:
	hero = hero.duplicate(true)
	var command: Dictionary = hero.get("command", {}).duplicate(true)
	command["knowledge"] = maxi(4, int(command.get("knowledge", 0)))
	hero["command"] = command
	var spellbook: Dictionary = hero.get("spellbook", {}).duplicate(true)
	spellbook["mana"] = {"current":60,"max":60}
	hero["spellbook"] = spellbook
	var active := _battle_stack("arcanum_caster", "player")
	var target := _battle_stack("arcanum_target", target_side)
	var battle := {"round":1,"resistance_seed":"sevenfold_%s" % spell_id,"player_hero":{"battle_spell_resistance_pct":0,"battle_control_resistance_pct":0,"battle_school_resistance_pct":{}},"enemy_hero_payload":{"battle_spell_resistance_pct":0,"battle_control_resistance_pct":0,"battle_school_resistance_pct":{}},"stacks":[active,target]}
	return SpellRules.resolve_battle_spell(hero, battle, active, target, spell_id)

func _battle_stack(battle_id: String, side: String) -> Dictionary:
	return {"battle_id":battle_id,"side":side,"name":battle_id.capitalize(),"base_count":12,"unit_hp":12,"total_health":144,"attack":7,"defense":7,"initiative":7,"cohesion":7,"effects":[],"spell_resistance_pct":0,"control_resistance_pct":0,"spell_school_resistance_pct":{},"status_immunity_ids":[]}

func _node_result(session, placement_id: String) -> Dictionary:
	var nodes: Array = session.overworld.get("resource_nodes", [])
	for index in range(nodes.size()):
		if nodes[index] is Dictionary and String(nodes[index].get("placement_id", "")) == placement_id:
			return {"index":index,"node":nodes[index]}
	return {"index":-1,"node":{}}

func _write_json(path: String, payload: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_error("Could not write %s." % path)
		return
	file.store_string(JSON.stringify(payload, "  ") + "\n")

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_error(message)

func _error(message: String) -> void:
	_errors.append(message)
	push_error("%s %s" % [REPORT_ID, message])
