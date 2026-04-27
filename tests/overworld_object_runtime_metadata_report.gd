extends Node

var _failed := false

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var cases := [
		{
			"label": "safe pickup metadata",
			"site_id": "site_wood_wagon",
			"expected": [
				"Class: Pickup",
				"Cadence: one-time",
				"pickup/cache",
				"Roles: Build Resource, Small Reward, Route Pacing",
			],
		},
		{
			"label": "safe persistent economy metadata",
			"site_id": "site_brightwood_sawmill",
			"expected": [
				"Class: Persistent Economy Site",
				"Cadence: persistent control",
				"capture/ownership",
				"income",
				"Roles: Resource Front, Counter Capture Target, Town Support",
			],
		},
		{
			"label": "safe cooldown service metadata",
			"site_id": "site_wayfarer_infirmary",
			"expected": [
				"Class: Interactable Site",
				"Cadence: cooldown days",
				"repeat service",
				"Roles: Recovery, Town Support",
			],
		},
	]
	var surfaces := {}
	for runtime_case in cases:
		var site_id := String(runtime_case.get("site_id", ""))
		var surface := _interaction_surface(site_id)
		surfaces[site_id] = surface
		_assert_contains_all(String(runtime_case.get("label", site_id)), surface, runtime_case.get("expected", []))
		if _failed:
			return

	var wood_object := ContentService.get_map_object("object_wood_wagon")
	if wood_object.has("body_tiles") or wood_object.has("approach"):
		_fail("Safe runtime metadata report must not require body_tiles or approach metadata for object_wood_wagon")
		return

	var payload := {
		"ok": true,
		"adopted_runtime_fields": ["primary_class", "secondary_tags", "interaction.cadence"],
		"runtime_surface": "OverworldRules.describe_resource_site_interaction_surface",
		"deferred_fields": ["body_tiles", "approach", "passability_class", "route_effect", "renderer_hint_id", "ai_hints", "save_state"],
		"surfaces": surfaces,
	}
	print("OVERWORLD_OBJECT_RUNTIME_METADATA_REPORT %s" % JSON.stringify(payload))
	get_tree().quit(0)

func _interaction_surface(site_id: String) -> String:
	var site := ContentService.get_resource_site(site_id)
	if site.is_empty():
		_fail("Missing resource site %s" % site_id)
		return ""
	return OverworldRules.describe_resource_site_interaction_surface({"site_id": site_id}, site)

func _assert_contains_all(label: String, text: String, expected_parts: Array) -> void:
	for expected in expected_parts:
		if not text.contains(String(expected)):
			_fail("%s missing '%s' in '%s'" % [label, expected, text])
			return

func _fail(message: String) -> void:
	_failed = true
	push_error("Overworld object runtime metadata report: %s" % message)
	get_tree().quit(1)
