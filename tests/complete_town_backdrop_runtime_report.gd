extends Node

const TownStageViewScript = preload("res://scenes/town/TownStageView.gd")
const VIEWPORT_SIZES := [Vector2i(1280, 720), Vector2i(1920, 1080)]
const CAPTURE_DIR := "res://.artifacts/complete_town_backdrops/captures"
const TOWN_CASES := {
	"town_riverwatch": {"scenario_id": "river-pass", "path": "res://art/towns/runtime/backdrops/complete_identities/town_riverwatch.png"},
	"town_duskfen": {"scenario_id": "river-pass", "path": "res://art/towns/runtime/backdrops/complete_identities/town_duskfen.png"},
	"town_blackfen_gate": {"scenario_id": "causeway-stand", "path": "res://art/towns/runtime/backdrops/complete_identities/town_blackfen_gate.png"},
	"town_highwater_keep": {"scenario_id": "stonewake-watch", "path": "res://art/towns/runtime/backdrops/complete_identities/town_highwater_keep.png"},
	"town_murkward_ford": {"scenario_id": "stonewake-watch", "path": "res://art/towns/runtime/backdrops/complete_identities/town_murkward_ford.png"},
	"town_reedbarrow_ferry": {"scenario_id": "reedbarrow-ferry", "path": "res://art/towns/runtime/backdrops/complete_identities/town_reedbarrow_ferry.png"},
	"town_nightglass_redoubt": {"scenario_id": "nightglass-redoubt", "path": "res://art/towns/runtime/backdrops/complete_identities/town_nightglass_redoubt.png"},
	"town_prismhearth": {"scenario_id": "prismhearth-watch", "path": "res://art/towns/runtime/backdrops/complete_identities/town_prismhearth.png"},
	"town_halo_spire": {"scenario_id": "prismhearth-watch", "path": "res://art/towns/runtime/backdrops/complete_identities/town_halo_spire.png"},
	"town_thornwake_graftroot_caravan": {"scenario_id": "mireford-skirmish", "path": "res://art/towns/runtime/backdrops/complete_identities/town_thornwake_graftroot_caravan.png"},
	"town_brasshollow_orevein_gantry": {"scenario_id": "orevein-contract", "path": "res://art/towns/runtime/backdrops/complete_identities/town_brasshollow_orevein_gantry.png"},
	"town_veilmourn_bellwake_harbor": {"scenario_id": "bellwake-wreck-claim", "path": "res://art/towns/runtime/backdrops/complete_identities/town_veilmourn_bellwake_harbor.png"},
	"town_thornwake_rootgate_nursery": {"scenario_id": "rootgate-toll", "path": "res://art/towns/runtime/backdrops/complete_identities/town_thornwake_rootgate_nursery.png"},
	"town_brasshollow_clauseworks_depot": {"scenario_id": "rootgate-toll", "path": "res://art/towns/runtime/backdrops/complete_identities/town_brasshollow_clauseworks_depot.png"},
	"town_veilmourn_fogchart_mooring": {"scenario_id": "fogchart-mooring", "path": "res://art/towns/runtime/backdrops/complete_identities/town_veilmourn_fogchart_mooring.png"},
	"town_cinderlock_bastion": {"scenario_id": "third-hearths-confluence", "path": "res://art/towns/runtime/backdrops/third_hearths/town_cinderlock_bastion.png"},
	"town_dawnmirror_observatory": {"scenario_id": "third-hearths-confluence", "path": "res://art/towns/runtime/backdrops/third_hearths/town_dawnmirror_observatory.png"},
	"town_briarwheel_enclave": {"scenario_id": "third-hearths-confluence", "path": "res://art/towns/runtime/backdrops/third_hearths/town_briarwheel_enclave.png"},
	"town_cindercoil_foundry": {"scenario_id": "third-hearths-confluence", "path": "res://art/towns/runtime/backdrops/third_hearths/town_cindercoil_foundry.png"},
	"town_gloamwake_anchorage": {"scenario_id": "third-hearths-confluence", "path": "res://art/towns/runtime/backdrops/third_hearths/town_gloamwake_anchorage.png"},
	"town_rainwrit_bastion": {"scenario_id": "ninefold-confluence", "path": "res://art/towns/runtime/backdrops/horizon_citadels/town_rainwrit_bastion.png"},
	"town_hollowreed_sanctuary": {"scenario_id": "ninefold-confluence", "path": "res://art/towns/runtime/backdrops/horizon_citadels/town_hollowreed_sanctuary.png"},
	"town_meridian_choirhold": {"scenario_id": "ninefold-confluence", "path": "res://art/towns/runtime/backdrops/horizon_citadels/town_meridian_choirhold.png"},
	"town_crownroot_refuge": {"scenario_id": "ninefold-confluence", "path": "res://art/towns/runtime/backdrops/horizon_citadels/town_crownroot_refuge.png"},
	"town_blackbell_foundry": {"scenario_id": "ninefold-confluence", "path": "res://art/towns/runtime/backdrops/horizon_citadels/town_blackbell_foundry.png"},
	"town_pale_sounding_harbor": {"scenario_id": "ninefold-confluence", "path": "res://art/towns/runtime/backdrops/horizon_citadels/town_pale_sounding_harbor.png"},
}
const FACTION_FALLBACK_CASES := {
	"town_riverwatch": "faction_embercourt",
	"town_duskfen": "faction_mireclaw",
	"town_prismhearth": "faction_sunvault",
	"town_thornwake_graftroot_caravan": "faction_thornwake",
	"town_brasshollow_orevein_gantry": "faction_brasshollow",
	"town_veilmourn_bellwake_harbor": "faction_veilmourn",
}
const FACTION_BACKDROPS := {
	"faction_embercourt": "res://art/towns/runtime/backdrops/town_embercourt.png",
	"faction_mireclaw": "res://art/towns/runtime/backdrops/town_mireclaw.png",
	"faction_sunvault": "res://art/towns/runtime/backdrops/town_sunvault.png",
	"faction_thornwake": "res://art/towns/runtime/backdrops/town_thornwake.png",
	"faction_brasshollow": "res://art/towns/runtime/backdrops/town_brasshollow.png",
	"faction_veilmourn": "res://art/towns/runtime/backdrops/town_veilmourn.png",
}

var _original_content_scale_size := Vector2i.ZERO

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var original_size := get_window().size
	_original_content_scale_size = get_window().content_scale_size
	var catalog := _catalog_contract()
	if not bool(catalog.get("ok", false)):
		_fail("Exact backdrop catalog failed", catalog, original_size)
		return
	var fallback := await _fallback_contract()
	if not bool(fallback.get("ok", false)):
		_fail("Faction fallback contract failed", fallback, original_size)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CAPTURE_DIR))
	var rows := []
	for viewport_size in VIEWPORT_SIZES:
		for town_id_value in TOWN_CASES.keys():
			var town_id := String(town_id_value)
			var row: Dictionary = await _run_town_case(viewport_size, town_id)
			rows.append(row)
			if not bool(row.get("ok", false)):
				_fail("Live exact-town backdrop failed", row, original_size)
				return
	get_window().size = original_size
	get_window().content_scale_size = _original_content_scale_size
	SessionState.reset_session()
	print("COMPLETE_TOWN_BACKDROP_RUNTIME_REPORT %s" % JSON.stringify({
		"ok": true,
		"catalog": catalog,
		"fallback": fallback,
		"rows": rows,
		"save_version": SessionStateStore.SAVE_VERSION,
	}))
	get_tree().quit(0)

func _catalog_contract() -> Dictionary:
	var hashes := []
	var rows := []
	for town_id_value in TOWN_CASES.keys():
		var town_id := String(town_id_value)
		var expected_path := String(TOWN_CASES[town_id].get("path", ""))
		var town := ContentService.get_town(town_id)
		var texture: Texture2D = load(expected_path) as Texture2D if ResourceLoader.exists(expected_path, "Texture2D") else null
		var bytes := FileAccess.get_file_as_bytes(ProjectSettings.globalize_path(expected_path))
		var digest: String = str(hash(bytes))
		var exact: bool = (
			not town.is_empty()
			and String(town.get("scenic_backdrop_path", "")) == expected_path
			and texture != null
			and texture.get_size() == Vector2(1600, 900)
			and bytes.size() > 100000
			and digest != ""
		)
		rows.append({"town_id": town_id, "path": expected_path, "bytes": bytes.size(), "sha256": digest, "exact": exact})
		hashes.append(digest)
	return {
		"ok": rows.size() == 26 and _unique(hashes).size() == 26 and rows.all(func(row): return bool(row.get("exact", false))),
		"town_count": rows.size(),
		"unique_art_count": _unique(hashes).size(),
		"rows": rows,
	}

func _fallback_contract() -> Dictionary:
	var fixture = TownStageViewScript.new()
	add_child(fixture)
	fixture.size = Vector2(1180, 640)
	var rows := []
	for town_id_value in FACTION_FALLBACK_CASES.keys():
		var town_id := String(town_id_value)
		var faction_id := String(FACTION_FALLBACK_CASES[town_id])
		var town := ContentService.get_town(town_id).duplicate(true)
		town.erase("scenic_backdrop_path")
		fixture.set_precomputed_town_state(null, {
			"town": {"town_id": town_id, "built_buildings": [], "garrison": [], "available_recruits": {}},
			"town_template": town,
			"faction": ContentService.get_faction(faction_id),
		})
		await get_tree().process_frame
		var summary: Dictionary = fixture.validation_scenic_backdrop_summary()
		var exact: bool = (
			String(summary.get("town_id", "")) == town_id
			and String(summary.get("faction_id", "")) == faction_id
			and String(summary.get("selection_scope", "")) == "faction_fallback"
			and String(summary.get("mapped_path", "")) == String(FACTION_BACKDROPS[faction_id])
			and bool(summary.get("texture_loaded", false))
			and summary.get("texture_size", Vector2.ZERO) == Vector2(1600, 900)
			and bool(summary.get("source_within_texture", false))
			and bool(summary.get("destination_contained", false))
		)
		rows.append({"town_id": town_id, "faction_id": faction_id, "exact": exact, "summary": summary})
	fixture.queue_free()
	await get_tree().process_frame
	return {"ok": rows.size() == 6 and rows.all(func(row): return bool(row.get("exact", false))), "rows": rows}

func _run_town_case(viewport_size: Vector2i, town_id: String) -> Dictionary:
	get_window().content_scale_size = viewport_size
	get_window().size = viewport_size
	await get_tree().process_frame
	var scenario_id := String(TOWN_CASES[town_id].get("scenario_id", ""))
	var session = ScenarioFactory.create_session(scenario_id, "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	var placement_id := _make_town_player_owned(session, town_id)
	if placement_id == "":
		return {"ok": false, "failure": "town_placement_missing", "town_id": town_id, "viewport": [viewport_size.x, viewport_size.y]}
	var visit: Dictionary = OverworldRules.set_active_town_visit(session, placement_id)
	if not bool(visit.get("ok", false)):
		return {"ok": false, "failure": "active_town_visit_failed", "town_id": town_id, "visit": visit}
	var authority_before: Dictionary = session.to_dict()
	SessionState.set_active_session(session)
	var shell = load("res://scenes/town/TownShell.tscn").instantiate()
	add_child(shell)
	for unused in range(5):
		await get_tree().process_frame
	shell.call("_apply_responsive_layout")
	await get_tree().process_frame
	var stage: Node = shell.get_node_or_null("%TownStage")
	var summary: Dictionary = stage.validation_scenic_backdrop_summary() if stage != null else {}
	var shell_surface := _shell_surface_contract(shell)
	var expected_path := String(TOWN_CASES[town_id].get("path", ""))
	var mapping_exact: bool = (
		stage != null
		and String(summary.get("town_id", "")) == town_id
		and String(summary.get("selection_scope", "")) == "exact_town"
		and String(summary.get("mapped_path", "")) == expected_path
		and bool(summary.get("texture_loaded", false))
		and summary.get("texture_size", Vector2.ZERO) == Vector2(1600, 900)
		and bool(summary.get("source_within_texture", false))
		and bool(summary.get("destination_contained", false))
		and not bool(summary.get("procedural_fallback", true))
	)
	var capture_path := "%s/%s_%dx%d.png" % [CAPTURE_DIR, town_id, viewport_size.x, viewport_size.y]
	var viewport_texture: ViewportTexture = get_viewport().get_texture()
	var capture_ok := viewport_texture != null and viewport_texture.get_image().save_png(ProjectSettings.globalize_path(capture_path)) == OK
	var authority_exact: bool = session.to_dict() == authority_before
	var row := {
		"ok": mapping_exact and bool(shell_surface.get("ok", false)) and capture_ok and authority_exact,
		"town_id": town_id,
		"scenario_id": scenario_id,
		"viewport": [viewport_size.x, viewport_size.y],
		"mapping": summary,
		"shell_surface": shell_surface,
		"capture_ok": capture_ok,
		"capture_path": capture_path,
		"authority_exact": authority_exact,
	}
	shell.queue_free()
	await get_tree().process_frame
	SessionState.reset_session()
	return row

func _make_town_player_owned(session, town_id: String) -> String:
	var towns: Array = session.overworld.get("towns", []) if session.overworld.get("towns", []) is Array else []
	for index in range(towns.size()):
		if towns[index] is Dictionary and String(towns[index].get("town_id", "")) == town_id:
			var town: Dictionary = towns[index]
			town["owner"] = "player"
			towns[index] = town
			session.overworld["towns"] = towns
			return String(town.get("placement_id", ""))
	return ""

func _shell_surface_contract(shell: Node) -> Dictionary:
	var controls := {
		"stage": shell.get_node_or_null("%TownStage"),
		"management_tabs": shell.get_node_or_null("%ManagementTabs"),
		"build_catalog": shell.get_node_or_null("%OpenBuildCatalog"),
		"muster_catalog": shell.get_node_or_null("%OpenMusterCatalog"),
		"leave": shell.get_node_or_null("%Leave"),
	}
	var exact := true
	var required_visible := ["stage", "management_tabs", "leave"]
	var labels := []
	for label_value in controls.keys():
		var label := String(label_value)
		var control: Control = controls[label] as Control
		exact = exact and control != null and control.size.x > 0.0 and control.size.y > 0.0
		if label in required_visible:
			exact = exact and control.is_visible_in_tree()
		labels.append({"id": label, "visible": control != null and control.is_visible_in_tree(), "size": control.size if control != null else Vector2.ZERO})
	return {"ok": exact, "controls": labels}

func _unique(values: Array) -> Array:
	var result := []
	for value in values:
		if value not in result:
			result.append(value)
	return result

func _fail(message: String, details: Dictionary, original_size: Vector2i) -> void:
	push_error("%s: %s" % [message, details])
	get_window().size = original_size
	get_window().content_scale_size = _original_content_scale_size
	SessionState.reset_session()
	get_tree().quit(1)
