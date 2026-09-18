#!/usr/bin/env python3
"""Fresh native sessions omit town support pairs; source objects/saves survive."""
import json
import os
from pathlib import Path
import sys

import battle_readability_regression as runner

ROOT = runner.ROOT
OUTPUT = ROOT / '.artifacts/town-supply-removal-20260918'
run_probe = runner.run_probe
probe_environment = runner.probe_environment
COMPILED_OWNERS = ('scripts/persistence/NativeRandomMapPackageSessionBridge.gdc',
                   'scripts/persistence/GeneratedNeutralEncounterRules.gdc',
                   'scripts/core/ScenarioFactory.gdc', 'scripts/core/OverworldRules.gdc')
SCRIPT = r'''extends Node
const Select = preload("res://scripts/core/ScenarioSelectRules.gd")
const Bridge = preload("res://scripts/persistence/NativeRandomMapPackageSessionBridge.gd")
const Levels = preload("res://scripts/core/OverworldLevelRules.gd")
const Store = preload("res://scripts/core/SessionStateStore.gd")
const SITE := "site_generated_town_required_source_cache"
const SUPPORT := "h3maped_small_town_source_support_"
var failures := []
var checks := 0
var cases := []
var out := ""
func _ready() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message)
func normalized(value: Variant) -> Variant: return JSON.parse_string(JSON.stringify(value))
func ids(rows: Array) -> Array:
	var result := rows.map(func(row): return String(row.get("placement_id", "")))
	result.sort()
	return result
func verify(session, adoption: Dictionary, label: String) -> void:
	var objects := Bridge._document_objects(adoption.map_document)
	check(ids(objects) == ids(session.overworld.package_source_objects_by_id.values()), label + ": source object identities changed")
	for object in objects:
		check(normalized(session.overworld.package_source_objects_by_id[object.placement_id]) == normalized(object), label + ": native object/masks changed " + String(object.placement_id))
	var expected_nodes := Bridge._resource_nodes_from_document(adoption.map_document)
	check(ids(expected_nodes) == ids(session.overworld.resource_nodes), label + ": resource placements were added/removed")
	for node in session.overworld.resource_nodes:
		check(not String(node.placement_id).begins_with(SUPPORT), label + ": per-town support survives")
		check(String(node.get("site_id", "")) != SITE, label + ": generated town cache survives")
	var guards := Bridge._ensure_generated_guarded_reward_site_guards(expected_nodes, Bridge._ensure_generated_rare_source_guards(expected_nodes, Bridge._encounters_from_document(adoption.map_document)), session.overworld.map_size)
	check(ids(guards) == ids(session.overworld.encounters), label + ": normal native/rare/reward guards changed")
	for guard in session.overworld.encounters:
		check(not SUPPORT in String(guard.placement_id) and not String(guard.get("target_placement_id", "")).begins_with(SUPPORT), label + ": orphaned support guard")
	check(session.overworld.map == Bridge._map_rows_from_document(adoption.map_document), label + ": native terrain changed")
	check(normalized(session.overworld.terrain_layers) == normalized(Bridge._terrain_layers_from_document(adoption.map_document)), label + ": native layers changed")
	var owned: Array = session.overworld.towns.filter(func(town): return town.owner == "player")
	check(not owned.is_empty(), label + ": missing player town")
	if not owned.is_empty():
		check(Levels.position(session.overworld.hero_position) == Levels.town_entrance(owned[0]), label + ": hero no longer starts at own town entrance")
func persisted(service, adoption: Dictionary, generated: Dictionary, config: Dictionary, index: int):
	var map_path := "user://maps/town-supply-removal-%d.amap" % index
	var scenario_path := "user://maps/town-supply-removal-%d.ascenario" % index
	var saved: Dictionary = service.save_map_package(adoption.map_document, map_path)
	check(bool(saved.get("ok", false)), "map package write")
	if not saved.get("ok", false): return null
	var map_load: Dictionary = service.load_map_package(map_path)
	var doc = adoption.scenario_document
	doc.configure({"scenario_id":doc.get_scenario_id(), "scenario_hash":doc.get_scenario_hash(), "map_ref":map_load.map_ref, "selection":doc.get_selection(), "player_slots":doc.get_player_slots(), "objectives":doc.get_objectives(), "script_hooks":doc.get_script_hooks(), "enemy_factions":doc.get_enemy_factions(), "start_contract":doc.get_start_contract()})
	saved = service.save_scenario_package(doc, scenario_path)
	check(bool(saved.get("ok", false)), "scenario package write")
	if not saved.get("ok", false): return null
	var scenario_load: Dictionary = service.load_scenario_package(scenario_path)
	var boundary: Dictionary = adoption.session_boundary_record.duplicate(true)
	boundary.merge({"map_package_ref":map_load.map_ref, "scenario_package_ref":scenario_load.scenario_ref, "map_package_path":map_path, "scenario_package_path":scenario_path}, true)
	var startup := {"map_path":map_path, "scenario_path":scenario_path, "map_ref":map_load.map_ref, "scenario_ref":scenario_load.scenario_ref, "session_boundary_record":boundary}
	var retry := Select._random_map_retry_status(generated, generated.get("validation_report", {}))
	var identity := Select._native_random_map_generated_identity(generated, adoption, startup)
	var provenance := Select._native_random_map_provenance(config, generated, adoption, startup, retry)
	return Select.start_random_map_skirmish_session_from_setup({"ok":true, "package_startup":startup, "provenance":provenance, "replay_metadata":Select._random_map_replay_metadata(provenance, identity, retry), "validation":generated.get("validation_report", {}), "retry_status":retry})
func save_roundtrip(session, label: String) -> void:
	var before: Dictionary = normalized(session.to_dict())
	check(SaveService.save_session(before, 1) != "", label + ": save failed")
	var restored = SaveService.restore_manual_session(1)
	check(restored != null, label + ": restore failed")
	if restored == null:
		var summary: Dictionary = SaveService.inspect_manual_slot(1).duplicate(true)
		summary.erase("payload")
		print("RESTORE_DIAGNOSTIC " + JSON.stringify(summary))
		return
	for key in ["resource_nodes", "encounters", "towns", "hero_position", "map", "terrain_layers"]:
		check(normalized(restored.overworld.get(key)) == before.overworld.get(key), label + ": save changed " + key)
	check(restored.save_version == Store.SAVE_VERSION, label + ": save schema changed")
func legacy_pair(session) -> void:
	# A representative old saved pair must remain playable, not silently stripped.
	var old = Store.new_session_data()
	old.from_dict(session.to_dict().duplicate(true))
	var tile: Dictionary = old.overworld.hero_position.duplicate(true)
	var legacy := {"placement_id": SUPPORT + "legacy_fixture_required_sources", "site_id":SITE, "x":tile.x, "y":tile.y, "level":tile.get("level", 0), "visit_tile":tile.duplicate(), "owner":"neutral", "collected":false, "generated_package_source_policy":"town_required_source_route_support"}
	old.overworld.resource_nodes.append(legacy)
	var guard := Bridge._supplemental_rare_source_guard(legacy)
	check(not guard.is_empty(), "legacy guard/content no longer resolves")
	old.overworld.encounters.append(guard)
	OverworldRules.normalize_overworld_state(old)
	check(old.overworld.resource_nodes.any(func(node): return node.placement_id == legacy.placement_id), "normalization removed saved cache")
	check(old.overworld.encounters.any(func(row): return row.placement_id == guard.placement_id), "normalization removed saved guard")
	save_roundtrip(old, "legacy")
func run() -> void:
	out = OS.get_environment("BATTLE_READABILITY_OUT")
	check(ClassDB.class_exists("MapPackageService"), "native service unavailable")
	if not ClassDB.class_exists("MapPackageService"): return finish()
	var service = ClassDB.instantiate("MapPackageService")
	var configs := [
		["small", "165429308", 2, false],
		["medium", "10", 2, false],
		["medium", "10", 2, true],
	]
	for index in range(configs.size()):
		var row: Array = configs[index]
		var label := "%s-%s-levels%d" % [row[0], row[1], 2 if row[3] else 1]
		var config := Select.build_random_map_player_config(row[1], "", "", row[2], "land", row[3], "homm3_" + row[0], Select.RANDOM_MAP_TEMPLATE_SELECTION_MODE_CATALOG_AUTO, "faction_embercourt", "")
		var generated: Dictionary = service.generate_random_map(config)
		check(bool(generated.get("ok", false)), label + ": native generation failed: " + String(generated.get("error_code", "")))
		if not generated.get("ok", false): continue
		var adoption: Dictionary = service.convert_generated_payload(generated, {"feature_gate":"town_supply_removal", "session_save_version":Store.SAVE_VERSION})
		check(bool(adoption.get("ok", false)), label + ": package conversion failed")
		if not adoption.get("ok", false): continue
		var original_objects: Array = normalized(Bridge._document_objects(adoption.map_document))
		var session = Bridge.build_session_from_adoption(adoption)
		verify(session, adoption, label)
		var repeated = Bridge.build_session_from_adoption(adoption)
		for key in ["resource_nodes", "encounters", "towns", "hero_position", "map", "terrain_layers"]:
			check(normalized(session.overworld.get(key)) == normalized(repeated.overworld.get(key)), label + ": repeat adoption drift " + key)
		check(original_objects == normalized(Bridge._document_objects(adoption.map_document)), label + ": adoption mutated package")
		var disk = persisted(service, adoption, generated, config, index)
		check(disk != null, label + ": disk session missing")
		if disk == null: continue
		verify(disk, adoption, label + "-disk")
		save_roundtrip(disk, label)
		var owners := {}
		for town in disk.overworld.towns: owners[town.owner] = int(owners.get(town.owner, 0)) + 1
		cases.append({"case":label, "source_objects":original_objects.size(), "resources":disk.overworld.resource_nodes.size(), "guards":disk.overworld.encounters.size(), "town_owners":owners, "package_object_hash":JSON.stringify(original_objects).sha256_text()})
		if index == 1:
			legacy_pair(disk)
			SessionState.set_active_session(disk)
			var shell = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
			add_child(shell)
			for frame in range(8): await get_tree().process_frame
			if DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				check(get_viewport().get_texture().get_image().save_png(out.path_join("generated-town-without-supply-pair.png")) == OK, "capture failed")
			shell.queue_free()
			for frame in range(3): await get_tree().process_frame
	check(cases.size() == configs.size(), "not every native case completed")
	finish()
func finish() -> void:
	print("BATTLE_READABILITY_REPORT " + JSON.stringify({"ok":failures.is_empty(), "checks":checks, "failures":failures, "cases":cases}))
	get_tree().quit(0 if failures.is_empty() else 1)
'''


def main():
    if '--platform' in sys.argv:
        import packaged_menu_and_turn_readability_regression as package
        package.ui = sys.modules[__name__]
        label = sys.argv[sys.argv.index('--label') + 1]
        code = package.main()
        receipt = json.loads((Path(os.environ.get('HEROES_BATTLE_READABILITY_ARTIFACT_DIR', str(OUTPUT))) / label / 'packaged-report.json').read_text())
        if not receipt.get('original_probe_sha256') or receipt['original_probe_sha256'] != receipt.get('packaged_probe_sha256'):
            raise RuntimeError('Exact probe did not execute through the release bootstrap')
        return code
    runner.OUTPUT, runner.SCRIPT = OUTPUT, SCRIPT
    runner.run_probe, runner.probe_environment = run_probe, probe_environment
    return runner.main()


if __name__ == '__main__':
    raise SystemExit(main())
