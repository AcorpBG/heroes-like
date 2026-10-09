extends Node
# The overworld has no Command/Frontier drawers: every hero order is issued from
# the hero sheet. Covers casting (one overworld spell per hero per day, the
# spellbook opening on overworld spells), artifact equip/stow, stack splits,
# and the "built today" / "cast today" roster badges, on a generated map.

const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")
const OverworldRulesScript = preload("res://scripts/core/OverworldRules.gd")
const SpellRulesScript = preload("res://scripts/core/SpellRules.gd")
const HeroCommandRulesScript = preload("res://scripts/core/HeroCommandRules.gd")
const REPORT_ID := "OVERWORLD_HERO_SHEET_ORDERS_REGRESSION"
const FIRST_SPELL := "spell_waystride"
const SECOND_SPELL := "spell_trailglyph"
const ARTIFACT_ID := "artifact_trailsinger_boots"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	ContentService.clear_generated_scenario_drafts()
	var config := ScenarioSelectRulesScript.build_random_map_player_config(
		"hero-sheet-orders-1", "", "", 2, "land", false, "homm3_small",
		ScenarioSelectRulesScript.RANDOM_MAP_TEMPLATE_SELECTION_MODE_SIZE_DEFAULT, "", "", "normal")
	var setup := ScenarioSelectRulesScript.build_random_map_skirmish_setup_with_retry(config, "normal", ScenarioSelectRulesScript.RANDOM_MAP_PLAYER_RETRY_POLICY)
	var session = ScenarioSelectRulesScript.start_random_map_skirmish_session_from_setup(setup)
	if session == null or session.scenario_id == "":
		return _fail("The generated session did not start.")
	SessionState.set_active_session(session)

	var shell = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	add_child(shell)
	for i in range(4): await get_tree().process_frame
	session = shell.get("_session")
	var hero: Dictionary = SpellRulesScript.ensure_hero_spellbook(session.overworld.get("hero", {}))
	hero.spellbook.known_spell_ids = [FIRST_SPELL, SECOND_SPELL]
	hero.spellbook.mana = {"current": 40, "max": 40}
	hero["artifacts"] = {"equipped": {}, "inventory": [ARTIFACT_ID]}
	session.overworld["hero"] = hero
	session.overworld.movement["current"] = 2
	HeroCommandRulesScript.commit_active_hero(session)
	shell.call("_refresh")
	await get_tree().process_frame
	for removed in ["OpenCommand", "OpenFrontier", "CommandPanel", "FrontierPanel", "ActionPanel"]:
		if shell.get_node_or_null("%" + removed) != null:
			return _fail("Retired drawer node %s is still in the overworld." % removed)

	# Spellbook tab opens on overworld spells with a Cast button.
	var sheet = shell.validation_open_hero_sheet("Spellbook")
	if sheet == null or not sheet.is_interactive():
		return _fail("The hero sheet did not open with live orders.")
	var spellbook: Control = sheet.find_child("Spellbook", true, false)
	var context: OptionButton = spellbook.find_child("SpellContext", true, false)
	var cast_button: Button = spellbook.find_child("PrepareSpell", true, false)
	if sheet.current_tab() != "Spellbook" or context.selected != 2 or not cast_button.visible or cast_button.text != "Cast spell":
		return _fail("The spellbook did not open on overworld spells: tab=%s context=%d button=%s" % [sheet.current_tab(), context.selected, cast_button.text])

	# First cast works, spends mana, records the day and closes the sheet.
	var mana_before := int(session.overworld.hero.spellbook.mana.current)
	sheet.spell_cast_requested.emit(FIRST_SPELL)
	await get_tree().process_frame
	var hero_id := String(session.overworld.get("active_hero_id", ""))
	if not OverworldRulesScript.hero_cast_spell_today(session, hero_id) or sheet.visible:
		return _fail("Casting from the sheet did not record today's spell or close the sheet: %s" % shell.get("_last_message"))
	if int(session.overworld.hero.spellbook.mana.current) >= mana_before:
		return _fail("Casting did not spend mana.")
	var roster_button: Button = shell.find_child("SpellCastToday", true, false).get_parent() if shell.find_child("SpellCastToday", true, false) != null else null
	if roster_button == null or not roster_button.get_node("SpellCastToday").visible:
		return _fail("The roster does not show the cast-today badge.")

	# A second spell the same day is refused, in the sheet and by the rules.
	var blocker: Control = shell.get("_spell_cast_input_blocker")
	for i in range(600):
		if not blocker.visible: break
		await get_tree().process_frame
	sheet = shell.validation_open_hero_sheet("Spellbook")
	if sheet == null:
		return _fail("The hero sheet did not reopen after the cast cue.")
	for action in sheet.orders.get("spell_actions", []):
		if not bool(action.get("disabled", false)):
			return _fail("A second overworld spell is offered on the same day: %s" % action.get("id"))
	var second: Dictionary = OverworldRulesScript.cast_overworld_spell(session, SECOND_SPELL)
	if bool(second.get("ok", false)) or not String(second.get("message", "")).contains("already cast"):
		return _fail("The rules allowed a second overworld spell today: %s" % second)

	# Artifacts: equip from the backpack, then stow.
	sheet.show_tab("Artifacts")
	var equip: Button = sheet.find_child("ArtifactOrder_equip_artifact_%s" % ARTIFACT_ID, true, false)
	if equip == null:
		return _fail("The artifact tab offers no Equip order.")
	equip.pressed.emit()
	await get_tree().process_frame
	var equipped: Dictionary = session.overworld.hero.artifacts.equipped
	if ARTIFACT_ID not in equipped.values() or sheet.current_tab() != "Artifacts":
		return _fail("Equip from the sheet did not equip the artifact or lost the tab.")
	var slot := String(equipped.keys()[equipped.values().find(ARTIFACT_ID)])
	var stow: Button = sheet.find_child("ArtifactOrder_unequip_artifact_%s" % slot, true, false)
	if stow == null:
		return _fail("The artifact tab offers no Stow order.")
	stow.pressed.emit()
	await get_tree().process_frame
	if ARTIFACT_ID not in session.overworld.hero.artifacts.inventory:
		return _fail("Stow from the sheet did not return the artifact to the backpack.")

	# Army: split half of the first stack into an empty slot.
	var holder: Dictionary = sheet.orders.get("army_holder", {})
	var stacks_before := _stack_count(session)
	var source := -1
	var target := -1
	for stack in HeroCommandRulesScript.hero_inspection_snapshot(session, hero_id).get("inspection_army_slots", []):
		if source < 0 and int(stack.get("count", 0)) >= 2: source = int(stack.get("slot_index", -1))
	var used := []
	for stack in HeroCommandRulesScript.hero_inspection_snapshot(session, hero_id).get("inspection_army_slots", []):
		used.append(int(stack.get("slot_index", -1)))
	for index in range(HeroCommandRulesScript.ARMY_SLOT_COUNT):
		if index not in used:
			target = index
			break
	if holder.is_empty() or source < 0 or target < 0:
		return _fail("No splittable stack or free slot in the starting army: %s" % holder)
	sheet.army_operation_requested.emit(hero_id, source, hero_id, target, "half")
	await get_tree().process_frame
	if _stack_count(session) != stacks_before + 1 or not sheet.visible:
		return _fail("Splitting from the sheet did not add a stack.")
	sheet.close_sheet()

	# A town that built today shows its badge in the roster.
	var town_index := -1
	for index in range(session.overworld.towns.size()):
		if String(session.overworld.towns[index].get("owner", "")) == "player": town_index = index
	if town_index < 0:
		return _fail("The player owns no town.")
	session.overworld.towns[town_index]["last_build_day"] = int(session.day)
	shell.call("_refresh")
	await get_tree().process_frame
	var built: Control = shell.find_child("BuiltToday", true, false)
	if built == null or not built.visible:
		return _fail("The roster does not show the built-today badge.")

	# Next day the hero may cast again.
	session.day += 1
	var actions: Array = OverworldRulesScript.get_spell_actions(session)
	if actions.filter(func(action): return not bool(action.get("disabled", true))).is_empty():
		return _fail("The spell limit did not reset on the next day.")

	print("%s %s" % [REPORT_ID, JSON.stringify({"ok": true})])
	shell.queue_free()
	await get_tree().process_frame
	get_tree().quit(0)

func _stack_count(session) -> int:
	var count := 0
	for stack in session.overworld.get("army", {}).get("stacks", []):
		if int(stack.get("count", 0)) > 0: count += 1
	return count

func _fail(message: String) -> void:
	push_error("%s %s" % [REPORT_ID, message])
	print("%s %s" % [REPORT_ID, JSON.stringify({"ok": false, "message": message})])
	get_tree().quit(1)
