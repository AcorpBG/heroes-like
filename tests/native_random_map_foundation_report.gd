extends Node

const REPORT_ID := "NATIVE_RANDOM_MAP_FOUNDATION_REPORT"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	if not ClassDB.class_exists("MapPackageService"):
		_fail("MapPackageService native class is not available.")
		return

	var service: Variant = ClassDB.instantiate("MapPackageService")
	var metadata: Dictionary = service.get_api_metadata()
	if String(metadata.get("binding_kind", "")) != "native_gdextension" or not bool(metadata.get("native_extension_loaded", false)):
		_fail("Native GDExtension metadata did not prove native load: %s" % JSON.stringify(metadata))
		return

	var capabilities: PackedStringArray = service.get_capabilities()
	for required in ["native_random_map_config_identity", "native_random_map_foundation_stub"]:
		if not capabilities.has(required):
			_fail("Missing native RMG capability %s in %s." % [required, JSON.stringify(Array(capabilities))])
			return

	var config := {
		"seed": "native-rmg-foundation-10184",
		"size": {
			"width": 36,
			"height": 36,
			"level_count": 1,
			"size_class_id": "homm3_small",
			"water_mode": "land",
		},
		"template_id": "border_gate_compact_v1",
		"profile": {
			"id": "border_gate_compact_profile_v1",
			"template_id": "border_gate_compact_v1",
		},
	}
	var same_config := config.duplicate(true)
	var changed_seed_config := config.duplicate(true)
	changed_seed_config["seed"] = "native-rmg-foundation-10184-changed"

	var first_identity: Dictionary = service.random_map_config_identity(config)
	var second_identity: Dictionary = service.random_map_config_identity(same_config)
	var changed_identity: Dictionary = service.random_map_config_identity(changed_seed_config)
	if String(first_identity.get("signature", "")) == "":
		_fail("Native RMG identity did not produce a signature.")
		return
	if String(first_identity.get("signature", "")) != String(second_identity.get("signature", "")):
		_fail("Same native RMG config did not produce the same identity.")
		return
	if String(first_identity.get("signature", "")) == String(changed_identity.get("signature", "")):
		_fail("Changed native RMG seed did not change identity.")
		return

	var generated: Dictionary = service.generate_random_map(config)
	if not bool(generated.get("ok", false)):
		_fail("Native RMG foundation generate_random_map returned ok=false: %s" % JSON.stringify(generated))
		return
	if String(generated.get("status", "")) != "partial_foundation":
		_fail("Native RMG foundation did not report partial_foundation status: %s" % JSON.stringify(generated))
		return
	if String(generated.get("full_generation_status", "")) != "not_implemented":
		_fail("Native RMG foundation did not explicitly preserve full_generation_status=not_implemented.")
		return

	var map_doc: Variant = generated.get("map_document")
	if map_doc == null:
		_fail("Native RMG foundation did not return a MapDocument stub.")
		return
	if map_doc.get_source_kind() != "generated" or map_doc.get_width() != 36 or map_doc.get_height() != 36:
		_fail("Generated MapDocument stub did not preserve generated source and dimensions.")
		return
	var doc_metadata: Dictionary = map_doc.get_metadata()
	if not bool(doc_metadata.get("generated", false)):
		_fail("Generated MapDocument metadata did not mark generated=true.")
		return
	if String(doc_metadata.get("full_generation_status", "")) != "not_implemented":
		_fail("Generated MapDocument metadata falsely implied full generation.")
		return
	if not map_doc.get_terrain_layer_ids().is_empty():
		_fail("Foundation MapDocument stub should not contain terrain layers yet.")
		return

	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"binding_kind": metadata.get("binding_kind", ""),
		"native_extension_loaded": metadata.get("native_extension_loaded", false),
		"signature": first_identity.get("signature", ""),
		"changed_seed_signature": changed_identity.get("signature", ""),
		"status": generated.get("status", ""),
		"full_generation_status": generated.get("full_generation_status", ""),
		"map_id": map_doc.get_map_id(),
		"width": map_doc.get_width(),
		"height": map_doc.get_height(),
		"source_kind": map_doc.get_source_kind(),
	})])
	get_tree().quit(0)

func _fail(message: String) -> void:
	push_error("%s failed: %s" % [REPORT_ID, message])
	get_tree().quit(1)
