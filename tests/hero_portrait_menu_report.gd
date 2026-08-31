extends Node

const REPORT_ID := "HERO_PORTRAIT_MENU_REPORT"
const CAMPAIGN_ID := "campaign_reedfall"
const SCENARIO_ID := "river-pass"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	ContentService.clear_cache()
	var hero_ids: Array[String] = ContentService.get_content_ids(ContentService.HEROES_PATH)
	var loaded_paths := {}
	for hero_id in hero_ids:
		var hero := ContentService.get_hero(hero_id)
		var art := ContentService.get_hero_art(hero_id)
		var path := String(art.get("portrait", ""))
		var texture: Variant = ResourceLoader.load(path, "Texture2D") if path != "" else null
		if hero.is_empty() or String(art.get("hero_id", "")) != hero_id or not (texture is Texture2D):
			_fail("Authored hero portrait did not load for %s: %s" % [hero_id, JSON.stringify(art)])
			return
		if texture.get_width() != 384 or texture.get_height() != 512 or loaded_paths.has(path):
			_fail("Authored hero portrait size/path uniqueness failed for %s." % hero_id)
			return
		loaded_paths[path] = true
	if hero_ids.size() != 66 or loaded_paths.size() != 66:
		_fail("Hero portrait coverage must be exactly 66 unique authored heroes.")
		return

	var shell = load("res://scenes/menus/MainMenu.tscn").instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame
	shell.call("validation_open_campaign_stage")
	if not bool(shell.call("validation_select_campaign", CAMPAIGN_ID)) or not bool(shell.call("validation_select_campaign_chapter", SCENARIO_ID)):
		_fail("Campaign portrait fixture could not select River Pass.")
		return
	await get_tree().process_frame
	var campaign: Dictionary = shell.call("validation_snapshot")
	if not bool(campaign.get("campaign_commander_portrait_visible", false)) \
			or String(campaign.get("campaign_commander_portrait_path", "")) != "res://art/heroes/portraits/hero_lyra.png" \
			or String(campaign.get("campaign_commander_portrait_tooltip", "")) != "Lyra Emberwell portrait":
		_fail("Campaign portrait did not follow the selected commander: %s" % JSON.stringify(campaign))
		return

	shell.call("validation_open_skirmish_stage")
	if not bool(shell.call("validation_select_skirmish", SCENARIO_ID)):
		_fail("Skirmish portrait fixture could not select River Pass.")
		return
	await get_tree().process_frame
	var skirmish: Dictionary = shell.call("validation_snapshot")
	if not bool(skirmish.get("skirmish_commander_portrait_visible", false)) \
			or String(skirmish.get("skirmish_commander_portrait_path", "")) != "res://art/heroes/portraits/hero_lyra.png" \
			or String(skirmish.get("skirmish_commander_portrait_tooltip", "")) != "Lyra Emberwell portrait":
		_fail("Skirmish portrait did not follow the selected commander: %s" % JSON.stringify(skirmish))
		return

	print(REPORT_ID, " ", JSON.stringify({
		"ok": true,
		"hero_count": hero_ids.size(),
		"unique_portrait_count": loaded_paths.size(),
		"campaign_path": campaign.get("campaign_commander_portrait_path", ""),
		"skirmish_path": skirmish.get("skirmish_commander_portrait_path", ""),
	}))
	get_tree().quit(0)

func _fail(message: String) -> void:
	push_error(message)
	print(REPORT_ID, " ", JSON.stringify({"ok": false, "error": message}))
	get_tree().quit(1)
