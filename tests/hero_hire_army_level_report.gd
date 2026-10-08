extends Node

## Hired heroes come with an army and a level. Drives the real tavern rules,
## the shared hire path, save restore and the Town tavern popout:
## - every weekly offer over many sessions and weeks leads at least one
##   creature, a tier-1 company first, and is level 1 most weeks with level 2
##   and 3 sometimes;
## - an offer reads the same after repeated reads, a save round trip, a hire in
##   the other tavern place and a popout refresh;
## - hiring delivers exactly the offered level (earned through
##   HeroProgressionRules) and army;
## - the tavern card shows each offer's level and army without a scrollbar;
## - no transfer can empty a hero, and a town defense won by the garrison
##   leaves the hero a creature;
## - an older save's empty-army hero gets a starting army on load.
## Set HERO_HIRE_CAPTURE_DIR to save the tavern popout when run in a window.

const TownShellScene = preload("res://scenes/town/TownShell.tscn")
const HeroCommand = preload("res://scripts/core/HeroCommandRules.gd")
const Progression = preload("res://scripts/core/HeroProgressionRules.gd")
const Store = preload("res://scripts/core/SessionStateStore.gd")
const Battle = preload("res://scripts/core/BattleRules.gd")
const OverworldLevelRulesScript = preload("res://scripts/core/OverworldLevelRules.gd")
const TAVERN_ID := "building_wayfarers_hall"
const SEEDS := 48
const WEEKS := 26
const HIRE_WEEKS := [0, 5, 11, 19]

var _failures := []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var base = _fixture()
	var report := {"schema": "hero_hire_army_level_report_v1"}
	report["offers"] = _offer_sweep(base)
	report["hires"] = _hire_sweep(base)
	report["save_round_trip"] = _save_round_trip(base)
	report["old_save_migration"] = _old_save_migration(base)
	report["transfers"] = _transfer_floor(base)
	report["town_defense"] = _town_defense_floor(base)
	report["tavern_card"] = await _tavern_card(base)
	report["ok"] = _failures.is_empty()
	report["failures"] = _failures
	if _failures.is_empty():
		print("HERO_HIRE_ARMY_LEVEL_REPORT %s" % JSON.stringify(report))
	else:
		push_error("HERO_HIRE_ARMY_LEVEL_REPORT failed: %s" % JSON.stringify(report))
	get_tree().quit(0 if _failures.is_empty() else 1)

# --- weekly offers ----------------------------------------------------------------

func _offer_sweep(base) -> Dictionary:
	var levels := {1: 0, 2: 0, 3: 0}
	var stack_sizes := {}
	var offers := 0
	var weeks := 0
	var both_veteran_weeks := 0
	var smallest_army := 1 << 30
	for seed_index in range(SEEDS):
		var session = _clone(base)
		session.session_id = "hero_hire_seed_%d" % seed_index
		for week in range(WEEKS):
			session.day = week * 7 + 1 + (seed_index % 7)
			var offer_ids: Array = HeroCommand.tavern_offer_ids(session)
			_check(offer_ids.size() == HeroCommand.TAVERN_OFFER_SIZE, "seed %d week %d offers %s" % [seed_index, week, offer_ids])
			var veterans := 0
			for hero_id_value in offer_ids:
				veterans += 1 if int(HeroCommand.tavern_offer(session, String(hero_id_value)).get("level", 1)) > 1 else 0
			both_veteran_weeks += 1 if veterans == 2 else 0
			weeks += 1
			for hero_id_value in offer_ids:
				var hero_id := String(hero_id_value)
				var offer: Dictionary = HeroCommand.tavern_offer(session, hero_id)
				offers += 1
				var level := int(offer.get("level", 0))
				_check(level >= 1 and level <= 3, "%s level %d" % [hero_id, level])
				levels[level] = int(levels.get(level, 0)) + 1
				var stacks: Array = offer.get("army", {}).get("stacks", [])
				var troops := _troops(stacks)
				smallest_army = mini(smallest_army, troops)
				stack_sizes[stacks.size()] = int(stack_sizes.get(stacks.size(), 0)) + 1
				_check(troops >= 1, "%s week %d offer leads no troops" % [hero_id, week])
				_check(not stacks.is_empty() and _unit_tier(stacks[0]) == 1 and _unit_faction(stacks[0]) == String(ContentService.get_hero(hero_id).get("faction_id", "")), "%s first company is not a tier-1 creature of its faction %s" % [hero_id, stacks])
				_check(offer == HeroCommand.tavern_offer(session, hero_id), "%s offer changed on a second read" % hero_id)
				# Within the week the offer never changes, whatever the day.
				var later = _clone(session)
				later.day = week * 7 + 7
				_check(offer == HeroCommand.tavern_offer(later, hero_id), "%s offer changed later in the week" % hero_id)
	var level_two_share := float(levels[2]) / float(maxi(1, offers))
	var level_three_share := float(levels[3]) / float(maxi(1, offers))
	var level_one_share := float(levels[1]) / float(maxi(1, offers))
	_check(level_one_share >= 0.8 and level_one_share <= 0.93, "level 1 share %.3f" % level_one_share)
	_check(level_two_share >= 0.05 and level_two_share <= 0.16, "level 2 share %.3f" % level_two_share)
	_check(level_three_share >= 0.01 and level_three_share <= 0.06, "level 3 share %.3f" % level_three_share)
	_check(int(stack_sizes.get(2, 0)) > int(stack_sizes.get(1, 0)), "a second company should be common %s" % stack_sizes)
	_check(int(stack_sizes.get(1, 0)) > 0, "some offers should lead a single company %s" % stack_sizes)
	# The two places roll independently: two veterans in one week stay rare.
	var both_share := float(both_veteran_weeks) / float(maxi(1, weeks))
	_check(both_share <= 0.06, "two veterans in %.3f of weeks" % both_share)
	# Every hero in the content, of every faction, has a starting army.
	var heroes_without_army := []
	for hero_value in ContentService.load_json("res://content/heroes.json").get("items", []):
		var template: Dictionary = hero_value
		var army: Dictionary = HeroCommand.starting_army_for_hero(template, "hero_hire_content|%s" % String(template.get("id", "")))
		if _troops(army.get("stacks", [])) < 1:
			heroes_without_army.append(String(template.get("id", "")))
	_check(heroes_without_army.is_empty(), "heroes without a starting army %s" % [heroes_without_army])
	return {"offers": offers, "levels": levels, "stack_sizes": stack_sizes, "smallest_army": smallest_army, "both_veteran_week_share": snappedf(both_share, 0.001),
		"level_shares": [snappedf(level_one_share, 0.001), snappedf(level_two_share, 0.001), snappedf(level_three_share, 0.001)]}

# --- the shared hire path ---------------------------------------------------------

func _hire_sweep(base) -> Dictionary:
	var hires := 0
	var leveled := 0
	for seed_index in range(SEEDS):
		for week in HIRE_WEEKS:
			var session = _clone(base)
			session.session_id = "hero_hire_seed_%d" % seed_index
			session.day = int(week) * 7 + 2
			var town := _player_town(session)
			var offer_ids: Array = HeroCommand.tavern_offer_ids(session)
			if offer_ids.size() < 2:
				_check(false, "seed %d week %d has %d offers" % [seed_index, week, offer_ids.size()])
				continue
			var first := String(offer_ids[0])
			var second := String(offer_ids[1])
			var first_offer: Dictionary = HeroCommand.tavern_offer(session, first)
			var second_offer: Dictionary = HeroCommand.tavern_offer(session, second)
			var result: Dictionary = HeroCommand.recruit_hero_at_town(session, town, first)
			_check(bool(result.get("ok", false)), "hire %s: %s" % [first, result.get("message", "")])
			if not bool(result.get("ok", false)):
				continue
			hires += 1
			var hero: Dictionary = HeroCommand.hero_by_id(session, first)
			_check_hired_hero(hero, first_offer)
			if int(first_offer.get("level", 1)) > 1:
				leveled += 1
			# The other place keeps its hero, level and army after the hire.
			_check(HeroCommand.tavern_offer_ids(session) == [second], "after hiring %s the offer is %s" % [first, HeroCommand.tavern_offer_ids(session)])
			_check(HeroCommand.tavern_offer(session, second) == second_offer, "hiring %s rerolled %s" % [first, second])
			# Hiring the second place too gives exactly its offer.
			var second_result: Dictionary = HeroCommand.recruit_hero_at_town(session, town, second)
			_check(bool(second_result.get("ok", false)), "hire %s: %s" % [second, second_result.get("message", "")])
			if bool(second_result.get("ok", false)):
				hires += 1
				_check_hired_hero(HeroCommand.hero_by_id(session, second), second_offer)
				if int(second_offer.get("level", 1)) > 1:
					leveled += 1
	_check(leveled > 0, "no leveled hero was hired over %d hires" % hires)
	return {"hires": hires, "leveled_hires": leveled}

func _check_hired_hero(hero: Dictionary, offer: Dictionary) -> void:
	var hero_id := String(offer.get("hero_id", ""))
	_check(not hero.is_empty(), "%s missing after hire" % hero_id)
	if hero.is_empty():
		return
	var level := int(offer.get("level", 1))
	var stacks: Array = hero.get("army", {}).get("stacks", [])
	_check(_troops(stacks) >= 1, "%s was hired without troops" % hero_id)
	_check(_stack_rows(stacks) == _stack_rows(offer.get("army", {}).get("stacks", [])), "%s army %s differs from offer %s" % [hero_id, stacks, offer.get("army", {})])
	_check(int(hero.get("level", 0)) == level, "%s level %d, offered %d" % [hero_id, int(hero.get("level", 0)), level])
	_check(int(hero.get("experience", 0)) >= Progression.experience_for_level(level), "%s experience %d below level %d" % [hero_id, int(hero.get("experience", 0)), level])
	_check(int(hero.get("experience", 0)) < int(hero.get("next_level_experience", 0)), "%s experience past its next level" % hero_id)
	_check(int(hero.get("level_up_presented", 0)) == level and Progression.pending_choices_remaining(hero) == 0, "%s arrives with level-ups waiting" % hero_id)
	var template := ContentService.get_hero(hero_id)
	var starting: Array = template.get("starting_specialties", [])
	_check(hero.get("specialties", []).size() == starting.size() + level - 1, "%s specialties %s at level %d" % [hero_id, hero.get("specialties", []), level])
	var command: Dictionary = template.get("command", {})
	var expected := {}
	for stat in ["attack", "defense", "power", "knowledge"]:
		expected[stat] = int(command.get(stat, 0))
	for earned in range(2, level + 1):
		expected[Progression.command_gain_stat(hero, earned)] += 1
	_check(expected.keys().all(func(stat): return int(hero.get("command", {}).get(stat, 0)) == int(expected[stat])), "%s command %s at level %d, expected %s" % [hero_id, hero.get("command", {}), level, expected])
	var mana: Dictionary = hero.get("spellbook", {}).get("mana", {})
	_check(int(mana.get("current", -1)) == int(mana.get("max", -2)), "%s arrives without full mana %s" % [hero_id, mana])

# --- saves ------------------------------------------------------------------------

func _save_round_trip(base) -> Dictionary:
	var session = _clone(base)
	session.session_id = "hero_hire_save_trip"
	session.day = 3 * 7 + 4
	var before := _offers(session)
	var town := _player_town(session)
	var hired_id := String(HeroCommand.tavern_offer_ids(session)[0])
	HeroCommand.recruit_hero_at_town(session, town, hired_id)
	var after_hire := _offers(session)
	var restored: Dictionary = SaveService._normalize_restore_result(session.to_dict())
	_check(bool(restored.get("ok", false)), "save restore %s" % restored.get("message", ""))
	var loaded = restored.get("session", null)
	if loaded == null:
		return {"ok": false}
	_check(_offers(loaded) == after_hire, "offers changed across a save round trip: %s vs %s" % [_offers(loaded), after_hire])
	_check(_stack_rows(HeroCommand.hero_by_id(loaded, hired_id).get("army", {}).get("stacks", [])) == _stack_rows(HeroCommand.hero_by_id(session, hired_id).get("army", {}).get("stacks", [])), "hired army changed across a save round trip")
	_check(int(HeroCommand.hero_by_id(loaded, hired_id).get("level", 0)) == int(HeroCommand.hero_by_id(session, hired_id).get("level", -1)), "hired level changed across a save round trip")
	var plain = Store.SessionData.new()
	plain.from_dict(session.to_dict())
	OverworldRules.normalize_overworld_state(plain)
	_check(_offers(plain) == after_hire, "offers changed across to_dict/from_dict")
	return {"offers_before_hire": before, "offers_after_load": _offers(loaded)}

func _old_save_migration(base) -> Dictionary:
	var session = _clone(base)
	session.session_id = "hero_hire_old_save"
	session.day = 9
	var heroes: Array = session.overworld.get("player_heroes", [])
	# An old save: a reserve commander hired empty, and a primary whose army
	# was lost to an older bug.
	var empty_hire := HeroCommand.build_hero_from_template(ContentService.get_hero("hero_caelen"), OverworldLevelRulesScript.town_entrance(_player_town(session)), {"id": "hero_caelen_army", "name": "Field Army", "stacks": []}, session)
	heroes.append(empty_hire)
	for index in range(heroes.size()):
		if bool(heroes[index].get("is_primary", false)):
			heroes[index]["army"] = {"id": "primary_army", "name": "Field Army", "stacks": []}
	session.overworld["player_heroes"] = heroes
	session.overworld["army"] = {"id": "primary_army", "name": "Field Army", "stacks": []}
	# An AI raid commander whose host was lost the same way.
	var encounters: Array = session.overworld.get("encounters", [])
	var raid_tile: Dictionary = OverworldLevelRulesScript.town_entrance(_player_town(session))
	encounters.append({"placement_id": "hero_hire_empty_raid", "encounter_id": "hero_hire_empty_raid", "x": int(raid_tile.get("x", 0)) + 2, "y": int(raid_tile.get("y", 0)),
		"spawned_by_faction_id": "faction_mireclaw", "enemy_commander_state": {"roster_hero_id": "hero_vaska"},
		"enemy_army": {"id": "hero_hire_empty_raid", "name": "Raid Host", "stacks": []}})
	session.overworld["encounters"] = encounters
	var payload: Dictionary = session.to_dict()
	var restored: Dictionary = SaveService._normalize_restore_result(payload)
	var loaded = restored.get("session", null)
	_check(loaded != null, "old save did not restore")
	if loaded == null:
		return {"ok": false}
	var armies := {}
	for hero in loaded.overworld.get("player_heroes", []):
		var stacks: Array = hero.get("army", {}).get("stacks", [])
		armies[String(hero.get("id", ""))] = _troops(stacks)
		_check(_troops(stacks) >= 1, "%s still has no troops after loading an old save" % hero.get("id", ""))
	_check(_troops(loaded.overworld.get("army", {}).get("stacks", [])) >= 1, "active army mirror is still empty after load")
	var raid_troops := -1
	for encounter in loaded.overworld.get("encounters", []):
		if encounter is Dictionary and String(encounter.get("placement_id", "")) == "hero_hire_empty_raid":
			raid_troops = _troops(encounter.get("enemy_army", {}).get("stacks", []))
	_check(raid_troops >= 1, "AI raid commander still has no host after load (%d)" % raid_troops)
	armies["hero_hire_empty_raid"] = raid_troops
	# Loading the same save twice gives the same armies.
	var again = SaveService._normalize_restore_result(payload).get("session", null)
	_check(again != null and _stack_rows(HeroCommand.hero_by_id(again, "hero_caelen").get("army", {}).get("stacks", [])) == _stack_rows(HeroCommand.hero_by_id(loaded, "hero_caelen").get("army", {}).get("stacks", [])), "restored army differs between two loads")
	return {"restored_troops": armies}

# --- the one-creature floor -------------------------------------------------------

func _transfer_floor(base) -> Dictionary:
	var session = _clone(base)
	session.session_id = "hero_hire_transfer_floor"
	session.day = 2
	var town := _player_town(session)
	var hero_id := String(HeroCommand.tavern_offer_ids(session)[0])
	HeroCommand.recruit_hero_at_town(session, town, hero_id)
	town = _player_town(session)
	var refused := 0
	# Town transfers: move every company to the garrison; the last one stays.
	for _attempt in range(4):
		var stacks: Array = HeroCommand.hero_by_id(session, hero_id).get("army", {}).get("stacks", [])
		if stacks.is_empty():
			break
		var result: Dictionary = HeroCommand.transfer_town_stack(session, town, hero_id, HeroCommand.HOLDER_GARRISON, String(stacks[0].get("unit_id", "")), "all")
		town = _player_town(session)
		if not bool(result.get("ok", false)):
			refused += 1
			break
	_check(refused == 1, "moving a hero's last company to the garrison was not refused")
	_check(_troops(HeroCommand.hero_by_id(session, hero_id).get("army", {}).get("stacks", [])) >= 1, "town transfer emptied %s" % hero_id)
	# Slot drag of the last company into the garrison is refused too.
	var last: Array = HeroCommand.hero_by_id(session, hero_id).get("army", {}).get("stacks", [])
	var slot_result: Dictionary = HeroCommand.manage_army_slots(session, town, hero_id, int(last[0].get("slot_index", 0)), HeroCommand.HOLDER_GARRISON, 6, "all")
	_check(not bool(slot_result.get("ok", true)), "slot move emptied %s" % hero_id)
	# Field transfer to the active commander on the same tile is refused for the last company.
	HeroCommand.set_active_hero(session, hero_id)
	var primary_id := String(session.hero_id)
	var field_result: Dictionary = HeroCommand.transfer_field_stack(session, hero_id, primary_id, String(last[0].get("unit_id", "")), "all")
	_check(not bool(field_result.get("ok", true)), "field transfer emptied %s: %s" % [hero_id, field_result])
	_check(_troops(HeroCommand.hero_by_id(session, hero_id).get("army", {}).get("stacks", [])) >= 1, "%s ended with no troops" % hero_id)
	return {"hero_id": hero_id, "refused_town_transfer": refused, "slot_message": String(slot_result.get("message", "")), "field_message": String(field_result.get("message", ""))}

func _town_defense_floor(base) -> Dictionary:
	var session = _clone(base)
	session.session_id = "hero_hire_town_defense"
	var town := _player_town(session)
	var hero_id := String(session.hero_id)
	var hero: Dictionary = HeroCommand.hero_by_id(session, hero_id)
	var garrison_unit := String(hero.get("army", {}).get("stacks", [{}])[0].get("unit_id", ""))
	session.battle = {
		"context": {"type": "town_defense", "town_placement_id": String(town.get("placement_id", ""))},
		"player_commander_source": {"type": "town_hero", "hero_id": hero_id},
		"player_commander_state": hero.duplicate(true),
		"stacks": [
			{"side": "player", "source_type": "hero_army", "source_hero_id": hero_id, "unit_id": garrison_unit, "unit_hp": 10, "total_health": 0},
			{"side": "player", "source_type": "town_garrison", "source_town_placement_id": String(town.get("placement_id", "")), "unit_id": garrison_unit, "unit_hp": 10, "total_health": 50},
		],
	}
	Battle._sync_player_force_from_battle(session)
	session.battle = {}
	var hero_troops := _troops(HeroCommand.hero_by_id(session, hero_id).get("army", {}).get("stacks", []))
	var garrison_troops := _troops(_player_town(session).get("garrison", []))
	_check(hero_troops == 1 and garrison_troops == 4, "town defense won by the garrison left the hero %d and the garrison %d" % [hero_troops, garrison_troops])
	return {"hero_troops": hero_troops, "garrison_troops": garrison_troops}

# --- the tavern card --------------------------------------------------------------

func _tavern_card(base) -> Dictionary:
	# Show a week that offers a veteran, ideally a level-3 one leading a tier-2
	# company, so the card's level and army are both visible.
	var session = null
	var chosen_seed := ""
	for seed_index in range(400):
		var probe = _clone(base)
		probe.session_id = "hero_hire_card_%d" % seed_index
		probe.day = 2
		var levels := []
		var tiers := []
		for hero_id in HeroCommand.tavern_offer_ids(probe):
			var offer: Dictionary = HeroCommand.tavern_offer(probe, String(hero_id))
			levels.append(int(offer.get("level", 1)))
			for stack in offer.get("army", {}).get("stacks", []):
				tiers.append(_unit_tier(stack))
		if levels.size() != 2 or levels.max() < 2 or tiers.size() < 3:
			continue
		if session == null:
			session = probe
			chosen_seed = probe.session_id
		if levels.max() == 3 and 2 in tiers:
			session = probe
			chosen_seed = probe.session_id
			break
	_check(session != null, "no card fixture with a veteran offer in 400 seeds")
	if session == null:
		return {}
	var town := _player_town(session)
	town["built_buildings"] = ["building_town_hall", TAVERN_ID]
	_replace_town(session, town)
	session.overworld["resources"] = {"gold": 20000, "wood": 40, "ore": 40}
	_station_active_hero(session, town)
	var visit: Dictionary = OverworldRules.set_active_town_visit(session, String(town.get("placement_id", "")))
	_check(bool(visit.get("ok", false)), "town visit %s" % visit)
	session = SessionState.set_active_session(session)
	var expected := _offers(session)
	var original_size := get_window().size
	get_window().size = Vector2i(1280, 720)
	var shell = TownShellScene.instantiate()
	add_child(shell)
	await _frames(3)
	var info: Dictionary = await _open(shell)
	var cards: Array = info.get("panel", {}).get("heroes", [])
	_check(not bool(info.get("scroll_needed", true)), "tavern popout needs a scrollbar at 1280x720 (panel %s)" % info.get("panel_size", Vector2.ZERO))
	_check(cards.size() == 2, "tavern shows %d heroes" % cards.size())
	for card in cards:
		var hero_id := String(card.get("hero_id", ""))
		var offer: Dictionary = expected.get(hero_id, {})
		_check(bool(card.get("level_visible", false)) and String(card.get("level_text", "")) == "Level %d" % int(offer.get("level", 0)), "%s card level %s, offer %d" % [hero_id, card.get("level_text", ""), int(offer.get("level", 0))])
		_check(bool(card.get("army_visible", false)) and card.get("army", []) == _stack_rows(offer.get("army", {}).get("stacks", [])), "%s card army %s, offer %s" % [hero_id, card.get("army", []), offer.get("army", {})])
		_check(int(card.get("army_portraits", 0)) == offer.get("army", {}).get("stacks", []).size(), "%s card shows %d creature portraits" % [hero_id, int(card.get("army_portraits", 0))])
	await _capture("tavern_1280x720")
	get_window().size = Vector2i(1920, 1080)
	await _frames(4)
	info = await _open(shell)
	_check(not bool(info.get("scroll_needed", true)), "tavern popout needs a scrollbar at 1920x1080")
	await _capture("tavern_1920x1080")
	# Refreshing the popout or moving on a day in the same week keeps the offer.
	var live = SessionState.ensure_active_session()
	live.day = int(live.day) + 3
	info = await _open(shell)
	var refreshed := {}
	for card in info.get("panel", {}).get("heroes", []):
		refreshed[String(card.get("hero_id", ""))] = [String(card.get("level_text", "")), card.get("army", [])]
	var shown := {}
	for card in cards:
		shown[String(card.get("hero_id", ""))] = [String(card.get("level_text", "")), card.get("army", [])]
	_check(refreshed == shown, "tavern card changed on refresh: %s vs %s" % [refreshed, shown])
	# Hiring from the card gives the hero exactly what the card showed.
	var hire_id := String(cards[0].get("hero_id", "")) if not cards.is_empty() else ""
	var hired_offer: Dictionary = expected.get(hire_id, {})
	var view = shell.get("_building_info_surface")
	_check(hire_id != "" and bool(view.call("validation_press_hire", hire_id)), "hire pressed")
	await _frames(3)
	var stage = shell.get("_town_stage_view")
	if stage != null and stage.has_method("dismiss_town_action_presentation"):
		stage.call("dismiss_town_action_presentation")
	await _frames(2)
	_check_hired_hero(HeroCommand.hero_by_id(SessionState.ensure_active_session(), hire_id), hired_offer)
	info = shell.call("validation_building_information_snapshot", TAVERN_ID)
	_check(not bool(info.get("scroll_needed", true)), "tavern popout needs a scrollbar after the hire")
	shell.queue_free()
	await _frames(2)
	get_window().size = original_size
	return {"seed": chosen_seed, "cards": cards, "offers": expected}

func _open(shell: Node) -> Dictionary:
	var stage = shell.get("_town_stage_view")
	if stage != null and stage.has_method("dismiss_town_action_presentation"):
		stage.call("dismiss_town_action_presentation")
	await _frames(2)
	shell.call("validation_activate_building_information", TAVERN_ID)
	await _frames(3)
	return shell.call("validation_building_information_snapshot", TAVERN_ID)

func _capture(step: String) -> void:
	var directory := OS.get_environment("HERO_HIRE_CAPTURE_DIR")
	if DisplayServer.get_name() == "headless" or directory == "":
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(directory)
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [directory, step])

# --- fixtures ---------------------------------------------------------------------

func _fixture():
	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state(session)
	var town := _player_town(session)
	var built: Array = town.get("built_buildings", []).duplicate()
	if TAVERN_ID not in built:
		built.append(TAVERN_ID)
	town["built_buildings"] = built
	_replace_town(session, town)
	session.overworld["resources"] = {"gold": 99999, "wood": 99, "ore": 99}
	_station_active_hero(session, town)
	return session

func _clone(session):
	var copy = Store.SessionData.new()
	copy.from_dict(session.to_dict())
	return copy

func _offers(session) -> Dictionary:
	var offers := {}
	for hero_id in HeroCommand.tavern_offer_ids(session):
		offers[String(hero_id)] = HeroCommand.tavern_offer(session, String(hero_id))
	return offers

func _player_town(session) -> Dictionary:
	for town_value in session.overworld.get("towns", []):
		if town_value is Dictionary and String(town_value.get("owner", "")) == "player":
			return town_value
	return {}

func _replace_town(session, town: Dictionary) -> void:
	var towns: Array = session.overworld.get("towns", [])
	for index in range(towns.size()):
		if towns[index] is Dictionary and String(towns[index].get("placement_id", "")) == String(town.get("placement_id", "")):
			towns[index] = town
	session.overworld["towns"] = towns

func _station_active_hero(session, town: Dictionary) -> void:
	var position: Dictionary = OverworldLevelRulesScript.town_entrance(town)
	var heroes: Array = session.overworld.get("player_heroes", [])
	for index in range(heroes.size()):
		if heroes[index] is Dictionary and String(heroes[index].get("id", "")) == String(session.overworld.get("active_hero_id", "")):
			heroes[index]["position"] = position.duplicate(true)
	session.overworld["player_heroes"] = heroes
	session.overworld["hero_position"] = position.duplicate(true)
	var hero = session.overworld.get("hero", {})
	if hero is Dictionary:
		hero["position"] = position.duplicate(true)
		session.overworld["hero"] = hero

func _troops(stacks: Variant) -> int:
	var total := 0
	if stacks is Array:
		for stack in stacks:
			if stack is Dictionary and String(stack.get("unit_id", "")) != "":
				total += maxi(0, int(stack.get("count", 0)))
	return total

func _stack_rows(stacks: Variant) -> Array:
	var rows := []
	if stacks is Array:
		for stack in stacks:
			if stack is Dictionary and int(stack.get("count", 0)) > 0:
				rows.append([String(stack.get("unit_id", "")), int(stack.get("count", 0))])
	return rows

func _unit_tier(stack: Dictionary) -> int:
	return int(ContentService.get_unit(String(stack.get("unit_id", ""))).get("tier", 0))

func _unit_faction(stack: Dictionary) -> String:
	return String(ContentService.get_unit(String(stack.get("unit_id", ""))).get("faction_id", ""))

func _check(condition: bool, label: String) -> void:
	if not condition and _failures.size() < 60:
		_failures.append(label)

func _frames(count: int) -> void:
	for _index in range(count):
		await get_tree().process_frame
