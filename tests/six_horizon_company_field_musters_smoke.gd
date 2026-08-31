extends Node

const MapViewScript = preload("res://scenes/overworld/OverworldMapView.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const REPORT_ID := "SIX_HORIZON_COMPANY_FIELD_MUSTERS_SMOKE"
const OUTPUT_DIR := "res://.artifacts/six_horizon_company_field_musters_smoke"
const REPORT_PATH := OUTPUT_DIR + "/report.json"
const ATLAS_PATH := "res://art/overworld/runtime/objects/resource_sites/horizon_company_field_musters/horizon_company_field_musters_atlas.png"
const SCENARIO_ID := "horizon-compact-six-citadels"
const CASES := [
	{"faction_id":"faction_embercourt","site_id":"site_stormseal_powder_wharf","object_id":"object_stormseal_powder_wharf","placement_id":"horizon_stormseal_powder_wharf","unit_id":"unit_embercourt_cinderseal_bombardiers","claim_count":1,"weekly_count":1,"unclaimed":"mapobj_stormseal_powder_wharf","controlled":"resource_site_company_stormseal_powder_wharf_controlled","unclaimed_region":Rect2(0,0,48,48),"controlled_region":Rect2(48,0,48,48),"income":{"gold":45,"ore":1},"unclaimed_sha":"b17a516ca52178382df4c684f9b7daa7cc17d52ca00991f63d698d4c10c6974f","controlled_sha":"55dfff6604090735f0086053ffd8db584a422f8ba525222cefdbb02abe45e2c9"},
	{"faction_id":"faction_mireclaw","site_id":"site_moonwax_reed_circle","object_id":"object_moonwax_reed_circle","placement_id":"horizon_moonwax_reed_circle","unit_id":"unit_mireclaw_mireglass_reedcasters","claim_count":2,"weekly_count":1,"unclaimed":"mapobj_moonwax_reed_circle","controlled":"resource_site_company_moonwax_reed_circle_controlled","unclaimed_region":Rect2(96,0,48,48),"controlled_region":Rect2(144,0,48,48),"income":{"gold":30,"peatwax":1},"unclaimed_sha":"fc74dfed5e426632c4fcee6ea15984b2a0a385a3c7244deb402592c2889fd22d","controlled_sha":"45bf62d902c3ffd9d6cf2d3e3e3b0ff17ba7568cf82f8aa03de1b3fab332b30f"},
	{"faction_id":"faction_sunvault","site_id":"site_facet_vigil","object_id":"object_facet_vigil","placement_id":"horizon_facet_vigil","unit_id":"unit_sunvault_noonfacet_sentinels","claim_count":2,"weekly_count":1,"unclaimed":"mapobj_facet_vigil","controlled":"resource_site_company_facet_vigil_controlled","unclaimed_region":Rect2(192,0,48,48),"controlled_region":Rect2(240,0,48,48),"income":{"gold":40,"aetherglass":1},"unclaimed_sha":"0916c38f940572f0132917cdef6374a838773894e79b1c0f96534474c7e4cfcd","controlled_sha":"cbd9cc47bee1f06278703586cbc3015092616567ee4560b4970990438cdf8b05"},
	{"faction_id":"faction_thornwake","site_id":"site_heartseed_bolt_grove","object_id":"object_heartseed_bolt_grove","placement_id":"horizon_heartseed_bolt_grove","unit_id":"unit_thornwake_dawnseed_bolters","claim_count":2,"weekly_count":1,"unclaimed":"mapobj_heartseed_bolt_grove","controlled":"resource_site_company_heartseed_bolt_grove_controlled","unclaimed_region":Rect2(288,0,48,48),"controlled_region":Rect2(336,0,48,48),"income":{"gold":25,"wood":1},"unclaimed_sha":"fcf6c50b6a24862054999a672fd981eee8b3c012b63ad52dc4d6511a77600551","controlled_sha":"8bd3a7a0d096dd2df7867a373ec30bda69b5f92c56ea6d2ab91d212d1269327a"},
	{"faction_id":"faction_brasshollow","site_id":"site_blackbell_assay_watch","object_id":"object_blackbell_assay_watch","placement_id":"horizon_blackbell_assay_watch","unit_id":"unit_brasshollow_gaugeplate_bailiffs","claim_count":2,"weekly_count":1,"unclaimed":"mapobj_blackbell_assay_watch","controlled":"resource_site_company_blackbell_assay_watch_controlled","unclaimed_region":Rect2(384,0,48,48),"controlled_region":Rect2(432,0,48,48),"income":{"gold":35,"ore":1},"unclaimed_sha":"090abc3b2772dd9b2d854b759e373357cbf93c1e866b37f6153741e0d43450b6","controlled_sha":"0ffd9a865b98e02f0ca168558c44496ca7657f926cea2ae6002d5f6e00ec97ac"},
	{"faction_id":"faction_veilmourn","site_id":"site_last_memory_mooring","object_id":"object_last_memory_mooring","placement_id":"horizon_last_memory_mooring","unit_id":"unit_veilmourn_tidehook_deckhands","claim_count":5,"weekly_count":2,"unclaimed":"mapobj_last_memory_mooring","controlled":"resource_site_company_last_memory_mooring_controlled","unclaimed_region":Rect2(480,0,48,48),"controlled_region":Rect2(528,0,48,48),"income":{"gold":35,"memory_salt":1},"unclaimed_sha":"c39e0fd8302a54dc74435a49de79fc9b01067653095a9d8530e29c01930b8d12","controlled_sha":"35b93f3f2a463292715148942baa4c55dd49114bad22a8e08fb40ae5275ea891"},
]

var _errors: Array[String] = []
var _rows: Array = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	get_window().size = Vector2i(1280, 720)
	ContentService.clear_cache()
	var atlas := load(ATLAS_PATH) as Texture2D
	_expect(atlas != null and atlas.get_size() == Vector2(576, 48), "The twelve-state field-muster atlas must remain exactly 576x48.")
	var view = MapViewScript.new()
	view.size = Vector2(1280, 720)
	add_child(view)
	await get_tree().process_frame
	for case_value in CASES:
		await _run_case(view, case_value)
	var report := {"ok":_errors.is_empty(),"case_count":CASES.size(),"save_version":SessionStateStoreScript.SAVE_VERSION,"atlas_path":ATLAS_PATH,"rows":_rows,"errors":_errors}
	_write_json(REPORT_PATH, report)
	if _errors.is_empty():
		print("%s %s" % [REPORT_ID, JSON.stringify({"ok":true,"case_count":CASES.size(),"save_version":SessionStateStoreScript.SAVE_VERSION})])
	view.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if _errors.is_empty() else 1)


func _run_case(view: Control, case: Dictionary) -> void:
	var site_id := String(case.get("site_id", ""))
	var object_id := String(case.get("object_id", ""))
	var placement_id := String(case.get("placement_id", ""))
	var unit_id := String(case.get("unit_id", ""))
	var faction_id := String(case.get("faction_id", ""))
	var site := ContentService.get_resource_site(site_id)
	var map_object := ContentService.get_map_object(object_id)
	var unit := ContentService.get_unit(unit_id)
	_expect(String(site.get("content_status", "")) == "horizon_company_field_muster_live" and String(site.get("faction_id", "")) == faction_id, "%s lost its exact live faction-linked content contract." % site_id)
	_expect(String(map_object.get("resource_site_id", "")) == site_id and String(map_object.get("faction_id", "")) == faction_id, "%s lost its exact first-class map-object link." % object_id)
	_expect(String(unit.get("faction_id", "")) == faction_id, "%s is no longer the exact faction company for %s." % [unit_id, site_id])
	_expect(_single_entry_exact(site.get("claim_recruits", {}), unit_id, int(case.get("claim_count", 0))), "%s claim roster leaked or changed." % site_id)
	_expect(_single_entry_exact(site.get("weekly_recruits", {}), unit_id, int(case.get("weekly_count", 0))), "%s weekly roster leaked or changed." % site_id)
	_expect(_integer_dictionary_equal(site.get("control_income", {}), case.get("income", {})), "%s control income changed." % site_id)
	var source_base := "res://art/overworld/source/generated/resource_sites/horizon_company_field_musters/"
	var stem := site_id.trim_prefix("site_")
	var unclaimed_source := source_base + stem + "_unclaimed.png"
	var controlled_source := source_base + stem + "_controlled.png"
	var unclaimed_image := Image.load_from_file(ProjectSettings.globalize_path(unclaimed_source))
	var controlled_image := Image.load_from_file(ProjectSettings.globalize_path(controlled_source))
	_expect(not unclaimed_image.is_empty() and unclaimed_image.get_size() == Vector2i(887, 887) and unclaimed_image.detect_alpha() and FileAccess.get_sha256(unclaimed_source) == String(case.get("unclaimed_sha", "")), "%s unclaimed generated master changed." % site_id)
	_expect(not controlled_image.is_empty() and controlled_image.get_size() == Vector2i(887, 887) and controlled_image.detect_alpha() and FileAccess.get_sha256(controlled_source) == String(case.get("controlled_sha", "")), "%s controlled generated master changed." % site_id)

	var session = ScenarioFactory.create_session(SCENARIO_ID, "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state(session)
	var node_result := _resource_node_result(session, placement_id)
	var node: Dictionary = node_result.get("node", {})
	_expect(String(node.get("site_id", "")) == site_id, "%s is absent from the live six-citadel scenario." % placement_id)
	var pathing := OverworldRules.overworld_object_placement_pathing_surface(session, placement_id)
	_expect(String(pathing.get("object_id", "")) == object_id and int(pathing.get("body_tile_count", 0)) == 1 and int(pathing.get("interaction_tile_count", 0)) == 1, "%s lost its compact body or authored interaction tile." % placement_id)
	_expect(_reachable_after_front_clearance(session, pathing), "%s has no live route from the player start after existing battle fronts are cleared." % placement_id)
	var tile := Vector2i(int(node.get("x", 0)), int(node.get("y", 0)))
	_set_active_hero_position(session, tile)
	view.set_map_state(session, session.overworld.get("map", []), OverworldRules.derive_map_size(session), tile)
	await get_tree().process_frame
	var unclaimed_asset_id := String(view.call("_resource_asset_id", node))
	var unclaimed_texture = view.call("_object_texture_for_asset", unclaimed_asset_id)
	_expect(unclaimed_asset_id == String(case.get("unclaimed", "")), "%s lost its exact unclaimed landmark." % site_id)
	_expect(_exact_atlas_texture(unclaimed_texture, case.get("unclaimed_region")), "%s unclaimed landmark did not resolve its exact atlas region." % site_id)

	var rewards: Dictionary = site.get("claim_rewards", {})
	var resources_before := _resource_counts(session, rewards.keys())
	var army_before := _army_count(session, unit_id)
	var income_before := OverworldRules.controlled_resource_site_income(session, "player")
	var claim := OverworldRules._collect_resource_node_result(session, node_result, true)
	_expect(bool(claim.get("ok", false)), "%s production claim failed: %s" % [site_id, JSON.stringify(claim)])
	if not bool(claim.get("ok", false)):
		return
	_expect(_resource_delta_exact(resources_before, _resource_counts(session, rewards.keys()), rewards), "%s claim resources changed." % site_id)
	_expect(_army_count(session, unit_id) - army_before == int(case.get("claim_count", 0)), "%s did not add its exact company to the field army." % site_id)
	_expect(_resource_delta_exact(income_before, OverworldRules.controlled_resource_site_income(session, "player"), case.get("income", {})), "%s controlled income did not activate exactly." % site_id)
	_expect(bool(session.flags.get(stem + "_claimed", false)), "%s claim flag did not enter session authority." % site_id)
	var claimed_node: Dictionary = _resource_node_result(session, placement_id).get("node", {})
	view.set_map_state(session, session.overworld.get("map", []), OverworldRules.derive_map_size(session), tile)
	await get_tree().process_frame
	var controlled_asset_id := String(view.call("_resource_asset_id", claimed_node))
	var controlled_texture = view.call("_object_texture_for_asset", controlled_asset_id)
	_expect(controlled_asset_id == String(case.get("controlled", "")), "%s did not switch to its exact controlled landmark." % site_id)
	_expect(_exact_atlas_texture(controlled_texture, case.get("controlled_region")), "%s controlled landmark did not resolve its exact atlas region." % site_id)

	var town_recruits_before := _town_recruit_count(session, unit_id)
	var muster_messages := OverworldRules.apply_controlled_resource_site_musters(session, "player")
	_expect(not muster_messages.is_empty() and _town_recruit_count(session, unit_id) - town_recruits_before == int(case.get("weekly_count", 0)), "%s did not deliver its exact weekly company to the nearest held town." % site_id)
	var authority := session.to_dict()
	var repeat := OverworldRules._collect_resource_node_result(session, _resource_node_result(session, placement_id), true)
	_expect(not bool(repeat.get("ok", true)) and session.to_dict() == authority, "%s repeat claim mutated authority." % site_id)
	var capture_path := await _capture_if_requested(site_id)
	var restored := _clone_session(session)
	var restored_node: Dictionary = _resource_node_result(restored, placement_id).get("node", {})
	view.set_map_state(restored, restored.overworld.get("map", []), OverworldRules.derive_map_size(restored), tile)
	await get_tree().process_frame
	_expect(restored.to_dict() == session.to_dict() and int(restored.save_version) == SessionStateStoreScript.SAVE_VERSION, "%s did not round-trip exactly through save version %d." % [site_id, SessionStateStoreScript.SAVE_VERSION])
	_expect(String(view.call("_resource_asset_id", restored_node)) == controlled_asset_id, "%s restore lost its controlled-state art." % site_id)
	_rows.append({"site_id":site_id,"object_id":object_id,"placement_id":placement_id,"unit_id":unit_id,"unclaimed_asset_id":unclaimed_asset_id,"controlled_asset_id":controlled_asset_id,"claim_count":int(case.get("claim_count",0)),"weekly_count":int(case.get("weekly_count",0)),"income":case.get("income",{}),"reachable_after_front_clearance":true,"capture_path":capture_path,"save_round_trip_exact":restored.to_dict() == session.to_dict()})


func _resource_node_result(session: SessionStateStoreScript.SessionData, placement_id: String) -> Dictionary:
	var nodes: Array = session.overworld.get("resource_nodes", [])
	for index in range(nodes.size()):
		if nodes[index] is Dictionary and String(nodes[index].get("placement_id", "")) == placement_id:
			return {"index":index,"node":nodes[index]}
	return {"index":-1,"node":{}}


func _reachable_after_front_clearance(source: SessionStateStoreScript.SessionData, pathing: Dictionary) -> bool:
	var session := _clone_session(source)
	var resolved: Array = session.overworld.get("resolved_encounters", [])
	for encounter in session.overworld.get("encounters", []):
		if encounter is Dictionary and String(encounter.get("placement_id", "")) not in resolved:
			resolved.append(String(encounter.get("placement_id", "")))
	session.overworld["resolved_encounters"] = resolved
	var goals := {}
	for tile_value in pathing.get("interaction_tiles", []):
		if tile_value is Dictionary:
			goals[Vector2i(int(tile_value.get("x", -1)), int(tile_value.get("y", -1)))] = true
	var start_data: Dictionary = session.overworld.get("hero_position", {})
	var start := Vector2i(int(start_data.get("x", 0)), int(start_data.get("y", 0)))
	var map_size := OverworldRules.derive_map_size(session)
	var queue: Array[Vector2i] = [start]
	var seen := {start:true}
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		if goals.has(current):
			return true
		for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next_tile: Vector2i = current + Vector2i(direction)
			if next_tile.x < 0 or next_tile.y < 0 or next_tile.x >= map_size.x or next_tile.y >= map_size.y or seen.has(next_tile):
				continue
			if not goals.has(next_tile) and OverworldRules.tile_is_blocked(session, next_tile.x, next_tile.y):
				continue
			seen[next_tile] = true
			queue.append(next_tile)
	return false


func _exact_atlas_texture(texture: Variant, region_value: Variant) -> bool:
	return texture is AtlasTexture and texture.atlas != null and texture.atlas.resource_path == ATLAS_PATH and texture.region == region_value


func _single_entry_exact(value: Variant, key: String, count: int) -> bool:
	return value is Dictionary and value.size() == 1 and int(value.get(key, 0)) == count


func _integer_dictionary_equal(left_value: Variant, right_value: Variant) -> bool:
	if not (left_value is Dictionary) or not (right_value is Dictionary):
		return false
	var left: Dictionary = left_value
	var right: Dictionary = right_value
	if left.size() != right.size():
		return false
	for key_value in right.keys():
		if int(left.get(key_value, -999999)) != int(right.get(key_value, 0)):
			return false
	return true


func _resource_counts(session: SessionStateStoreScript.SessionData, keys: Array) -> Dictionary:
	var result := {}
	for key_value in keys:
		result[String(key_value)] = int(session.overworld.get("resources", {}).get(String(key_value), 0))
	return result


func _resource_delta_exact(before: Dictionary, after: Dictionary, expected_value: Variant) -> bool:
	if not (expected_value is Dictionary):
		return false
	for key_value in expected_value.keys():
		var key := String(key_value)
		if int(after.get(key, 0)) - int(before.get(key, 0)) != int(expected_value.get(key_value, 0)):
			return false
	return true


func _army_count(session: SessionStateStoreScript.SessionData, unit_id: String) -> int:
	var total := 0
	for stack in session.overworld.get("hero", {}).get("army", {}).get("stacks", []):
		if stack is Dictionary and String(stack.get("unit_id", "")) == unit_id:
			total += int(stack.get("count", 0))
	return total


func _town_recruit_count(session: SessionStateStoreScript.SessionData, unit_id: String) -> int:
	var total := 0
	for town in session.overworld.get("towns", []):
		if town is Dictionary:
			total += int(town.get("available_recruits", {}).get(unit_id, 0))
	return total


func _set_active_hero_position(session: SessionStateStoreScript.SessionData, tile: Vector2i) -> void:
	var position := {"x":tile.x,"y":tile.y}
	session.overworld["hero_position"] = position.duplicate(true)
	var active_hero: Dictionary = session.overworld.get("hero", {})
	active_hero["position"] = position.duplicate(true)
	session.overworld["hero"] = active_hero
	var heroes: Array = session.overworld.get("player_heroes", [])
	for index in range(heroes.size()):
		if heroes[index] is Dictionary and String(heroes[index].get("id", "")) == String(session.overworld.get("active_hero_id", "")):
			var hero: Dictionary = heroes[index]
			hero["position"] = position.duplicate(true)
			heroes[index] = hero
	session.overworld["player_heroes"] = heroes


func _clone_session(source: SessionStateStoreScript.SessionData) -> SessionStateStoreScript.SessionData:
	var clone := SessionStateStoreScript.SessionData.new()
	clone.from_dict(source.to_dict())
	return clone


func _capture_if_requested(stem: String) -> String:
	var capture_dir := OS.get_environment("HORIZON_COMPANY_FIELD_MUSTER_CAPTURE_DIR")
	if capture_dir == "":
		return ""
	await get_tree().process_frame
	var absolute_dir := ProjectSettings.globalize_path(capture_dir)
	DirAccess.make_dir_recursive_absolute(absolute_dir)
	var path := absolute_dir.path_join("%s.png" % stem)
	var image := get_viewport().get_texture().get_image()
	_expect(image != null and not image.is_empty() and image.save_png(path) == OK, "%s capture failed." % stem)
	return path


func _write_json(path: String, payload: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(payload, "  ") + "\n")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)
		push_error(message)
