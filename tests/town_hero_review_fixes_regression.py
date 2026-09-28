"""Town, hero and scenario code-review fixes: multi-hero income and town-hero
scaling, merchant objective artifacts, market affordability search, campaign
level-up carryover, last-stack transfers, town cache/lane refresh and the
shared spellbook's card reuse."""
import argparse
from pathlib import Path

from unified_mines_regression import run_probe

SCRIPT = r'''extends Node
const Factory = preload("res://scripts/core/ScenarioFactory.gd")
const Rules = preload("res://scripts/core/OverworldRules.gd")
const Dev = preload("res://scripts/core/TownDevelopmentRules.gd")
const Towns = preload("res://scripts/core/TownRules.gd")
const Heroes = preload("res://scripts/core/HeroCommandRules.gd")
const Progression = preload("res://scripts/core/HeroProgressionRules.gd")
const Artifacts = preload("res://scripts/core/ArtifactRules.gd")
const Campaigns = preload("res://scripts/core/CampaignRules.gd")
const Difficulty = preload("res://scripts/core/DifficultyRules.gd")
const Levels = preload("res://scripts/core/OverworldLevelRules.gd")
const Spells = preload("res://scripts/core/SpellRules.gd")
const Store = preload("res://scripts/core/SessionStateStore.gd")
const INCOME_ARTIFACT := "artifact_quarry_tally_rod"
var checks := 0
var failures := []
func check(ok: bool, text: String):
	checks += 1
	if not ok: failures.append(text)
func fixture(objectives: Array = [{"type": "flag_true", "flag": "fixture_finished"}]):
	var s = Factory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	s.scenario_id = "town-hero-review-fixture"
	s.scenario_status = "in_progress"
	s.flags["native_random_map_runtime_scenario_record"] = {"id": s.scenario_id, "objectives": {"victory": objectives, "defeat": []}}
	s.overworld.encounters = []; s.overworld.resource_nodes = []; s.overworld.map_objects = []; s.overworld.artifact_nodes = []
	s.overworld.towns = [{"placement_id": "review_town", "town_id": "town_riverwatch", "x": 3, "y": 3, "owner": "player", "built_buildings": ["building_town_hall"], "available_recruits": {}, "garrison": [], "last_build_day": 0}]
	Rules._set_active_hero_position(s, Vector2i(3, 3), 0)
	for id in s.overworld.resources: s.overworld.resources[id] = 999999
	Rules.invalidate_spatial_lookup(s); Rules.normalize_overworld_state(s)
	Rules.set_active_town_visit(s, "review_town")
	return s
func town(s) -> Dictionary:
	return s.overworld.towns[0]
func build(s, id: String) -> void:
	s.day += 1
	var r = Rules.build_in_active_town(s, id)
	check(bool(r.get("ok", false)), "build " + id + ": " + String(r.get("message", "")))
func second_hero_id(s) -> String:
	for hero in ContentService.load_json("res://content/heroes.json").get("items", []):
		if String(hero.id) != String(s.hero_id): return String(hero.id)
	return ""
func add_hero(s, hero_id: String, tile: Vector2i, stacks: Array) -> void:
	var hero := Heroes.build_hero_from_template(ContentService.get_hero(hero_id), {"x": tile.x, "y": tile.y, "level": 0}, {"id": hero_id + "_army", "name": "Field Army", "stacks": stacks}, s)
	s.overworld.player_heroes.append(hero)
	Heroes.normalize_session(s)
func edit_hero(s, hero_id: String, change: Callable) -> void:
	Heroes.commit_active_hero(s)
	var heroes: Array = s.overworld.player_heroes
	for index in range(heroes.size()):
		if String(heroes[index].id) == hero_id:
			heroes[index] = change.call(heroes[index].duplicate(true))
	s.overworld.player_heroes = heroes
	if String(s.overworld.active_hero_id) == hero_id: s.overworld.hero = heroes.filter(func(h): return String(h.id) == hero_id)[0]
	Heroes.normalize_session(s)
func copy(s):
	var saved = Store.SessionData.new(); saved.from_dict(s.to_dict()); Rules.normalize_overworld_state(saved)
	return saved
func _ready(): call_deferred("run")
func run():
	hero_income_and_town_scaling()
	merchant_objective_artifacts()
	market_affordability_search()
	campaign_level_up_marker()
	last_stack_transfers()
	await town_screen_refresh()
	await spellbook_card_reuse()
	print("TOWN_HERO_REVIEW_FIXES_REPORT " + JSON.stringify({"checks": checks, "failures": failures}))
	get_tree().quit(0 if failures.is_empty() else 1)

func hero_income_and_town_scaling():
	var s = fixture()
	var reserve_id := second_hero_id(s)
	add_hero(s, reserve_id, Vector2i(9, 9), [{"unit_id": "unit_river_guard", "count": 3}])
	var with_rod = copy(s)
	edit_hero(with_rod, reserve_id, func(h): return Artifacts.claim_artifact(h, INCOME_ARTIFACT, "Fixture", true).hero)
	check(Artifacts.has_artifact(Heroes.hero_by_id(with_rod, reserve_id), INCOME_ARTIFACT), "fixture rod not owned by reserve hero")
	var switched = copy(with_rod)
	check(Heroes.set_active_hero(switched, reserve_id).ok, "could not select reserve hero")
	var plain = copy(s)
	var gold := {}
	for entry in [["plain", plain], ["rod", with_rod], ["switched", switched]]:
		var before := int(entry[1].overworld.resources.gold)
		Rules.end_turn(entry[1])
		gold[entry[0]] = int(entry[1].overworld.resources.gold) - before
	var expected := int(Difficulty.scale_income_resources(s, {"gold": 120}).get("gold", 120))
	check(int(gold.rod) - int(gold.plain) == expected, "reserve hero's artifact income ignored: %s" % JSON.stringify(gold))
	check(int(gold.switched) == int(gold.rod), "hero selection changed artifact income: %s" % JSON.stringify(gold))
	# Recruit prices and growth follow the town's own hero, not the selected one.
	edit_hero(s, reserve_id, func(h):
		h["specialties"] = ["mustercaptain"]
		return h)
	var unit_id := "unit_river_guard"
	var base_cost: Dictionary = Rules.town_recruit_cost(s, town(s), unit_id)
	check(Heroes.set_active_hero(s, reserve_id).ok, "could not select remote specialist")
	check(Rules.town_recruit_cost(s, town(s), unit_id) == base_cost, "remote selected hero changed town recruit cost")
	var entrance: Dictionary = Levels.town_entrance(town(s))
	Rules._set_active_hero_position(s, Vector2i(int(entrance.x), int(entrance.y)), 0)
	Heroes.commit_active_hero(s)
	var local_cost: Dictionary = Rules.town_recruit_cost(s, town(s), unit_id)
	check(int(local_cost.get("gold", 0)) < int(base_cost.get("gold", 0)), "stationed specialist did not discount recruits: %s vs %s" % [JSON.stringify(local_cost), JSON.stringify(base_cost)])

func merchant_objective_artifacts():
	var probe = fixture()
	for id in ["building_dev_hall_2", "building_market_square", "building_dev_trade_exchange", "building_dev_artifact_exchange"]: build(probe, id)
	var open_offers: Array = Dev.offers(town(probe), probe.day)
	check(open_offers.size() == 3, "merchant fixture has no stock")
	if open_offers.is_empty(): return
	var goal := String(open_offers[0])
	var s = fixture([{"id": "recover_goal", "type": "artifact_owned_by_player", "artifact_id": goal}])
	for id in ["building_dev_hall_2", "building_market_square", "building_dev_trade_exchange", "building_dev_artifact_exchange"]: build(s, id)
	check(Dev.objective_artifact_ids(s) == [goal], "objective artifact ids: %s" % JSON.stringify(Dev.objective_artifact_ids(s)))
	var stock: Array = Dev.offers(town(s), s.day, Dev.objective_artifact_ids(s))
	check(goal not in stock and stock.size() == 3, "merchant still stocks objective artifact")
	check(stock.slice(0, 2) == open_offers.slice(1, 3), "exclusion reshuffled the rest of the weekly stock")
	check(not Towns.perform_response_action(s, "town_buy:" + goal).get("ok", false), "objective artifact bought on day one")
	s.overworld.hero = Artifacts.claim_artifact(s.overworld.hero, goal, "Fixture", false).hero
	var ids: Array = Dev.service_actions(s, town(s)).map(func(a): return String(a.id))
	check("town_sell:" + goal not in ids, "sell action offered for objective artifact")
	check(not Towns.perform_response_action(s, "town_sell:" + goal).get("ok", false), "objective artifact sold")
	check(Artifacts.has_artifact(s.overworld.hero, goal), "objective artifact lost to the merchant")

func market_affordability_search():
	var s = fixture()
	for id in ["building_dev_hall_2", "building_market_square", "building_dev_trade_exchange"]: build(s, id)
	var t := town(s)
	var cost := {"gold": 250, "wood": 1, "ore": 1}
	for pool in [{"gold": 0, "wood": 0, "ore": 0}, {"gold": 900, "wood": 0, "ore": 9}, {"gold": 5000, "wood": 3, "ore": 40}, {"gold": 30000, "wood": 60, "ore": 60}, {"gold": 1200, "wood": 30, "ore": 0}]:
		for available in [0, 1, 7, 40, 150]:
			var linear := 0
			for count in range(available, 0, -1):
				if Rules.can_afford_cost_with_town_market(t, pool, Towns._multiply_resource_cost(cost, count), int(s.day)):
					linear = count
					break
			var searched := Towns._max_market_affordable_count(s, t, pool, cost, available)
			check(searched == linear, "market search %d != linear %d for %s of %d" % [searched, linear, JSON.stringify(pool), available])

func campaign_level_up_marker():
	var s = fixture()
	var hero_id := String(s.hero_id)
	var bundle := Campaigns._normalize_carryover_bundle({"hero_id": hero_id, "hero_progression": {"level": 6, "experience": 6000, "next_level_experience": 7000, "specialties": ["wayfinder", "wayfinder", "spellwright", "spellwright", "borderwarden"]}})
	check(int(bundle.hero_progression.get("level_up_presented", 0)) == 6, "bundle marker not normalized to carried level")
	Campaigns._apply_carryover(s, bundle, {"carryover_import": {"hero_progression": true}})
	var hero: Dictionary = Heroes.primary_hero(s)
	check(int(hero.level) == 6, "carried level lost")
	check(Progression.level_up_summary(hero).is_empty(), "carried levels replay as level-up dialogs: %s" % JSON.stringify(Progression.level_up_summary(hero)))

func last_stack_transfers():
	var s = fixture()
	var hero_id := String(s.overworld.active_hero_id)
	var t := town(s)
	Heroes._set_holder_stacks(s, t, hero_id, [{"unit_id": "unit_river_guard", "count": 5}])
	t["garrison"] = [{"unit_id": "unit_river_guard", "count": 2}]
	s.overworld.towns[0] = t
	check(not Heroes.transfer_town_stack(s, t, hero_id, "garrison", "unit_river_guard", "all").ok, "town transfer emptied the hero")
	check(Heroes.transfer_town_stack(s, t, hero_id, "garrison", "unit_river_guard", "half").ok, "partial town transfer blocked")
	check(not Heroes.manage_army_slots(s, t, hero_id, 0, "garrison", 3, "all").ok, "slot move emptied the hero")
	var disabled_all := false
	for action in Heroes.get_town_transfer_actions(s, t):
		if String(action.id) == "transfer:%s:garrison:unit_river_guard:all" % hero_id: disabled_all = bool(action.disabled)
	check(disabled_all, "town order to hand over the last stack is enabled")
	check(Heroes.transfer_town_stack(s, t, "garrison", hero_id, "unit_river_guard", "all").ok, "garrison could not hand over its troops")
	check(Heroes.hero_by_id(s, hero_id).army.stacks.size() >= 1, "hero lost its army")
	var reserve_id := second_hero_id(s)
	add_hero(s, reserve_id, Vector2i(3, 3), [{"unit_id": "unit_river_guard", "count": 1}])
	check(not Heroes.transfer_field_stack(s, reserve_id, hero_id, "unit_river_guard", "all").ok, "field transfer emptied the reserve hero")
	Heroes._set_holder_stacks(s, t, reserve_id, [{"unit_id": "unit_river_guard", "count": 1}, {"unit_id": "unit_river_guard_veteran", "count": 1}])
	check(Heroes.transfer_field_stack(s, reserve_id, hero_id, "unit_river_guard", "all").ok, "field transfer of a spare stack blocked")

func town_screen_refresh():
	var s = fixture()
	for id in ["building_dev_hall_2", "building_market_square"]: build(s, id)
	s.overworld.towns[0]["garrison"] = [{"unit_id": "unit_river_guard", "count": 4}]
	s = SessionState.set_active_session(s); s.game_state = "town"
	var shell = load("res://scenes/town/TownShell.tscn").instantiate()
	add_child(shell)
	for i in range(8): await get_tree().process_frame
	s = shell._session
	var t: Dictionary = Towns.get_active_town(s)
	# Stale-hero cache: artifacts and mana are part of the town cache key.
	var before := String(shell._town_entity_cache_signature(t, false))
	s.overworld.hero = Artifacts.claim_artifact(s.overworld.hero, INCOME_ARTIFACT, "Fixture", false).hero
	var with_artifact := String(shell._town_entity_cache_signature(t, false))
	check(before != with_artifact, "town cache key ignores hero artifacts")
	s.overworld.hero = Artifacts.claim_artifact(s.overworld.hero, "artifact_trailsinger_boots", "Fixture", true).hero
	var with_equipment := String(shell._town_entity_cache_signature(t, false))
	check(with_equipment != with_artifact, "town cache key ignores equipped artifacts")
	s.overworld.hero.spellbook.mana.current = int(s.overworld.hero.spellbook.mana.get("max", 0)) + 7
	var with_mana := String(shell._town_entity_cache_signature(t, false))
	check(with_mana != with_equipment, "town cache key ignores hero mana")
	check(with_mana.length() <= 4096 and not with_mana.contains("{"), "town cache key became a large JSON-style signature")
	# Walking the hero away and back must still reuse the cached town.
	Rules._set_active_hero_position(s, Vector2i(5, 3), 0)
	s.overworld.movement.current = max(0, int(s.overworld.movement.get("current", 0)) - 2)
	check(String(shell._town_entity_cache_signature(t, false)) == with_mana, "hero movement changed the town cache key")
	# Status plaques are computed once per town state, not every pulse frame.
	var stage = shell._town_stage_view
	var plaques: Array = stage._cached_status_plaque_payloads()
	for i in range(3): await get_tree().process_frame
	check(is_same(plaques, stage._cached_status_plaque_payloads()), "status plaques recomputed between frames")
	# With no dialog open, an order refresh leaves the hidden management lanes alone.
	shell._open_town_catalog("log")
	await get_tree().process_frame
	shell._close_town_catalog(false)
	await get_tree().process_frame
	var hidden_rows: Array = shell._transfer_actions.get_children()
	check(not hidden_rows.is_empty(), "fixture transfer lane is empty")
	check(shell._open_town_catalog_lanes().is_empty(), "closed town dialog reports open lanes")
	shell._refresh()
	await get_tree().process_frame
	check(hidden_rows.all(func(row): return is_instance_valid(row) and not row.is_queued_for_deletion()), "hidden lanes rebuilt after a refresh")
	shell._open_town_catalog("log")
	await get_tree().process_frame
	check(shell._open_town_catalog_lanes().has("transfer") and shell._transfer_actions.is_visible_in_tree(), "log dialog lanes not shown")
	var open_rows: Array = shell._transfer_actions.get_children()
	shell._refresh()
	await get_tree().process_frame
	check(not open_rows.is_empty() and open_rows.all(func(row): return not is_instance_valid(row)), "open lane not rebuilt after a refresh")
	shell.queue_free()
	await get_tree().process_frame

func spellbook_card_reuse():
	var s = fixture()
	var hero: Dictionary = s.overworld.hero.duplicate(true)
	hero.spellbook.mana.current = 5
	var ids: Array = ContentService.load_json("res://content/spells.json").items.map(func(spell): return String(spell.id))
	var book = load("res://scenes/shared/SpellbookView.gd").new()
	add_child(book)
	book.size = Vector2(620, 610)
	book.configure(hero, ids)
	await get_tree().process_frame
	var cards: Array = book._grid.get_children()
	check(cards.size() == ids.size(), "one card per spell")
	book._search.text = "e"; book._search.text_changed.emit("e")
	book._sort.select(1); book._sort.item_selected.emit(1)
	check(book._grid.get_children().size() == cards.size() and cards.all(func(card): return is_instance_valid(card) and not card.is_queued_for_deletion()), "filter change rebuilt spell cards")
	var shown: Array = book._grid.get_children().filter(func(card): return card.visible).map(func(card): return String(card.get_meta("spell_id")))
	check(not shown.is_empty() and shown == book.visible_spell_ids(), "visible cards differ from filtered order")
	var costs: Array = shown.map(func(id): return Spells.adjusted_spell_mana_cost(hero, ContentService.get_spell(id)))
	var ascending := true
	for index in range(1, costs.size()): ascending = ascending and int(costs[index - 1]) <= int(costs[index])
	check(ascending, "mana sort order wrong: %s" % JSON.stringify(costs))
	book._search.text = ""; book._search.text_changed.emit("")
	check(book._grid.get_children().filter(func(card): return card.visible).size() == ids.size(), "cleared filter did not show every card")
	book.queue_free()
	await get_tree().process_frame
'''


if __name__ == '__main__':
    p = argparse.ArgumentParser()
    p.add_argument('--godot', type=Path, required=True)
    p.add_argument('--output', type=Path, required=True)
    args = p.parse_args()
    raise SystemExit(run_probe(SCRIPT, args.godot, args.output, 'TOWN_HERO_REVIEW_FIXES_REPORT'))
