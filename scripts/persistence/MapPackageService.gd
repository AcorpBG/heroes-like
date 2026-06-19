extends RefCounted

const MapDocumentScript = preload("res://scripts/persistence/MapDocument.gd")
const ScenarioDocumentScript = preload("res://scripts/persistence/ScenarioDocument.gd")

const API_ID := "aurelion_map_package_api"
const API_VERSION := "0.1.0"
const PACKAGE_SCHEMA_VERSION := 1
const MAP_SCHEMA_ID := "aurelion_map_document"
const SCENARIO_SCHEMA_ID := "aurelion_scenario_document"
const MAP_PACKAGE_EXTENSION := ".amap"
const SCENARIO_PACKAGE_EXTENSION := ".ascenario"
const BINDING_KIND := "gdscript_compatibility_shim"

const CAPABILITIES := [
	"api_metadata",
	"typed_map_document_stub",
	"typed_scenario_document_stub",
	"stable_not_implemented_errors",
	"native_random_map_config_identity",
	"headless_binding_smoke",
]

const CORE_TERRAIN_POOL := ["grass", "snow", "sand", "dirt", "rough", "lava", "underground"]
const DEFAULT_FACTIONS := ["faction_embercourt", "faction_mireclaw", "faction_sunvault", "faction_thornwake"]
const TERRAIN_ID_BY_CODE := ["grass", "snow", "sand", "dirt", "rough", "lava", "underground", "water", "rock"]

func get_api_version() -> String:
	return API_VERSION

func get_api_metadata() -> Dictionary:
	return {
		"ok": true,
		"api_id": API_ID,
		"api_version": API_VERSION,
		"binding_kind": BINDING_KIND,
		"native_extension_loaded": false,
		"map_schema_id": MAP_SCHEMA_ID,
		"scenario_schema_id": SCENARIO_SCHEMA_ID,
		"package_schema_version": PACKAGE_SCHEMA_VERSION,
		"map_package_extension": MAP_PACKAGE_EXTENSION,
		"scenario_package_extension": SCENARIO_PACKAGE_EXTENSION,
		"capabilities": get_capabilities(),
		"native_rmg_generation_authority": "blocked_until_exact_h3maped_private_state_chain",
		"native_rmg_runtime_generation_allowed": false,
		"native_rmg_legacy_capability_policy": "legacy_generation_surfaces_not_exposed",
		"status": "skeleton",
	}

func get_capabilities() -> PackedStringArray:
	return PackedStringArray(CAPABILITIES)

func get_schema_ids() -> Dictionary:
	return {
		"map_document": MAP_SCHEMA_ID,
		"scenario_document": SCENARIO_SCHEMA_ID,
		"map_validation_report": "aurelion_map_validation_report",
		"scenario_validation_report": "aurelion_scenario_validation_report",
		"native_rmg_package_session_adoption_report": "aurelion_native_random_map_package_session_adoption_report_v1",
	}

func create_map_document_stub(initial_state: Dictionary = {}) -> Variant:
	return MapDocumentScript.new(initial_state)

func create_scenario_document_stub(initial_state: Dictionary = {}) -> Variant:
	return ScenarioDocumentScript.new(initial_state)

func load_map_package(path: String, options: Dictionary = {}) -> Dictionary:
	return _not_implemented("load_map_package", "not_implemented", path, options)

func load_scenario_package(path: String, options: Dictionary = {}) -> Dictionary:
	return _not_implemented("load_scenario_package", "not_implemented", path, options)

func validate_map_document(map_document: Variant, options: Dictionary = {}) -> Dictionary:
	return _validation_not_implemented("validate_map_document", "aurelion_map_validation_report")

func validate_scenario_document(scenario_document: Variant, map_document: Variant, options: Dictionary = {}) -> Dictionary:
	return _validation_not_implemented("validate_scenario_document", "aurelion_scenario_validation_report")

func save_map_package(map_document: Variant, path: String, options: Dictionary = {}) -> Dictionary:
	return _not_implemented("save_map_package", "not_implemented", path, options)

func save_scenario_package(scenario_document: Variant, path: String, options: Dictionary = {}) -> Dictionary:
	return _not_implemented("save_scenario_package", "not_implemented", path, options)

func migrate_map_package(source_path: String, target_path: String, target_version: int, options: Dictionary = {}) -> Dictionary:
	return _not_implemented("migrate_map_package", "not_implemented", source_path, options)

func migrate_scenario_package(source_path: String, target_path: String, target_version: int, options: Dictionary = {}) -> Dictionary:
	return _not_implemented("migrate_scenario_package", "not_implemented", source_path, options)

func convert_legacy_scenario_record(scenario_record: Dictionary, terrain_layers_record: Dictionary, options: Dictionary = {}) -> Dictionary:
	return _not_implemented("convert_legacy_scenario_record", "not_implemented", "", options)

func convert_generated_payload(generated_map: Dictionary, options: Dictionary = {}) -> Dictionary:
	return _conversion_fail(
		"native_rmg_package_session_adoption_disabled",
		"Generated-map package/session adoption is disabled until the exact native H3MapEd state-chain implementation owns the generated payload."
	)

func compute_document_hash(document: Variant, options: Dictionary = {}) -> Dictionary:
	return _not_implemented("compute_document_hash", "not_implemented", "", options)

func inspect_package(path: String, options: Dictionary = {}) -> Dictionary:
	return _not_implemented("inspect_package", "not_implemented", path, options)

func normalize_random_map_config(config: Dictionary) -> Dictionary:
	var size: Dictionary = config.get("size", {}) if config.get("size", {}) is Dictionary else {}
	var profile: Dictionary = config.get("profile", {}) if config.get("profile", {}) is Dictionary else {}
	var player_constraints := _normalize_player_constraints(config.get("player_constraints", config.get("players", {})))
	var player_count := int(player_constraints.get("player_count", 2))
	var seed := String(config.get("seed", "0")).strip_edges()
	if seed == "":
		seed = "0"
	var template_id := String(config.get("template_id", "")).strip_edges()
	if template_id == "":
		template_id = String(profile.get("template_id", "")).strip_edges()
	var profile_id := String(profile.get("id", config.get("profile_id", ""))).strip_edges()
	var water_mode := String(size.get("water_mode", config.get("water_mode", "land"))).strip_edges()
	if water_mode != "islands":
		water_mode = "land"
	var terrain_ids := _normalized_terrain_pool(_normalized_string_array(profile.get("terrain_ids", []), CORE_TERRAIN_POOL))
	var faction_ids := _repeated_to_count(_normalized_string_array(profile.get("faction_ids", []), DEFAULT_FACTIONS), DEFAULT_FACTIONS, player_count)
	var town_ids := _town_ids_for_factions(profile.get("town_ids", []), faction_ids, player_count)
	return {
		"schema_id": "aurelion_native_random_map_config_normalization",
		"schema_version": 1,
		"normalizer_version": "native_rmg_exact_h3maped_state_chain_blocked_v1",
		"seed": seed,
		"normalized_seed": seed,
		"width": _foundation_dimension(config, size, "width", "requested_width", 36),
		"height": _foundation_dimension(config, size, "height", "requested_height", 36),
		"level_count": clampi(int(size.get("level_count", config.get("level_count", 1))), 1, 2),
		"template_id": template_id,
		"profile_id": profile_id,
		"size_class_id": String(size.get("size_class_id", config.get("size_class_id", ""))).strip_edges(),
		"water_mode": water_mode,
		"player_constraints": player_constraints,
		"terrain_ids": terrain_ids,
		"faction_ids": faction_ids,
		"town_ids": town_ids,
		"full_generation_status": "not_implemented",
		"normalization_scope": "config_identity_only_runtime_generation_blocked_until_exact_h3maped_state_chain",
	}

func random_map_config_identity(config: Dictionary) -> Dictionary:
	var normalized := normalize_random_map_config(config)
	var canonical := _stable_stringify(normalized)
	var signature := _hash32_hex(canonical)
	return {
		"ok": true,
		"schema_id": "aurelion_native_random_map_identity",
		"schema_version": 1,
		"algorithm": "canonical_variant_fnv1a32_config_normalization",
		"signature": signature,
		"config_hash": "fnv1a32:%s" % signature,
		"map_id": "native_rmg_%s" % signature,
		"normalized_seed": String(normalized.get("normalized_seed", "")),
		"width": int(normalized.get("width", 0)),
		"height": int(normalized.get("height", 0)),
		"level_count": int(normalized.get("level_count", 1)),
		"template_id": String(normalized.get("template_id", "")),
		"profile_id": String(normalized.get("profile_id", "")),
		"canonical_config": canonical,
		"normalized_config": normalized,
		"full_generation_status": "not_implemented",
	}

func generate_random_map(config: Dictionary, options: Dictionary = {}) -> Dictionary:
	var normalized := normalize_random_map_config(config)
	var identity := random_map_config_identity(config)
	return {
		"ok": false,
		"status": "native_rmg_exact_state_chain_runtime_blocked",
		"generation_status": "native_rmg_exact_state_chain_runtime_blocked",
		"full_generation_status": "waiting_for_exact_h3maped_executable_state_chain",
		"error_code": "native_rmg_exact_state_chain_not_ported",
		"message": "GDScript compatibility RMG generation is disabled. Runtime generation must come only from the native exact H3MapEd state-chain implementation after it owns the generated payload.",
		"runtime_generation_allowed": false,
		"native_runtime_authoritative": false,
		"public_runtime_authoritative": false,
		"full_parity_claim": false,
		"normalized_config": normalized,
		"deterministic_identity": identity,
		"options_keys": options.keys(),
	}

func _validation_not_implemented(operation: String, report_schema_id: String) -> Dictionary:
	return {
		"ok": false,
		"status": "fail",
		"error_code": "not_implemented",
		"message": "%s is not implemented in the Slice 1 package API skeleton." % operation,
		"report": {
			"schema_id": report_schema_id,
			"schema_version": 1,
			"status": "fail",
			"failure_count": 1,
			"warning_count": 0,
			"failures": [{
				"code": "not_implemented",
				"severity": "fail",
				"path": operation,
				"message": "Validation is stubbed in Slice 1.",
				"context": {},
			}],
			"warnings": [],
			"metrics": {},
		},
		"recoverable": true,
	}

func _foundation_dimension(root: Dictionary, size: Dictionary, key: String, alternate_key: String, fallback: int) -> int:
	var value := int(size.get(key, 0))
	if value <= 0:
		value = int(size.get(alternate_key, 0))
	if value <= 0:
		value = int(root.get(key, fallback))
	return clampi(value, 8, 144)

func _normalize_player_constraints(value: Variant) -> Dictionary:
	var human_count := 1
	var computer_count := 1
	var player_count := 2
	var team_mode := "free_for_all"
	if value is Dictionary:
		human_count = clampi(int(value.get("human_count", value.get("humans", human_count))), 1, 8)
		if value.has("player_count") or value.has("total_count") or value.has("total"):
			player_count = clampi(int(value.get("player_count", value.get("total_count", value.get("total", player_count)))), 1, 8)
			player_count = max(player_count, human_count)
			computer_count = max(0, player_count - human_count)
		else:
			computer_count = clampi(int(value.get("computer_count", value.get("computers", computer_count))), 0, 7)
			player_count = clampi(human_count + computer_count, 1, 8)
		team_mode = String(value.get("team_mode", team_mode)).strip_edges().to_lower()
	if team_mode == "":
		team_mode = "free_for_all"
	return {"human_count": human_count, "computer_count": computer_count, "player_count": player_count, "team_mode": team_mode}

func _normalized_string_array(value: Variant, fallback: Array) -> Array:
	var result := []
	if value is Array:
		for item in value:
			var text := String(item).strip_edges()
			if text != "" and text not in result:
				result.append(text)
	return result if not result.is_empty() else fallback.duplicate()

func _repeated_to_count(source: Array, fallback: Array, count: int) -> Array:
	var base := source if not source.is_empty() else fallback
	var result := []
	for index in range(count):
		result.append(base[index % base.size()])
	return result

func _town_for_faction(faction_id: String) -> String:
	match faction_id:
		"faction_mireclaw":
			return "town_duskfen"
		"faction_sunvault":
			return "town_prismhearth"
		"faction_thornwake":
			return "town_thornwake_graftroot_caravan"
		"faction_brasshollow":
			return "town_brasshollow_orevein_gantry"
		"faction_veilmourn":
			return "town_veilmourn_bellwake_harbor"
		_:
			return "town_riverwatch"

func _town_ids_for_factions(value: Variant, faction_ids: Array, count: int) -> Array:
	var requested := _normalized_string_array(value, []) if value is Array else []
	var result := []
	for index in range(count):
		result.append(String(requested[index % requested.size()]) if not requested.is_empty() else _town_for_faction(String(faction_ids[index % faction_ids.size()])))
	return result

func _normalized_terrain_pool(requested: Array) -> Array:
	var result := []
	for terrain_id_value in requested:
		var terrain_id := String(terrain_id_value)
		if terrain_id in TERRAIN_ID_BY_CODE and terrain_id != "water" and terrain_id not in result:
			result.append(terrain_id)
	return result if not result.is_empty() else CORE_TERRAIN_POOL.duplicate()

func _hash32_hex(text: String) -> String:
	var value := _hash32_int(text)
	var chars := []
	for _index in range(8):
		chars.push_front("0123456789abcdef"[int(value % 16)])
		value = int(value / 16)
	return "".join(chars)

func _hash32_int(text: String) -> int:
	var value := 2166136261
	for index in range(text.length()):
		value = int((value ^ text.unicode_at(index)) % 4294967296)
		value = int((value * 16777619) % 4294967296)
	return value

func _stable_stringify(value: Variant) -> String:
	if value is Dictionary:
		var parts := []
		var keys: Array = value.keys()
		keys.sort()
		for key in keys:
			parts.append("%s:%s" % [String(key).c_escape(), _stable_stringify(value[key])])
		return "{%s}" % ",".join(parts)
	if value is Array:
		var parts := []
		for item in value:
			parts.append(_stable_stringify(item))
		return "[%s]" % ",".join(parts)
	if value is PackedInt32Array:
		var parts := []
		for item in value:
			parts.append("int:%d" % int(item))
		return "[%s]" % ",".join(parts)
	if value is PackedStringArray:
		var parts := []
		for item in value:
			parts.append("string:%s" % String(item).c_escape())
		return "[%s]" % ",".join(parts)
	if value is String:
		return "string:%s" % String(value).c_escape()
	if value is bool:
		return "bool:true" if bool(value) else "bool:false"
	if value == null:
		return "null"
	if value is int:
		return "int:%d" % int(value)
	if value is float:
		return "float:%s" % String.num(float(value))
	return "variant:%s" % String(value).c_escape()

func _conversion_fail(code: String, message: String) -> Dictionary:
	return {
		"ok": false,
		"status": "fail",
		"error_code": code,
		"message": message,
		"adoption_status": "blocked",
		"report": {
			"schema_id": "aurelion_native_random_map_package_session_adoption_report_v1",
			"schema_version": 1,
			"status": "fail",
			"failure_count": 1,
			"warning_count": 0,
			"failures": [{
				"code": code,
				"severity": "fail",
				"path": "convert_generated_payload",
				"message": message,
				"context": {},
			}],
			"warnings": [],
			"metrics": {},
			"package_session_adoption_ready": false,
			"native_runtime_authoritative": false,
			"full_parity_claim": false,
		},
	}

func _tagged_record_snapshots(value: Variant, record_kind: String) -> Array:
	var result := []
	if not (value is Array):
		return result
	for item in value:
		if not (item is Dictionary):
			continue
		var record: Dictionary = item.duplicate(true)
		record["native_record_kind"] = record_kind
		if not record.has("level"):
			record["level"] = 0
		result.append(record)
	return result

func _combined_native_map_objects(generated_map: Dictionary) -> Array:
	var result := []
	result.append_array(_tagged_record_snapshots(generated_map.get("object_placements", []), "object_placement"))
	result.append_array(_tagged_record_snapshots(generated_map.get("town_records", []), "town"))
	result.append_array(_tagged_record_snapshots(generated_map.get("guard_records", []), "guard"))
	return result

func _player_start_town_records_for_start_contract(generated_map: Dictionary) -> Array:
	var player_starts: Dictionary = generated_map.get("player_starts", {}) if generated_map.get("player_starts", {}) is Dictionary else {}
	var start_count := int(player_starts.get("start_count", 0))
	var by_slot := {}
	for town in generated_map.get("town_records", []):
		if town is Dictionary and bool(town.get("is_start_town", false)):
			by_slot[int(town.get("player_slot", 0))] = town.duplicate(true)
	var result := []
	for slot in range(1, start_count + 1):
		if by_slot.has(slot):
			result.append(by_slot[slot])
	return result

func _synchronized_player_starts_for_start_contract(generated_map: Dictionary) -> Array:
	var player_starts: Dictionary = generated_map.get("player_starts", {}) if generated_map.get("player_starts", {}) is Dictionary else {}
	var start_towns := _player_start_town_records_for_start_contract(generated_map)
	var town_by_slot := {}
	for town in start_towns:
		if town is Dictionary:
			town_by_slot[int(town.get("player_slot", 0))] = town
	var result := []
	var starts: Array = player_starts.get("starts", []) if player_starts.get("starts", []) is Array else []
	for start_value in starts:
		if not (start_value is Dictionary):
			continue
		var start: Dictionary = start_value.duplicate(true)
		var slot := int(start.get("player_slot", 0))
		if town_by_slot.has(slot):
			var town: Dictionary = town_by_slot[slot]
			start["x"] = int(town.get("x", start.get("x", 0)))
			start["y"] = int(town.get("y", start.get("y", 0)))
			start["level"] = int(town.get("level", start.get("level", 0)))
			start["town_id"] = String(town.get("town_id", start.get("town_id", "")))
			start["faction_id"] = String(town.get("faction_id", start.get("faction_id", "")))
			start["owner"] = String(town.get("owner", ""))
			start["owner_slot"] = town.get("owner_slot", start.get("owner_slot", 0))
			start["player_type"] = String(town.get("player_type", start.get("player_type", "")))
			start["team_id"] = String(town.get("team_id", start.get("team_id", "")))
			start["town_placement_id"] = String(town.get("placement_id", ""))
			start["primary_town_anchor_status"] = "materialized_as_player_start_town"
			start["start_contract_source"] = "materialized_player_start_town_record"
		result.append(start)
	return result

func _native_generated_scenario_objectives(generated_map: Dictionary) -> Dictionary:
	var towns: Array = generated_map.get("town_records", []) if generated_map.get("town_records", []) is Array else []
	var starting_town_id := ""
	var rival_town_id := ""
	for town_value in towns:
		if not (town_value is Dictionary):
			continue
		var town: Dictionary = town_value
		var placement_id := String(town.get("placement_id", ""))
		if placement_id == "":
			continue
		var owner := String(town.get("owner", ""))
		var player_slot := int(town.get("player_slot", 0))
		if starting_town_id == "" and (owner == "player" or player_slot == 1):
			starting_town_id = placement_id
			continue
		if rival_town_id == "" and owner != "player":
			rival_town_id = placement_id
	if rival_town_id == "":
		for town_value in towns:
			if not (town_value is Dictionary):
				continue
			var placement_id := String(town_value.get("placement_id", ""))
			if placement_id != "" and placement_id != starting_town_id:
				rival_town_id = placement_id
				break

	var victory_objectives := []
	var defeat_objectives := []
	if rival_town_id != "":
		victory_objectives.append({
			"id": "generated_capture_rival_town",
			"type": "town_owned_by_player",
			"placement_id": rival_town_id,
			"label": "Claim a generated rival town",
			"generated_support": "ScenarioRules.town_owned_by_player",
		})
	else:
		victory_objectives.append({
			"id": "generated_hold_until_day_14",
			"type": "day_at_least",
			"day": 14,
			"label": "Hold the generated frontier until Day 14",
			"generated_support": "ScenarioRules.day_at_least",
		})
	if starting_town_id != "":
		defeat_objectives.append({
			"id": "generated_primary_town_lost",
			"type": "town_not_owned_by_player",
			"placement_id": starting_town_id,
			"label": "Do not lose the generated starting town",
			"generated_support": "ScenarioRules.town_not_owned_by_player",
		})
	return {
		"victory_text": "Generated objective completed.",
		"defeat_text": "Generated objective failed.",
		"victory": victory_objectives,
		"defeat": defeat_objectives,
	}

func _not_implemented(operation: String, error_code: String, path: String, options: Dictionary) -> Dictionary:
	return {
		"ok": false,
		"status": "fail",
		"error_code": error_code,
		"message": "%s is not implemented in the Slice 1 package API skeleton." % operation,
		"operation": operation,
		"path": path,
		"report": {
			"schema_id": "aurelion_package_operation_report",
			"schema_version": 1,
			"status": "fail",
			"failures": [{
				"code": error_code,
				"severity": "fail",
				"path": operation,
				"message": "Package conversion/read/write is intentionally unavailable in Slice 1.",
				"context": {"options_keys": options.keys()},
			}],
			"warnings": [],
		},
		"recoverable": true,
	}
