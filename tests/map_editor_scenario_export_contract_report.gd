extends Node

const SCENARIO_ID := "ninefold-confluence"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var shell = load("res://scenes/editor/MapEditorShell.tscn").instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame

	var clean_contract: Dictionary = shell.call("validation_authored_scenario_export_contract")
	if not _assert_contract_boundary(clean_contract, false):
		return
	if bool(clean_contract.get("changed", true)):
		_fail("Clean authored scenario export draft should not report changes: %s" % [clean_contract.get("changed_domains", [])])
		return

	if not bool(shell.call("_set_tile_terrain", Vector2i(2, 2), "forest")):
		_fail("Could not seed terrain edit before export contract check.")
		return
	shell.set("_dirty", true)
	if not bool(shell.call("_set_hero_start", Vector2i(3, 3))):
		_fail("Could not seed hero start edit before export contract check.")
		return
	if not bool(shell.call("_select_object_family_by_id", "resource")):
		_fail("Could not select resource family before export contract check.")
		return
	if not bool(shell.call("_select_object_content_by_id", "site_wood_wagon")):
		_fail("Could not select resource content before export contract check.")
		return
	if not bool(shell.call("_place_object", Vector2i(5, 4))):
		_fail("Could not seed resource object before export contract check.")
		return

	var edited_contract: Dictionary = shell.call("validation_authored_scenario_export_contract")
	if not _assert_contract_boundary(edited_contract, true):
		return
	for domain in ["map", "start", "resource_nodes"]:
		if domain not in edited_contract.get("changed_domains", []):
			_fail("Edited authored scenario export draft missed changed domain %s: %s" % [domain, edited_contract.get("changed_domains", [])])
			return
	var draft: Dictionary = edited_contract.get("draft", {})
	var scenario_record: Dictionary = draft.get("scenario_record", {})
	var terrain_layers_record: Dictionary = draft.get("terrain_layers_record", {})
	var map_rows: Array = scenario_record.get("map", [])
	if map_rows.size() <= 2 or not (map_rows[2] is Array) or String(map_rows[2][2]) != "forest":
		_fail("Edited authored scenario export draft did not carry terrain edit at 2,2.")
		return
	var start: Dictionary = scenario_record.get("start", {})
	if int(start.get("x", -1)) != 3 or int(start.get("y", -1)) != 3:
		_fail("Edited authored scenario export draft did not carry hero start edit: %s" % [start])
		return
	if String(terrain_layers_record.get("id", "")) != SCENARIO_ID:
		_fail("Terrain-layer draft id did not match scenario: %s" % [terrain_layers_record.get("id", "")])
		return
	if String(edited_contract.get("draft_signature", "")).strip_edges() == "":
		_fail("Edited authored scenario export draft did not expose a deterministic signature.")
		return

	print("MAP_EDITOR_SCENARIO_EXPORT_CONTRACT_REPORT %s" % JSON.stringify({
		"ok": true,
		"scenario_id": SCENARIO_ID,
		"clean_changed_domains": clean_contract.get("changed_domains", []),
		"edited_changed_domains": edited_contract.get("changed_domains", []),
		"writeback_state": String(edited_contract.get("writeback_state", "")),
		"target_paths": edited_contract.get("target_paths", []),
		"draft_signature": String(edited_contract.get("draft_signature", "")),
	}, "", true))
	get_tree().quit(0)

func _assert_contract_boundary(contract: Dictionary, expected_dirty: bool) -> bool:
	if String(contract.get("contract_id", "")) != "editor_authored_scenario_export_contract_v1":
		_fail("Export contract id mismatch: %s" % [String(contract.get("contract_id", ""))])
		return false
	if not bool(contract.get("ok", false)) or not bool(contract.get("ready", false)):
		_fail("Export contract was not ready: blockers=%s" % [contract.get("blockers", [])])
		return false
	if bool(contract.get("dirty", not expected_dirty)) != expected_dirty:
		_fail("Export contract dirty state mismatch: expected=%s actual=%s" % [expected_dirty, contract.get("dirty", null)])
		return false
	if bool(contract.get("writeback_allowed", true)) or bool(contract.get("writeback_supported", true)):
		_fail("Export contract must not enable file writeback in this slice.")
		return false
	if String(contract.get("writeback_state", "")) != "validated_draft_only":
		_fail("Export contract did not keep writeback in validated_draft_only mode: %s" % [String(contract.get("writeback_state", ""))])
		return false
	if String(contract.get("write_context", "")).find("no authored file or campaign progress is written") < 0:
		_fail("Export contract lost the no-write boundary: %s" % [String(contract.get("write_context", ""))])
		return false
	for target_path in ["res://content/scenarios.json", "res://content/terrain_layers.json"]:
		if target_path not in contract.get("target_paths", []):
			_fail("Export contract missed target path %s." % [target_path])
			return false
	var draft: Dictionary = contract.get("draft", {})
	if draft.get("scenario_record", {}).is_empty() or draft.get("terrain_layers_record", {}).is_empty():
		_fail("Export contract did not include scenario and terrain-layer draft records.")
		return false
	return true

func _fail(message: String) -> void:
	push_error("MAP_EDITOR_SCENARIO_EXPORT_CONTRACT_REPORT failed: %s" % [message])
	get_tree().quit(1)
