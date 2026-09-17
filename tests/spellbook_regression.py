#!/usr/bin/env python3
"""Shared spellbook, local archive learning, real UI input and packaged owners."""
import sys
import battle_readability_regression as runner

ROOT = runner.ROOT
OUTPUT = ROOT / '.artifacts/spellbook-20260917'
run_probe = runner.run_probe
probe_environment = runner.probe_environment
COMPILED_OWNERS = ('scenes/shared/SpellbookView.gdc', 'scenes/shared/HeroSheet.gdc',
                   'scenes/town/TownShell.gdc', 'scenes/battle/BattleShell.gdc',
                   'scripts/core/TownRules.gdc', 'scripts/core/OverworldRules.gdc')
SCRIPT = r'''extends Node
const Store = preload("res://scripts/core/SessionStateStore.gd")
const Levels = preload("res://scripts/core/OverworldLevelRules.gd")
var checks := 0
var failures := []
var resolution := Vector2i(1280, 720)
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
func _ready() -> void: call_deferred("run")
func frames() -> void:
	for i in range(6): await get_tree().process_frame
func click(control: Control) -> void:
	var point := control.get_global_rect().get_center()
	var window := control.get_window()
	if window != get_tree().root and window.is_embedded(): point += Vector2(window.position)
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	get_tree().root.push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = event.position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		get_tree().root.push_input(event, true)
func key(code: int, viewport: Viewport = null) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		(viewport if viewport != null else get_viewport()).push_input(event)
func capture(label: String) -> void:
	await frames()
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var picture := get_viewport().get_texture().get_image()
	check(picture.get_size() == resolution, "capture resolution mismatch")
	picture.save_png(OS.get_environment("BATTLE_READABILITY_OUT").path_join(label + ".png"))
func fixture():
	return ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
func town_for(session) -> Dictionary:
	for town in session.overworld.towns:
		if town.owner == "player": return town
	return {}
func set_hero(session, position: Dictionary, spells: Array = ["spell_waystride"]) -> void:
	session.overworld.hero_position = position.duplicate(true)
	session.overworld.hero.spellbook.known_spell_ids = spells.duplicate()
	session.overworld.hero.spellbook.mana.current = 0
	HeroCommandRules.commit_active_hero(session)
func clone(session):
	var copy = Store.new_session_data()
	copy.from_dict(session.to_dict().duplicate(true))
	return copy
func learning() -> void:
	var session = fixture()
	var town := town_for(session)
	town.built_buildings.append("building_lantern_archive")
	var entrance := Levels.town_entrance(town)
	set_hero(session, {"x": entrance.x + 4, "y": entrance.y, "level": Levels.level_of(entrance)})
	var original_hero: Dictionary = session.overworld.hero.duplicate(true)
	check(OverworldRules.set_active_town_visit(session, town.placement_id).ok, "remote town browse rejected")
	check(session.overworld.hero == original_hero, "remote management taught active hero")
	var offered := TownRules.accessible_spell_ids(town)
	check(offered.size() > 2, "archive fixture incomplete")
	var remote_before: Dictionary = session.to_dict().duplicate(true)
	check(not TownRules.learn_spell_at_active_town(session, offered[0]).ok, "manual remote learning accepted")
	check(session.to_dict() == remote_before, "remote learning rejection mutated session")
	set_hero(session, entrance)
	var resources: Dictionary = session.overworld.resources.duplicate(true)
	var mana: Dictionary = session.overworld.hero.spellbook.mana.duplicate(true)
	var before_hero: Dictionary = session.overworld.hero.duplicate(true)
	check(OverworldRules.set_active_town_visit(session, town.placement_id).ok, "local visit rejected")
	for id in offered: check(SpellRules.knows_spell(session.overworld.hero, id), "arrival failed to learn " + id)
	check(session.overworld.hero.spellbook.mana == mana and session.overworld.resources == resources, "free learning spent mana/resources")
	var changed: Dictionary = session.overworld.hero.duplicate(true)
	changed.spellbook = before_hero.spellbook
	check(changed == before_hero, "learning changed non-spell hero state")
	check(HeroCommandRules.hero_by_id(session, session.overworld.active_hero_id) == session.overworld.hero, "active roster mirror stale")
	var saved: Dictionary = session.to_dict().duplicate(true)
	check(TownRules.teach_visiting_heroes(session, town).count == 0 and session.to_dict() == saved, "repeat visit not idempotent")
	var restored = clone(session)
	check(restored.overworld.hero.spellbook == session.overworld.hero.spellbook, "save round trip lost learned spells")
	# Wrong map level and uncontrolled castles cannot teach.
	for owner in ["neutral", "enemy"]:
		var unavailable: Dictionary = town.duplicate(true)
		unavailable.owner = owner
		check(TownRules.teach_visiting_heroes(session, unavailable).count == 0, "uncontrolled town taught hero")
	set_hero(session, {"x": entrance.x, "y": entrance.y, "level": 1 if Levels.level_of(entrance) == 0 else 0})
	check(TownRules.teach_visiting_heroes(session, town).count == 0, "cross-level archive teaching")
	# Local reserve hero is taught, never the remotely selected hero.
	var template: Dictionary = {}
	for candidate in ContentService.load_json("res://content/heroes.json").items:
		if candidate.id != session.overworld.active_hero_id:
			template = candidate
			break
	var reserve: Dictionary = HeroCommandRules.build_hero_from_template(template, entrance, {}, session)
	reserve.spellbook.known_spell_ids = ["spell_waystride"]
	reserve.spellbook.mana.current = 0
	session.overworld.player_heroes.append(reserve)
	original_hero = session.overworld.hero.duplicate(true)
	check(TownRules.teach_visiting_heroes(session, town).count > 0, "local reserve not taught")
	check(session.overworld.hero == original_hero, "remote selected hero learned reserve library")
	for id in offered: check(SpellRules.knows_spell(HeroCommandRules.hero_by_id(session, reserve.id), id), "reserve mirror lost spell")
	# Both movement interaction branches perform learning without UI.
	for direct in [true, false]:
		set_hero(session, entrance)
		var result: Dictionary = OverworldRules._resolve_post_move_interaction(session) if direct else OverworldRules._resolve_destination_descriptor_interaction(session, {"kind":"town", "placement_id":town.placement_id,"level":Levels.level_of(entrance)})
		check(result.get("route", "") == "town", "arrival branch did not visit town: " + str(result))
		for id in offered: check(SpellRules.knows_spell(session.overworld.hero, id), "arrival branch failed teaching")
	# Building archives while present is the same learning boundary.
	var built = fixture()
	var building_town := town_for(built)
	set_hero(built, Levels.town_entrance(building_town))
	OverworldRules.set_active_town_visit(built, building_town.placement_id)
	for resource in built.overworld.resources: built.overworld.resources[resource] = 100000
	building_town.last_build_day = -1
	var build_result := OverworldRules.build_in_active_town(built, "building_lantern_archive")
	check(build_result.ok, "archive construction failed: " + str(build_result))
	for id in TownRules.accessible_spell_ids(town_for(built)): check(SpellRules.knows_spell(built.overworld.hero, id), "new archive not taught")
	# Capturing a castle teaches only the hero physically at its entrance.
	var captured = fixture()
	var captured_town := town_for(captured)
	captured_town.owner = "neutral"
	captured_town.built_buildings.append("building_lantern_archive")
	set_hero(captured, Levels.town_entrance(captured_town))
	check(OverworldRules.transition_town_control(captured, captured_town.placement_id, "player").ok, "capture control failed")
	for id in TownRules.accessible_spell_ids(captured_town): check(SpellRules.knows_spell(captured.overworld.hero, id), "captured town did not teach visitor")
	# Every authored town/faction uses its actual tier and school library.
	for authored in ContentService.load_json("res://content/towns.json").items:
		var sample := {"town_id":authored.id,"owner":"player","x":entrance.x,"y":entrance.y,"level":Levels.level_of(entrance),"built_buildings":[]}
		set_hero(session, Levels.town_entrance(sample))
		check(TownRules.teach_visiting_heroes(session, sample).count == 0, "unbuilt town taught spells")
		sample.built_buildings = authored.starting_building_ids + authored.buildable_building_ids
		var eligible := TownRules.accessible_spell_ids(sample)
		TownRules.teach_visiting_heroes(session, sample)
		for spell in ContentService.load_json(ContentService.SPELLS_PATH).items:
			check(SpellRules.knows_spell(session.overworld.hero, spell.id) == (spell.id == "spell_waystride" or spell.id in eligible), "faction/tier learning mismatch: " + authored.id + "/" + spell.id)
func check_book(book: Control) -> void:
	var viewport := book.get_viewport().get_visible_rect()
	for fixed in [book._context, book._role, book._count, book._details]:
		check(viewport.encloses(fixed.get_global_rect()), "book fixed control clipped: " + fixed.name)
	for button in book._grid.get_children():
		check(button.icon != null and button.text != "", "missing spell icon/name")
		check(button.tooltip_text.contains(SpellRules._spell_effect_summary(ContentService.get_spell(button.get_meta("spell_id")), book._hero)), "tooltip lacks actual effect")
		check(button.accessibility_name != "" and button.focus_mode == Control.FOCUS_ALL, "spell inaccessible")
		check(button.size.x >= 222, "spell card collapsed")
func filters(book: Control, all_ids: Array) -> void:
	for context_index in range(3):
		for role_index in range(4):
			book._context.select(context_index)
			book._role.select(role_index)
			book._role.item_selected.emit(role_index)
			var expected := []
			for id in all_ids:
				var spell := ContentService.get_spell(id)
				if context_index != 0 and spell.context != ["", "battle", "overworld"][context_index]: continue
				if role_index != 0 and ["", "damage", "buff", "debuff"][role_index] not in SpellRules.spell_role_categories(spell): continue
				expected.append(id)
			var actual: Array = book.visible_spell_ids()
			actual.sort()
			expected.sort()
			check(actual == expected, "combined filter mismatch")
	book._context.select(0)
	book._role.select(0)
	book._context.item_selected.emit(0)
func run() -> void:
	get_tree().current_scene = null
	var dimensions := OS.get_environment("TOWN_OVERLAY_RESOLUTION").split("x")
	resolution = Vector2i(int(dimensions[0]), int(dimensions[1]))
	get_tree().root.size = resolution
	get_tree().root.content_scale_size = resolution
	learning()
	var session = SessionState.set_active_session(fixture())
	var town := town_for(session)
	town.built_buildings.append_array(["building_lantern_archive", "building_starseer_annex"])
	set_hero(session, Levels.town_entrance(town))
	OverworldRules.set_active_town_visit(session, town.placement_id)
	var shell = load("res://scenes/town/TownShell.tscn").instantiate()
	get_tree().root.add_child(shell)
	get_tree().current_scene = shell
	await frames()
	click(shell._spells_action_button)
	await frames()
	check(shell._town_catalog_mode == "spells" and shell._spellbook_view.is_visible_in_tree(), "town icon did not open shared book")
	check(get_viewport().get_visible_rect().encloses(shell._town_catalog_panel.get_global_rect()), "town book panel exceeds viewport")
	var book: Control = shell._spellbook_view
	check_book(book)
	filters(book, TownRules.accessible_spell_ids(town))
	await capture("town-spellbook")
	if DisplayServer.get_name() != "headless":
		var first: Button = book._grid.get_child(0)
		var hover := InputEventMouseMotion.new()
		hover.position = first.get_global_rect().get_center()
		hover.global_position = hover.position
		get_viewport().push_input(hover, true)
		await get_tree().create_timer(0.85).timeout
		var help = get_node("/root/ContextualHelp")
		check(help._hover_text == first.tooltip_text, "hover did not expose selected spell description")
		if help._hover_card != null:
			var card: Control = help._hover_card.get_ref()
			check(card != null and get_viewport().get_visible_rect().encloses(card.get_global_rect()), "spell tooltip exceeds viewport")
		await capture("town-spell-hover")
		help.dismiss()
	key(KEY_ESCAPE)
	await frames()
	check(not shell._town_catalog_is_open(), "Escape failed to close town book")
	check(get_viewport().gui_get_focus_owner() == shell._spells_action_button, "town book did not restore launcher focus")
	shell.queue_free()
	await frames()
	# Hero page is detached read-only data; all authored spells test scrolling.
	var hero: Dictionary = HeroCommandRules.hero_inspection_snapshot(session, session.overworld.active_hero_id)
	var all_ids: Array = ContentService.load_json(ContentService.SPELLS_PATH).items.map(func(s): return String(s.id))
	hero.spellbook.known_spell_ids = all_ids.duplicate()
	var sheet = load("res://scenes/shared/HeroSheet.gd").new()
	get_tree().root.add_child(sheet)
	sheet.open_hero(hero, null)
	sheet._tabs.current_tab = 3
	await frames()
	var before: Dictionary = session.to_dict().duplicate(true)
	book = sheet._spellbook_view
	check_book(book)
	filters(book, all_ids)
	await frames()
	# Authored multi-role spells must remain in both views, not only their first tag.
	for role_index in [1, 3]:
		book._role.select(role_index)
		book._role.item_selected.emit(role_index)
		check("spell_cinder_burst" in book.visible_spell_ids(), "multi-role spell missing from damage/debuff")
	book._role.select(0)
	book._role.item_selected.emit(0)
	await frames()
	book._grid.get_child(0).grab_focus()
	await frames()
	check(book._details.text != "", "keyboard focus lacks spell description")
	await capture("hero-spellbook")
	book._grid.get_child(book._grid.get_child_count()-1).grab_focus()
	await frames()
	check(book._scroll.scroll_vertical > 0, "focused spell did not scroll into view")
	for i in range(12):
		key(KEY_TAB)
		check(sheet.is_ancestor_of(get_viewport().gui_get_focus_owner()), "focus escaped hero book")
	check(session.to_dict() == before, "hero inspection changed live state")
	key(KEY_ESCAPE)
	check(not sheet.visible, "hero book Escape failed")
	sheet.queue_free()
	await frames()
	# Battle modal uses its actual defending commander, not a remote hero.
	session.battle = BattleRules.create_battle_payload(session, session.overworld.encounters[0])
	session.battle.player_commander_state.spellbook.known_spell_ids = ["spell_cinder_burst", "spell_stone_veil", "spell_waystride"]
	session.battle.player_commander_state.spellbook.mana.current = 30
	var players: Array = session.battle.stacks.filter(func(s): return s.side == "player")
	session.battle.active_stack_id = players[0].battle_id
	session.battle.turn_order = [players[0].battle_id] + session.battle.stacks.filter(func(s): return s.battle_id != players[0].battle_id).map(func(s): return s.battle_id)
	session.battle.turn_index = 0
	session.game_state = "battle"
	shell = load("res://scenes/battle/BattleShell.tscn").instantiate()
	get_tree().root.add_child(shell)
	get_tree().current_scene = shell
	await frames()
	click(shell._spellbook_button)
	await frames()
	check(is_instance_valid(shell._spellbook_dialog) and shell._spellbook_dialog.visible, "battle button did not open book")
	if is_instance_valid(shell._spellbook_dialog):
		book = shell._spellbook_view
		check_book(book)
		check(book._hero.id == session.battle.player_commander_state.id, "wrong battle commander book")
		before = session.to_dict().duplicate(true)
		check(not shell._on_board_hex_destination_requested(1, 1).ok, "battle board accepts input beneath book")
		filters(book, session.battle.player_commander_state.spellbook.known_spell_ids)
		book._select("spell_waystride")
		check(book._prepare.disabled, "adventure spell can be prepared in battle")
		book._select("spell_cinder_burst")
		check(not book._prepare.disabled, "legal battle spell not preparable")
		await capture("battle-spellbook")
		click(book._prepare)
		await frames()
		check(not shell._spellbook_dialog.visible and shell._spell_targeting_id == "spell_cinder_burst", "book did not stage existing targeting flow: visible=%s target=%s disabled=%s" % [shell._spellbook_dialog.visible, shell._spell_targeting_id, book._prepare.disabled])
		check(session.to_dict() == before, "preparing spell cast/spent mana")
		shell._cancel_selected_order()
		shell._open_spellbook()
		await frames()
		key(KEY_ESCAPE, shell._spellbook_dialog)
		await frames()
		check(not shell._spellbook_dialog.visible, "Escape failed to close battle book")
		check(session.to_dict() == before, "canceled book changed battle")
		# Keyboard/controller select and cancel use the same modal, not battle orders.
		shell._spellbook_button.grab_focus()
		key(KEY_ENTER)
		await frames()
		check(shell._spellbook_dialog.visible, "keyboard cannot open battle book")
		book._grid.get_child(0).grab_focus()
		check(book._details.text != "", "battle focus description missing")
		var cancel := InputEventJoypadButton.new()
		cancel.button_index = JOY_BUTTON_B
		cancel.pressed = true
		shell._spellbook_dialog.push_input(cancel)
		cancel = cancel.duplicate()
		cancel.pressed = false
		shell._spellbook_dialog.push_input(cancel)
		await frames()
		check(not shell._spellbook_dialog.visible, "controller cannot cancel battle book")
		# Reopen with insufficient mana: browsing still works, casting is locked.
		session.battle.player_commander_state.spellbook.mana.current = 0
		shell._open_spellbook()
		book._select("spell_cinder_burst")
		check(book._prepare.disabled, "mana lock missing")
		shell._close_spellbook()
		book.configure({}, [], "town")
		check(book._empty.visible and "archives" in book._empty.text, "empty town library is unexplained")
		book.configure({}, [], "inspect")
		check(book._empty.visible and "not learned" in book._empty.text, "empty hero book is unexplained")
	shell.queue_free()
	await frames()
	print("BATTLE_READABILITY_REPORT " + JSON.stringify({"ok":failures.is_empty(),"checks":checks,"failures":failures,"resolution":str(resolution),"catalog_spells":all_ids.size(),"save_version":Store.SAVE_VERSION}))
	get_tree().quit(0 if failures.is_empty() else 1)
'''


def main():
    if '--platform' in sys.argv:
        import packaged_menu_and_turn_readability_regression as package
        package.ui = sys.modules[__name__]
        return package.main()
    runner.OUTPUT = OUTPUT
    runner.SCRIPT = SCRIPT
    runner.run_probe = run_probe
    runner.probe_environment = probe_environment
    return runner.main()


if __name__ == '__main__':
    raise SystemExit(main())
