extends Node

## Recruit responsiveness regression. Recruits through the Muster Hall cards,
## a dwelling popout and the plain recruit order on a real TownShell, then
## checks that the screen shows exactly what a full redraw from the new state
## shows (cards, popout, stores, army, stage, cached town view) and that each
## recruit took the fast path: one shared post-order read scope with one town
## view build, the preflight signature reused from the previous order, and the
## Muster cards and popout updated in place. Counters, not wall-clock times,
## so the report is not timing-sensitive. A direct session edit between two
## recruits must invalidate the reused preflight signature.

const TownShellScene = preload("res://scenes/town/TownShell.tscn")
const TownBuildingPanel = preload("res://scripts/core/TownBuildingPanel.gd")
const TownBuildingPanelView = preload("res://scenes/town/TownBuildingPanelView.gd")
const TownRecruitCard = preload("res://scenes/town/TownRecruitCard.gd")
const Board = preload("res://scripts/core/TownConstructionBoard.gd")
const OverworldLevelRulesScript = preload("res://scripts/core/OverworldLevelRules.gd")
const REPORT_ID := "TOWN_RECRUIT_RESPONSIVENESS_REPORT"

var _failures := []
var _steps := []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state(session)
	var town := _first_player_town(session)
	if town.is_empty():
		_finish({"error": "player_town_missing"})
		return
	var template := ContentService.get_town(String(town.get("town_id", "")))
	var dwellings := _tier_dwellings(Board.town_building_ids(template))
	if dwellings.size() < 2:
		_finish({"error": "town has fewer than two dwelling tiers"})
		return
	var low_building := String(dwellings[0])
	var high_building := String(dwellings[1])
	var low_unit := String(ContentService.get_building(low_building).get("unlock_unit_id", ""))
	var high_unit := String(ContentService.get_building(high_building).get("unlock_unit_id", ""))
	town["built_buildings"] = ["building_town_hall", low_building, high_building]
	town["available_recruits"] = {low_unit: 10, high_unit: 4}
	town["garrison"] = []
	town["last_build_day"] = 0
	session.day = 2
	_station_active_hero(session, town)
	var visit: Dictionary = OverworldRules.set_active_town_visit(session, String(town.get("placement_id", "")))
	if not bool(visit.get("ok", false)):
		_finish({"error": "town_visit", "visit": visit})
		return
	var low_cost: Dictionary = OverworldRules.town_recruit_cost(session, TownRules.get_active_town(session), low_unit)
	var high_cost: Dictionary = OverworldRules.town_recruit_cost(session, TownRules.get_active_town(session), high_unit)
	# Stores for exactly three low and one high recruit, so every recruit
	# changes what the other cards can pay for and the last ones run dry.
	var resources := {}
	for resource_id in OverworldRules.LIVE_STOCKPILE_RESOURCE_KEYS:
		resources[String(resource_id)] = int(low_cost.get(resource_id, 0)) * 3 + int(high_cost.get(resource_id, 0))
	session.overworld["resources"] = resources
	session = SessionState.set_active_session(session)
	var shell = TownShellScene.instantiate()
	add_child(shell)
	await _frames(4)

	# 1. Muster Hall: recruit two of the low tier from its card.
	shell.call("validation_open_town_catalog", "muster")
	await _frames(3)
	var card = _muster_card(shell, low_unit)
	_check(card != null, "muster card for %s" % low_unit)
	if card != null:
		var counters := _counters(shell)
		_check(bool(card.call("set_amount", 2)) and bool(card.call("press_recruit")), "muster recruit pressed")
		_verify_recruit(shell, "muster", low_unit, 2, counters, low_cost)
		_verify_muster_cards(shell, "muster")
		_check(int(_counters(shell).muster_card_updates) == int(counters.muster_card_updates) + 1 and int(_counters(shell).muster_card_rebuilds) == int(counters.muster_card_rebuilds), "muster cards were not updated in place %s -> %s" % [counters, _counters(shell)])
	await _settle(shell)

	# 2. Dwelling popout: recruit the high tier, which empties the stores of it.
	shell.call("_close_town_catalog", false)
	await _frames(2)
	shell.call("validation_activate_building_information", high_building)
	await _frames(3)
	var view = shell.get("_building_info_surface")
	var counters_popout := _counters(shell)
	_check(bool(view.call("validation_set_recruit_amount", high_unit, 1)) and bool(view.call("validation_press_recruit", high_unit)), "popout recruit pressed")
	_verify_recruit(shell, "popout", high_unit, 1, counters_popout, high_cost)
	_verify_popout(shell, high_building, "popout")
	_check(int(_counters(shell).popout_in_place) == int(counters_popout.popout_in_place) + 1, "popout was not refreshed in place %s -> %s" % [counters_popout, _counters(shell)])
	await _settle(shell)

	# 3. Plain recruit order with no dialog open.
	shell.call("_close_town_catalog", false)
	await _frames(2)
	var counters_plain := _counters(shell)
	shell.call("_on_recruit_action_pressed", low_unit, 1)
	_verify_recruit(shell, "plain", low_unit, 1, counters_plain, low_cost)
	await _settle(shell)

	# 4. A direct session edit between orders must not reuse the stored
	# preflight signature: the recap has to show the real store change.
	var live = SessionState.ensure_active_session()
	var stores: Dictionary = live.overworld.get("resources", {})
	for resource_id in low_cost:
		stores[resource_id] = int(stores.get(resource_id, 0)) + int(low_cost[resource_id]) * 2
	live.overworld["resources"] = stores
	var counters_edit := _counters(shell)
	shell.call("validation_open_town_catalog", "muster")
	await _frames(3)
	card = _muster_card(shell, low_unit)
	_check(card != null and bool(card.call("set_amount", 1)) and bool(card.call("press_recruit")), "muster recruit after a direct edit")
	_verify_recruit(shell, "after_edit", low_unit, 1, counters_edit, low_cost, false)
	_verify_muster_cards(shell, "after_edit")

	shell.queue_free()
	await _frames(2)
	_finish({"low_unit": low_unit, "high_unit": high_unit, "steps": _steps})

## Checks one recruit right after the click, before any frame: the order's
## effect, every visible surface against a fresh read of the new state, and the
## fast-path counters.
func _verify_recruit(shell: Node, label: String, unit_id: String, count: int, before_counters: Dictionary, unit_cost: Dictionary, expect_reuse: bool = true) -> void:
	var session = SessionState.ensure_active_session()
	var recap: Dictionary = shell.get("_last_action_recap")
	var counters := _counters(shell)
	var step := {"label": label, "unit_id": unit_id, "count": count, "counters_before": before_counters, "counters_after": counters}
	_check(bool(recap.get("active", false)) and String(recap.get("action_id", "")) == "recruit:%s" % unit_id, "%s: recap %s" % [label, recap])
	# Stores: the recap's delta is exactly the price, and the resource chip
	# shows the new stockpile.
	var expected_delta := []
	for resource_id in OverworldRules.LIVE_STOCKPILE_RESOURCE_KEYS:
		if int(unit_cost.get(resource_id, 0)) > 0:
			expected_delta.append("%s -%d" % [resource_id, int(unit_cost[resource_id]) * count])
	_check(String(recap.get("affected", "")).contains("Stores %s" % ", ".join(expected_delta)), "%s: recap stores delta %s, expected %s" % [label, recap.get("affected", ""), expected_delta])
	var chip: Dictionary = shell.get("_resource_label").call("validation_snapshot")
	for resource_id in OverworldRules.LIVE_STOCKPILE_RESOURCE_KEYS:
		_check(int(chip.get("resources", {}).get(resource_id, -1)) == int(session.overworld.get("resources", {}).get(resource_id, -2)), "%s: resource chip %s stale" % [label, resource_id])
	var items_ok := true
	for item in chip.get("popup_items", []):
		var amount := int(session.overworld.get("resources", {}).get(String(item.get("resource_id", "")), 0))
		items_ok = items_ok and int(item.get("amount", -1)) == amount and String(item.get("text", "")).ends_with("  %d" % amount)
	_check(items_ok, "%s: resource popup items stale %s" % [label, chip.get("popup_items", [])])
	# Army: the destination holder, the army bar and the stage show the new troops.
	var town: Dictionary = TownRules.get_active_town(session)
	var destination: Dictionary = HeroCommandRules.town_recruitment_destination(session, town)
	var holder_count := 0
	for stack in destination.get("stacks", []):
		if stack is Dictionary and String(stack.get("unit_id", "")) == unit_id:
			holder_count += int(stack.get("count", 0))
	step["holder_count"] = holder_count
	var bar: Dictionary = shell.call("validation_army_management_snapshot")
	_check(JSON.stringify(bar).contains(unit_id), "%s: army bar lacks %s" % [label, unit_id])
	var stage_town: Dictionary = shell.get("_town_stage_view").get("_town")
	_check(stage_town.get("garrison", []) == town.get("garrison", []) and stage_town.get("available_recruits", {}) == town.get("available_recruits", {}), "%s: stage shows stale garrison/reserve" % label)
	# The cached town view equals a fresh build of the new state.
	OverworldRules.begin_normalized_read_scope(session)
	TownRules.begin_read_scope(session)
	var cached: Dictionary = shell.call("_active_town_entity_view_state", town, false)
	var hit := bool(shell.get("_last_town_entity_cache_result").get("hit", false))
	var direct: Dictionary = shell.call("_build_active_town_entity_view_state", false)
	shell.call("_refresh_active_town_dynamic_view_state", direct, town, false)
	var fresh_signature := TownRules.town_action_consequence_signature(session)
	TownRules.end_read_scope(session)
	OverworldRules.end_normalized_read_scope(session)
	_check(hit, "%s: town view cache missed right after the recruit refresh" % label)
	_check(cached == direct, "%s: cached town view differs from a fresh build" % label)
	# The next order's preflight signature is the fresh signature of this state.
	var remembered: Dictionary = shell.get("_remembered_consequence_signature_entry")
	_check(remembered.get("signature", {}) == fresh_signature, "%s: stored preflight signature differs from a fresh read" % label)
	# Fast path: one view build, preflight reuse, no detached save copy.
	_check(int(counters.entity_builds) == int(before_counters.entity_builds) + 1, "%s: town view builds %d -> %d" % [label, before_counters.entity_builds, counters.entity_builds])
	if expect_reuse:
		_check(int(counters.signature_reuse) == int(before_counters.signature_reuse) + 1, "%s: preflight signature was read cold" % label)
	else:
		_check(int(counters.signature_reuse) == int(before_counters.signature_reuse), "%s: preflight reused a signature after a direct session edit" % label)
	var context_surface: Dictionary = shell.call("_active_town_entity_view_state", town, false).get("town_context_surface", {})
	_check(not bool(context_surface.get("save_context_included", true)), "%s: hidden event strip built the save context" % label)
	_steps.append(step)

## Every Muster card must render exactly like a card configured from scratch
## with the current catalog row, stores and tooltip.
func _verify_muster_cards(shell: Node, label: String) -> void:
	var session = SessionState.ensure_active_session()
	var town: Dictionary = TownRules.get_active_town(session)
	var destination := String(HeroCommandRules.town_recruitment_destination(session, town).summary)
	var rows: Array = TownRules.get_muster_catalog(session)
	var cards: Array = shell.get("_recruit_actions").get_children().filter(func(node): return node is TownRecruitCard and not node.is_queued_for_deletion())
	_check(cards.size() == rows.size(), "%s: muster cards %d for %d rows" % [label, cards.size(), rows.size()])
	_check(String(shell.get("_town_catalog_subtitle_label").text) == destination, "%s: muster subtitle stale" % label)
	_check(String(shell.get("_response_label").text) == "Upgrade stationed troops", "%s: muster troop-upgrade caption replaced by %s" % [label, shell.get("_response_label").text])
	var resources: Dictionary = session.overworld.get("resources", {})
	for index in range(mini(cards.size(), rows.size())):
		var fresh = TownRecruitCard.new()
		add_child(fresh)
		fresh.configure(TownBuildingPanel.recruit_card(rows[index]), resources, true, String(shell.call("_catalog_muster_tooltip", rows[index], destination)))
		var live_dump := _render_dump(cards[index])
		var fresh_dump := _render_dump(fresh)
		_check(live_dump == fresh_dump, "%s: muster card %s differs from a fresh card\nlive=%s\nfresh=%s" % [label, rows[index].get("unit_id", ""), live_dump, fresh_dump])
		fresh.queue_free()

## The open popout must render exactly like a popout configured from scratch
## with a fresh model of the new state.
func _verify_popout(shell: Node, building_id: String, label: String) -> void:
	var session = SessionState.ensure_active_session()
	var view = shell.get("_building_info_surface")
	OverworldRules.begin_normalized_read_scope(session)
	TownRules.begin_read_scope(session)
	var model := TownBuildingPanel.build(session, building_id, {})
	TownRules.end_read_scope(session)
	OverworldRules.end_normalized_read_scope(session)
	_check(view.call("model") == model, "%s: popout model differs from a fresh model" % label)
	var fresh = TownBuildingPanelView.new()
	add_child(fresh)
	fresh.configure(model, true)
	var live_dump := _render_dump(view)
	var fresh_dump := _render_dump(fresh)
	_check(live_dump == fresh_dump, "%s: popout differs from a fresh popout\nlive=%s\nfresh=%s" % [label, live_dump, fresh_dump])
	fresh.queue_free()

## Text, state, colors and textures of every live control under `node`, in
## tree order, ignoring generated node names.
func _render_dump(node: Node) -> Array:
	var rows := []
	_collect(node, rows)
	return rows

func _collect(node: Node, rows: Array) -> void:
	if node.is_queued_for_deletion():
		return
	var name_text := "" if String(node.name).begins_with("@") else String(node.name)
	if node is Label:
		rows.append("Label|%s|%s|%s|%s|%s" % [name_text, node.text, node.tooltip_text, node.visible, node.get_theme_color("font_color").to_html()])
	elif node is Button:
		rows.append("Button|%s|%s|%s|%s|%s" % [name_text, node.text, node.disabled, node.tooltip_text, node.visible])
	elif node is Range:
		rows.append("Range|%s|%s|%s|%s|%s" % [name_text, node.min_value, node.max_value, node.value, node.editable])
	elif node is TextureRect:
		rows.append("Texture|%s|%s|%s" % [name_text, node.texture.resource_path if node.texture != null else "", node.tooltip_text])
	elif node is PanelContainer:
		var style = node.get_theme_stylebox("panel")
		rows.append("Panel|%s|%s" % [name_text, (style as StyleBoxFlat).bg_color.to_html() if style is StyleBoxFlat else ""])
	elif node is Control:
		rows.append("Control|%s|%s" % [name_text, node.visible])
	for child in node.get_children():
		_collect(child, rows)

func _counters(shell: Node) -> Dictionary:
	var view = shell.get("_building_info_surface")
	return {
		"entity_builds": int(shell.get("_validation_town_entity_build_count")),
		"signature_reuse": int(shell.get("_validation_consequence_signature_reuse_count")),
		"muster_card_updates": int(shell.get("_validation_muster_card_update_count")),
		"muster_card_rebuilds": int(shell.get("_validation_muster_card_rebuild_count")),
		"popout_in_place": int(view.call("validation_in_place_refresh_count")) if view != null else 0,
	}

func _muster_card(shell: Node, unit_id: String):
	for node in shell.get("_recruit_actions").get_children():
		if node is TownRecruitCard and not node.is_queued_for_deletion() and String(node.unit_id) == unit_id:
			return node
	return null

func _settle(shell: Node) -> void:
	await _frames(3)
	var stage = shell.get("_town_stage_view")
	if stage != null and stage.has_method("dismiss_town_action_presentation"):
		stage.call("dismiss_town_action_presentation")
	await _frames(2)

func _tier_dwellings(template_ids: Array) -> Array:
	var by_tier := {}
	for building_id_value in template_ids:
		var building := ContentService.get_building(String(building_id_value))
		var tier := int(building.get("dwelling_tier", 0))
		if tier in [1, 2] and int(building.get("choice_branch", 1)) == 1 and int(building.get("stage", 1)) == 1 and String(building.get("unlock_unit_id", "")) != "":
			by_tier[tier] = String(building_id_value)
	var result := []
	for tier in [1, 2]:
		if by_tier.has(tier):
			result.append(by_tier[tier])
	return result

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

func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures.append(label)

func _frames(count: int) -> void:
	for _index in range(count):
		await get_tree().process_frame

func _finish(extra: Dictionary) -> void:
	var report := {"ok": _failures.is_empty() and not extra.has("error"), "schema": "town_recruit_responsiveness_report_v1", "failures": _failures}
	report.merge(extra, true)
	if bool(report.ok):
		print("%s %s" % [REPORT_ID, JSON.stringify(report)])
	else:
		push_error("%s failed: %s" % [REPORT_ID, JSON.stringify(report)])
	get_tree().quit(0 if bool(report.ok) else 1)
