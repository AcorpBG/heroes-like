extends Node

## Focused live report for the Town building popout. For every faction town
## template it clicks built buildings through the real TownShell hotspot route
## and checks each kind's own body: dwelling recruitment with an amount and its
## upgrade, magic guild spell shelves by level, tavern heroes and hiring, hero
## training and artifact services, market hand-off and plain upgrade lines.

const TownShellScene = preload("res://scenes/town/TownShell.tscn")
const Board = preload("res://scripts/core/TownConstructionBoard.gd")
const OverworldLevelRulesScript = preload("res://scripts/core/OverworldLevelRules.gd")
const CAPTURE_DIR := "res://.artifacts/town_building_panel"
const TAVERN_ID := "building_wayfarers_hall"
const RICH := {"gold": 60000, "wood": 300, "ore": 300, "aetherglass": 60, "embergrain": 60, "peatwax": 60, "verdant_grafts": 60, "brass_scrip": 60, "memory_salt": 60}

var _errors := []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CAPTURE_DIR))
	var original_size := get_window().size
	var only := OS.get_environment("PANEL_TOWN")
	var rows := []
	var templates := []
	for town_value in ContentService.load_json("res://content/towns.json").get("items", []):
		if only == "" or String(town_value.get("id", "")) == only:
			templates.append(String(town_value.get("id", "")))
	for index in range(templates.size()):
		var viewport_size := Vector2i(1920, 1080) if index % 2 == 0 else Vector2i(1280, 720)
		var row: Dictionary = await _run_town(String(templates[index]), viewport_size)
		rows.append(row)
		if not bool(row.get("ok", false)):
			_errors.append("%s failed: %s" % [templates[index], JSON.stringify(row.get("failures", []))])
	get_window().size = original_size
	var report := {
		"ok": _errors.is_empty(),
		"schema": "town_building_panel_report_v1",
		"town_count": rows.size(),
		"rows": rows,
		"errors": _errors,
	}
	if _errors.is_empty():
		print("TOWN_BUILDING_PANEL_REPORT %s" % JSON.stringify(report))
	else:
		push_error("TOWN_BUILDING_PANEL_REPORT failed: %s" % JSON.stringify(report))
	get_tree().quit(0 if _errors.is_empty() else 1)

func _run_town(template_id: String, viewport_size: Vector2i) -> Dictionary:
	var failures := []
	get_window().size = viewport_size
	await _frames(2)
	var template := ContentService.get_town(template_id)
	var ids := _pick_buildings(Board.town_building_ids(template))
	for key in ["dwelling", "dwelling_upgrade", "guild", "market", "training", "artifacts", "fort"]:
		if String(ids.get(key, "")) == "":
			return {"ok": false, "template_id": template_id, "failures": ["no %s building" % key]}
	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state(session)
	var town := _first_player_town(session)
	if town.is_empty():
		return {"ok": false, "template_id": template_id, "failures": ["player_town_missing"]}
	var base_unit := String(ContentService.get_building(ids.dwelling).get("unlock_unit_id", ""))
	town["town_id"] = template_id
	town["built_buildings"] = ["building_town_hall", TAVERN_ID, ids.dwelling, ids.guild, ids.market, ids.training, ids.artifacts, ids.fort]
	town["available_recruits"] = {base_unit: 10}
	town["last_build_day"] = 0
	session.day = 2
	session.overworld["resources"] = RICH.duplicate(true)
	_station_active_hero(session, town)
	var visit: Dictionary = OverworldRules.set_active_town_visit(session, String(town.get("placement_id", "")))
	if not bool(visit.get("ok", false)):
		return {"ok": false, "template_id": template_id, "failures": ["town_visit"], "visit": visit}
	session = SessionState.set_active_session(session)
	var shell = TownShellScene.instantiate()
	add_child(shell)
	await _frames(3)

	# Looking is free: opening every popout leaves the session untouched.
	var untouched: Dictionary = SessionState.ensure_active_session().to_dict().duplicate(true)
	for building_id in [ids.dwelling, ids.guild, TAVERN_ID, ids.market, ids.training, ids.artifacts, ids.fort]:
		await _open(shell, String(building_id))
	shell.call("_close_town_catalog", false)
	await _frames(2)
	_check(failures, SessionState.ensure_active_session().to_dict() == untouched, "opening popouts changed the session")

	# Dwelling: recruit a chosen amount, then build its upgrade from the popout.
	var info: Dictionary = await _open(shell, ids.dwelling)
	var panel: Dictionary = info.get("panel", {})
	_no_scroll(failures, info, "dwelling")
	_check(failures, bool(info.get("open", false)) and String(info.get("mode", "")) == "building_info", "dwelling popout open")
	_check(failures, String(info.get("title", "")) == String(info.get("expected_title", "")), "dwelling title")
	_check(failures, String(panel.get("kind", "")) == "dwelling", "dwelling kind %s" % panel.get("kind", ""))
	_check(failures, bool(info.get("icon_loaded", false)), "dwelling painting")
	var recruit := _entry(panel.get("recruit", []), "unit_id", base_unit)
	_check(failures, int(recruit.get("max", 0)) == 10 and int(recruit.get("amount", 0)) == 10 and bool(recruit.get("button_enabled", false)), "recruit card %s" % recruit)
	_check(failures, float(recruit.get("name_width", 0.0)) > 40.0, "dwelling card hides the creature name %s" % recruit)
	await _capture(template_id, "dwelling", viewport_size)
	var view = shell.get("_building_info_surface")
	var army_before := _army_count(session, base_unit)
	_check(failures, bool(view.call("validation_set_recruit_amount", base_unit, 3)), "recruit amount 3")
	_check(failures, bool(view.call("validation_press_recruit", base_unit)), "recruit pressed")
	await _frames(3)
	_dismiss_presentation(shell)
	await _frames(2)
	info = shell.call("validation_building_information_snapshot", ids.dwelling)
	panel = info.get("panel", {})
	recruit = _entry(panel.get("recruit", []), "unit_id", base_unit)
	var town_after: Dictionary = TownRules.get_active_town(SessionState.ensure_active_session())
	_check(failures, int(town_after.get("available_recruits", {}).get(base_unit, -1)) == 7, "reserve after recruit %s" % town_after.get("available_recruits", {}))
	_check(failures, _army_count(SessionState.ensure_active_session(), base_unit) == army_before + 3, "army gained 3")
	_check(failures, bool(info.get("open", false)) and int(recruit.get("max", 0)) == 7, "popout refreshed after recruit %s" % recruit)
	_no_scroll(failures, info, "dwelling after recruit")

	# The Muster Hall shows the same recruit cards for every creature in town.
	shell.call("_close_town_catalog", false)
	await _frames(2)
	shell.call("validation_open_town_catalog", "muster")
	await _frames(4)
	var muster_snapshot: Dictionary = shell.call("validation_town_catalog_snapshot")
	var muster_rows: Array = TownRules.get_muster_catalog(SessionState.ensure_active_session())
	var muster_cards: Array = shell.get_node("%RecruitActions").get_children().filter(func(node): return node.has_method("snapshot"))
	_check(failures, String(muster_snapshot.get("mode", "")) == "muster" and muster_cards.size() == muster_rows.size() and int(muster_snapshot.get("muster_card_count", 0)) == muster_rows.size(), "muster cards %d for %d rows" % [muster_cards.size(), muster_rows.size()])
	_check(failures, not bool(shell.call("_building_popout_needs_scroll")), "muster hall needs a scrollbar")
	var muster_card = null
	for card in muster_cards:
		if String(card.get("unit_id")) == base_unit:
			muster_card = card
	_check(failures, muster_card != null and float(muster_card.call("snapshot").get("name_width", 0.0)) > 40.0, "muster card hides the creature name")
	_check(failures, muster_card != null and int(muster_card.call("snapshot").get("max", 0)) == 7 and muster_card.find_child("Stats", true, false) != null and muster_card.find_child("Role_*", true, false) != null, "muster card matches the dwelling card")
	await _capture(template_id, "muster", viewport_size)
	if muster_card != null:
		_check(failures, bool(muster_card.call("set_amount", 2)) and bool(muster_card.call("press_recruit")), "muster recruit pressed")
	await _frames(3)
	_dismiss_presentation(shell)
	await _frames(2)
	town_after = TownRules.get_active_town(SessionState.ensure_active_session())
	_check(failures, int(town_after.get("available_recruits", {}).get(base_unit, -1)) == 5, "reserve after muster recruit %s" % town_after.get("available_recruits", {}))
	_check(failures, _army_count(SessionState.ensure_active_session(), base_unit) == army_before + 5, "army gained 2 from the muster hall")
	shell.call("_close_town_catalog", false)
	await _frames(2)
	info = await _open(shell, ids.dwelling)
	panel = info.get("panel", {})
	view = shell.get("_building_info_surface")
	var upgrade: Dictionary = panel.get("upgrade", {})
	_check(failures, bool(upgrade.get("has_line", false)) and String(upgrade.get("next_id", "")) == String(ids.dwelling_upgrade), "dwelling upgrade line %s" % upgrade)
	_check(failures, String(upgrade.get("status", "")) == "ready" and bool(upgrade.get("button_enabled", false)), "dwelling upgrade ready %s" % upgrade)
	_check(failures, bool(view.call("validation_press_upgrade")), "upgrade pressed")
	await _frames(3)
	_dismiss_presentation(shell)
	await _frames(2)
	town_after = TownRules.get_active_town(SessionState.ensure_active_session())
	_check(failures, String(ids.dwelling_upgrade) in town_after.get("built_buildings", []), "upgrade built")
	info = await _open(shell, ids.dwelling_upgrade)
	_no_scroll(failures, info, "upgraded dwelling")
	panel = info.get("panel", {})
	_check(failures, String(panel.get("kind", "")) == "dwelling" and bool(panel.get("upgrade", {}).get("complete", false)), "upgraded dwelling complete %s" % panel.get("upgrade", {}))
	var troop_upgrade := false
	for service in panel.get("services", []):
		var service_id := String(service.get("id", ""))
		troop_upgrade = troop_upgrade or (service_id.begins_with("town_upgrade:") and service_id.ends_with(":" + base_unit) and bool(service.get("enabled", false)))
	_check(failures, troop_upgrade, "stationed troop upgrade offered %s" % [panel.get("services", [])])

	# Magic guild: five levels of spells, the built level first, the next level for tomorrow.
	info = await _open(shell, ids.guild)
	_no_scroll(failures, info, "guild")
	panel = info.get("panel", {})
	var levels: Array = panel.get("guild_levels", [])
	_check(failures, String(panel.get("kind", "")) == "guild", "guild kind")
	_check(failures, levels.size() == 5, "guild levels %d" % levels.size())
	var all_spells := []
	for level in levels:
		_check(failures, not level.get("spell_ids", []).is_empty(), "guild level %d empty" % int(level.get("level", 0)))
		_check(failures, bool(level.get("built", false)) == (int(level.get("level", 0)) == 1), "guild level %d built flag" % int(level.get("level", 0)))
		for spell_id in level.get("spell_ids", []):
			_check(failures, spell_id not in all_spells, "spell %s on two levels" % spell_id)
			all_spells.append(spell_id)
	_check(failures, all_spells.size() == TownRules.spell_ids_through_tier(town_after, 5).size(), "guild covers the library")
	_check(failures, int(panel.get("guild_level_shown", 0)) == 1 and panel.get("spell_cards_shown", []).size() == levels[0].get("spell_ids", []).size(), "guild shows level I")
	await _capture(template_id, "guild", viewport_size)
	view = shell.get("_building_info_surface")
	_check(failures, bool(view.call("validation_show_guild_level", 3)), "guild level III tab")
	await _frames(2)
	_no_scroll(failures, shell.call("validation_building_information_snapshot", ids.guild), "guild level III")
	var shown: Dictionary = view.call("validation_snapshot")
	_check(failures, shown.get("spell_cards_shown", []).size() == levels[2].get("spell_ids", []).size(), "guild shows level III")
	_check(failures, String(shown.get("upgrade", {}).get("status", "")) == "tomorrow" and not bool(shown.get("upgrade", {}).get("button_enabled", true)), "guild upgrade waits for tomorrow %s" % shown.get("upgrade", {}))

	# Tavern: this week's two heroes; a hire leaves its place empty until next week.
	info = await _open(shell, TAVERN_ID)
	_no_scroll(failures, info, "tavern")
	panel = info.get("panel", {})
	var heroes: Array = panel.get("heroes", [])
	var live_session = SessionState.ensure_active_session()
	var offer: Array = HeroCommandRules.tavern_offer_ids(live_session)
	var pool: Array = HeroCommandRules.recruitable_hero_ids(live_session)
	_check(failures, String(panel.get("kind", "")) == "tavern" and heroes.size() == 2, "tavern heroes %d" % heroes.size())
	_check(failures, offer.size() == 2 and offer == HeroCommandRules.tavern_offer_ids(live_session) and pool.size() > 2, "weekly offer %s of %s" % [offer, pool])
	_check(failures, heroes.map(func(hero): return String(hero.get("hero_id", ""))) == offer, "popout shows the weekly offer")
	for hero_id_value in offer:
		_check(failures, String(hero_id_value) in pool, "offered hero %s is hireable" % hero_id_value)
	var outsider := ""
	for hero_id_value in pool:
		if hero_id_value not in offer:
			outsider = String(hero_id_value)
			break
	var probe = SessionStateStore.new_session_data()
	probe.from_dict(live_session.to_dict())
	_check(failures, outsider != "" and not bool(TownRules.hire_hero_at_active_town(probe, outsider).get("ok", true)), "hero outside the weekly offer was hired")
	await _capture(template_id, "tavern", viewport_size)
	var hire_id := String(heroes[0].get("hero_id", "")) if not heroes.is_empty() else ""
	var commanders := HeroCommandRules.player_hero_count(SessionState.ensure_active_session())
	view = shell.get("_building_info_surface")
	_check(failures, hire_id != "" and bool(view.call("validation_press_hire", hire_id)), "hire pressed")
	await _frames(3)
	_dismiss_presentation(shell)
	await _frames(2)
	_check(failures, HeroCommandRules.player_hero_count(SessionState.ensure_active_session()) == commanders + 1, "hero hired")
	info = shell.call("validation_building_information_snapshot", TAVERN_ID)
	_check(failures, _entry(info.get("panel", {}).get("heroes", []), "hero_id", hire_id).is_empty() and info.get("panel", {}).get("heroes", []).size() == 1, "hired hero left an empty place")
	_check(failures, HeroCommandRules.tavern_offer_ids(SessionState.ensure_active_session()).size() == 1, "hired place refilled this week")
	_no_scroll(failures, info, "tavern after hire")
	var next_week = SessionStateStore.new_session_data()
	next_week.from_dict(SessionState.ensure_active_session().to_dict())
	next_week.day = 9
	var next_offer: Array = HeroCommandRules.tavern_offer_ids(next_week)
	_check(failures, next_offer.size() == 2 and hire_id not in next_offer, "next week offer %s" % [next_offer])

	# Training, artifact exchange and market services.
	info = await _open(shell, ids.training)
	_no_scroll(failures, info, "training")
	panel = info.get("panel", {})
	var train_id := "town_train:%s" % ids.training
	_check(failures, String(panel.get("kind", "")) == "training" and bool(_entry(panel.get("services", []), "id", train_id).get("enabled", false)), "training service %s" % [panel.get("services", [])])
	info = await _open(shell, ids.artifacts)
	_no_scroll(failures, info, "artifact exchange")
	panel = info.get("panel", {})
	var buy_count := 0
	for service in panel.get("services", []):
		if String(service.get("id", "")).begins_with("town_buy:"):
			buy_count += 1
	_check(failures, String(panel.get("kind", "")) == "artifact_exchange" and buy_count > 0, "artifact offers %d" % buy_count)
	info = await _open(shell, ids.market)
	_no_scroll(failures, info, "market")
	panel = info.get("panel", {})
	_check(failures, String(panel.get("kind", "")) == "market" and not _entry(panel.get("services", []), "id", "open:trade").is_empty(), "market hand-off")
	_check(failures, bool(panel.get("upgrade", {}).get("has_line", false)), "market upgrade line")

	# A plain building: description, effects and its next stage.
	info = await _open(shell, ids.fort)
	_no_scroll(failures, info, "fort")
	panel = info.get("panel", {})
	_check(failures, String(panel.get("kind", "")) == "building" and String(info.get("effects", "")).contains("Effects:"), "fort effects")
	_check(failures, String(info.get("description", "")) == String(info.get("expected_description", "")), "fort description")
	_check(failures, bool(panel.get("upgrade", {}).get("has_line", false)) and String(panel.get("upgrade", {}).get("next_id", "")) != "", "fort next stage")
	var catalog_rect: Rect2 = shell.get("_town_catalog_panel").get_global_rect()
	var view_rect: Rect2 = shell.get("_building_info_surface").get_global_rect()
	_check(failures, view_rect.size.x <= catalog_rect.size.x and view_rect.position.x >= catalog_rect.position.x - 1.0, "popout body fits the panel %s in %s" % [view_rect, catalog_rect])
	await _capture(template_id, "fort", viewport_size)

	# A town with a dwelling for every tier still musters without scrolling.
	shell.call("_close_town_catalog", false)
	await _frames(2)
	var full_session = SessionState.ensure_active_session()
	var towns: Array = full_session.overworld.get("towns", [])
	var active_town: Dictionary = TownRules.get_active_town(full_session)
	var tier_units := []
	for index in range(towns.size()):
		if String(towns[index].get("placement_id", "")) != String(active_town.get("placement_id", "")):
			continue
		var built: Array = towns[index].get("built_buildings", []).duplicate()
		var reserves: Dictionary = towns[index].get("available_recruits", {}).duplicate()
		for building_id_value in Board.town_building_ids(template):
			var building := ContentService.get_building(String(building_id_value))
			if int(building.get("dwelling_tier", 0)) > 0 and int(building.get("choice_branch", 1)) == 1 and int(building.get("stage", 1)) == 1:
				if String(building_id_value) not in built:
					built.append(String(building_id_value))
				reserves[String(building.get("unlock_unit_id", ""))] = 6
				tier_units.append(String(building.get("unlock_unit_id", "")))
		towns[index]["built_buildings"] = built
		towns[index]["available_recruits"] = reserves
	full_session.overworld["towns"] = towns
	shell.call("validation_open_town_catalog", "muster")
	await _frames(4)
	var full_rows: Array = TownRules.get_muster_catalog(full_session)
	var full_cards: Array = shell.get_node("%RecruitActions").get_children().filter(func(node): return node.has_method("snapshot"))
	_check(failures, tier_units.size() == 7 and full_rows.size() >= 7 and full_cards.size() == full_rows.size(), "full muster cards %d rows %d tiers %d" % [full_cards.size(), full_rows.size(), tier_units.size()])
	_check(failures, not bool(shell.call("_building_popout_needs_scroll")), "full muster hall needs a scrollbar")
	await _capture(template_id, "muster_full", viewport_size)
	shell.queue_free()
	await _frames(2)
	return {"ok": failures.is_empty(), "template_id": template_id, "viewport": viewport_size, "failures": failures}

func _pick_buildings(template_ids: Array) -> Dictionary:
	var ids := {}
	for building_id_value in template_ids:
		var building_id := String(building_id_value)
		var building := ContentService.get_building(building_id)
		var stage := int(building.get("stage", 1))
		if int(building.get("dwelling_tier", 0)) == 1 and int(building.get("choice_branch", 1)) == 1:
			ids["dwelling" if stage == 1 else "dwelling_upgrade"] = building_id
		elif String(building.get("line_id", "")) == "guild" and stage == 1:
			ids["guild"] = building_id
		elif String(building.get("line_id", "")) == "market" and stage == 1:
			ids["market"] = building_id
		elif String(building.get("line_id", "")) == "fort" and stage == 1:
			ids["fort"] = building_id
		elif building.has("hero_visit_reward") and String(building.get("faction_id", "")) == "" and not ids.has("training"):
			ids["training"] = building_id
		elif bool(building.get("artifact_exchange", false)):
			ids["artifacts"] = building_id
	return ids

func _open(shell: Node, building_id: String) -> Dictionary:
	_dismiss_presentation(shell)
	await _frames(2)
	shell.call("validation_activate_building_information", building_id)
	await _frames(3)
	return shell.call("validation_building_information_snapshot", building_id)

func _no_scroll(failures: Array, info: Dictionary, label: String) -> void:
	_check(failures, not bool(info.get("scroll_needed", true)), "%s popout needs a scrollbar (panel %s)" % [label, info.get("panel_size", Vector2.ZERO)])

func _dismiss_presentation(shell: Node) -> void:
	var stage = shell.get("_town_stage_view")
	if stage != null and stage.has_method("dismiss_town_action_presentation"):
		stage.call("dismiss_town_action_presentation")

func _entry(entries: Array, key: String, value: String) -> Dictionary:
	for entry in entries:
		if entry is Dictionary and String(entry.get(key, "")) == value:
			return entry
	return {}

func _army_count(session, unit_id: String) -> int:
	var total := 0
	for stack in session.overworld.get("hero", {}).get("army", {}).get("stacks", []):
		if String(stack.get("unit_id", "")) == unit_id:
			total += int(stack.get("count", 0))
	var town: Dictionary = TownRules.get_active_town(session)
	for stack in town.get("garrison", []):
		if stack is Dictionary and String(stack.get("unit_id", "")) == unit_id:
			total += int(stack.get("count", 0))
	return total

func _check(failures: Array, condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)

func _frames(count: int) -> void:
	for _index in range(count):
		await get_tree().process_frame

func _first_player_town(session) -> Dictionary:
	for town_value in session.overworld.get("towns", []):
		if town_value is Dictionary and String(town_value.get("owner", "")) == "player":
			return town_value
	return {}

func _station_active_hero(session, town: Dictionary) -> void:
	var entrance: Dictionary = OverworldLevelRulesScript.town_entrance(town)
	var position := {"x": int(entrance.get("x", 0)), "y": int(entrance.get("y", 0))}
	if entrance.has("level"):
		position["level"] = int(entrance.get("level", 0))
	session.overworld["hero_position"] = position.duplicate(true)
	var hero = session.overworld.get("hero", {})
	if hero is Dictionary:
		hero["x"] = position.x
		hero["y"] = position.y
		hero["position"] = position.duplicate(true)
		session.overworld["hero"] = hero
		var heroes: Array = session.overworld.get("player_heroes", [])
		for index in range(heroes.size()):
			if heroes[index] is Dictionary and String(heroes[index].get("id", "")) == String(hero.get("id", "")):
				heroes[index]["x"] = position.x
				heroes[index]["y"] = position.y
				heroes[index]["position"] = position.duplicate(true)
		session.overworld["player_heroes"] = heroes

func _capture(template_id: String, step: String, viewport_size: Vector2i) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png("%s/%s_%s_%dx%d.png" % [CAPTURE_DIR, template_id, step, viewport_size.x, viewport_size.y])
