extends "res://tests/native_random_map_broad_template_generation_report.gd"

func _template_case_limit() -> int:
	return 0

func _explicit_template_ids() -> Array:
	var catalog: Dictionary = ContentService.load_json(RandomMapGeneratorRulesScript.TEMPLATE_CATALOG_PATH)
	var ids := []
	for template in catalog.get("templates", []):
		if not (template is Dictionary):
			continue
		var template_id := String(template.get("id", ""))
		if template_id.begins_with("translated_rmg_template_"):
			ids.append(template_id)
	return ids
