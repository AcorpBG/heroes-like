#!/usr/bin/env python3
"""Twenty read-only/presentation improvements through live scenes and exports."""
import json
import os
import sys
import graphical_usability_regression as previous
import battle_readability_regression as runner

ROOT = runner.ROOT
OUTPUT = ROOT / '.artifacts/usability-expansion-20-20260917'
run_probe = runner.run_probe
probe_environment = runner.probe_environment
COMPILED_OWNERS = previous.COMPILED_OWNERS + (
    'scenes/shared/SpellbookView.gdc', 'scenes/shared/HeroSheet.gdc',
    'scripts/ui/DecisionDetails.gdc', 'scripts/ui/ReadinessWidgets.gdc')
SCRIPT = previous.SCRIPT.split('func battle()')[0] + r'''
const Details = preload("res://scripts/ui/DecisionDetails.gd")
var completed := []
func bounded(control: Control, message: String) -> void:
	check(Rect2(Vector2.ZERO,Vector2(requested)).encloses(control.get_global_rect()),message+" "+str(control.get_global_rect()))
func search_text(control: LineEdit, text: String) -> void:
	control.text=text
	control.text_changed.emit(text)
	await settle()
func type_query(control: LineEdit, text: String) -> void:
	await search_text(control,"")
	control.grab_focus()
	for character in text:
		for pressed in [true,false]:
			var key:=InputEventKey.new()
			key.keycode=character.to_upper().unicode_at(0)
			key.unicode=character.unicode_at(0)
			key.pressed=pressed
			Input.parse_input_event(key)
			await get_tree().process_frame
	await settle()
	check(control.text==text,"actual keyboard text/focus lost: "+String(control.name))
func spells() -> void:
	var session=ScenarioFactory.create_session("river-pass","normal",SessionState.LAUNCH_MODE_SKIRMISH)
	var hero:Dictionary=session.overworld.hero.duplicate(true)
	hero.spellbook.mana.current=5
	var before:Dictionary=hero.duplicate(true)
	var book=load("res://scenes/shared/SpellbookView.gd").new()
	add_child(book)
	book.position=Vector2(40,30)
	book.size=Vector2(620,610)
	var ids:Array=ContentService.load_json("res://content/spells.json").items.map(func(spell):return spell.id)
	book.configure(hero,ids)
	await settle()
	check(book.visible_spell_ids().size()==ids.size(),"full spell catalog missing")
	await type_query(book._search,"CINDER")
	check(not book.visible_spell_ids().is_empty(),"spell search lost known match")
	for id in book.visible_spell_ids(): check("cinder" in String(ContentService.get_spell(id).name).to_lower(),"spell name search")
	await search_text(book._search,"no_such_spell_123")
	check(book.visible_spell_ids().is_empty() and book._empty.visible,"spell empty search state")
	await search_text(book._search,"")
	completed.append(1)
	check(book._school.item_count>2,"school catalog not populated")
	for index in range(1,book._school.item_count):
		book._school.select(index);book._school.item_selected.emit(index)
		check(not book.visible_spell_ids().is_empty(),"school has no spells")
		for id in book.visible_spell_ids(): check(ContentService.get_spell(id).school_id==book._school.get_selected_metadata(),"school leaks other school")
	book._school.select(0)
	completed.append(2)
	for direction in [1,2]:
		book._sort.select(direction);book._sort.item_selected.emit(direction)
		var last:=-1 if direction==1 else 100000
		for id in book.visible_spell_ids():
			var cost:=SpellRules.adjusted_spell_mana_cost(hero,ContentService.get_spell(id))
			check(cost>=last if direction==1 else cost<=last,"adjusted mana sort")
			last=cost
	completed.append(3)
	book._affordable.button_pressed=true
	for id in book.visible_spell_ids(): check(SpellRules.adjusted_spell_mana_cost(hero,ContentService.get_spell(id))<=5,"unaffordable spell admitted")
	check(book.visible_spell_ids().size()<ids.size(),"affordability filter did nothing")
	book._role.select(1);book._context.select(1);book._rebuild()
	for id in book.visible_spell_ids():
		check("damage" in SpellRules.spell_role_categories(ContentService.get_spell(id)) and ContentService.get_spell(id).context=="battle","combined filters")
	check(hero==before,"spell discovery mutated hero")
	check(book._search in book.focus_controls() and book._school in book.focus_controls(),"new spell controls absent from focus")
	for control in [book._search,book._school,book._sort,book._affordable]: bounded(control,"spell filter clips")
	await capture("spell-discovery")
	completed.append(4)
	book.queue_free();await settle()
func construction() -> void:
	var session=ScenarioFactory.create_session("river-pass","normal",SessionState.LAUNCH_MODE_SKIRMISH)
	var town:Dictionary=session.overworld.towns[0]
	var entrance:Dictionary=Levels.town_entrance(town)
	session.overworld.hero_position=entrance.duplicate(true)
	HeroCommandRules.hero_by_id(session,String(session.overworld.active_hero_id)).position=entrance.duplicate(true)
	HeroCommandRules.normalize_session(session)
	check(OverworldRules.set_active_town_visit(session,String(town.placement_id)).ok,"town visit fixture")
	session.game_state="town"
	session=SessionState.set_active_session(session)
	var shell=load("res://scenes/town/TownShell.tscn").instantiate()
	add_child(shell);await settle()
	shell._on_open_build_catalog_pressed();await settle()
	var before:Dictionary=session.to_dict().duplicate(true)
	var rows:Array=shell._construction_catalog_rows
	var first:String=rows[0].name
	await search_text(shell._construction_search,first.to_upper())
	for card in shell._build_actions.get_children():
		if card.visible: check(first.to_lower() in String(ContentService.get_building(String(card.get_meta("construction_id")).trim_prefix("build:")).name).to_lower(),"construction search wrong card")
	await search_text(shell._construction_search,"no_such_building_123")
	check(shell._confirm_build_button.disabled and shell._selected_build_action_id=="","empty filter leaves committable selection")
	await search_text(shell._construction_search,"")
	completed.append(5)
	for index in range(1,5):
		shell._construction_status.select(index);shell._construction_status.item_selected.emit(index)
		var status:String=shell._construction_status.get_item_text(index)
		for card in shell._build_actions.get_children():
			if card.visible: check(String(card.get_child(0).get_child(0).get_meta("catalog_status"))==status,"construction status mismatch")
			check(card.get_child(0).get_child(0).button_pressed==(String(card.get_meta("construction_id"))==shell._selected_build_action_id),"filtered plan highlight disagrees with confirmation")
	shell._construction_status.select(0);shell._filter_construction_cards()
	completed.append(6)
	check(Details.resource_shortfall({"gold":100,"wood":5},{"gold":23,"wood":8})=={"gold":77},"shortfall is not exact")
	for action in rows:
		shell._refresh_construction_decision(action)
		var missing:=Details.resource_shortfall(action.get("cost",{}),session.overworld.resources)
		if not missing.is_empty() and not action.get("built",false): check(shell._construction_shortfall.text=="Missing: "+TownRules._describe_resources(missing),"selected shortfall wrong")
	completed.append(7)
	var jumped:=false
	for action in rows:
		shell._refresh_construction_decision(action)
		if shell._construction_requirements.get_child_count()==0:continue
		var requirement:String=ContentService.get_building(String(action.building_id)).requires[0]
		await click(shell._construction_requirements.get_child(0));await settle()
		check(shell._selected_build_action_id=="build:"+requirement,"prerequisite did not select its real plan")
		check(shell._construction_search.text=="" and shell._construction_status.selected==0,"prerequisite retained hiding filters")
		jumped=true
		break
	check(jumped,"no real prerequisite click tested")
	check(session.to_dict()==before,"construction inspection spent resources/changed save")
	bounded(shell._town_catalog_panel,"construction ledger exceeds viewport")
	await capture("construction-discovery")
	await click(shell._construction_peek_button);await settle()
	check(not shell._construction_filters.visible and not shell._construction_requirements.visible,"folded view retains extra controls")
	bounded(shell._town_catalog_panel,"folded construction clips")
	await capture("construction-folded")
	completed.append(8)
	shell.queue_free();await settle()
func battle_controls() -> void:
	var session=SessionState.set_active_session(fixture())
	var shell=load("res://scenes/battle/BattleShell.tscn").instantiate()
	add_child(shell);await settle()
	var log_control=shell._message_log
	for index in range(205):log_control.append_message("Archer %d strikes"%index)
	await settle()
	check(log_control.unread>0 and log_control.unread<=200,"collapsed unread count missing/unbounded")
	log_control.set_expanded(true)
	var before:Array=log_control.entries.duplicate()
	await search_text(log_control.search,"Archer 19")
	check(not log_control.filtered_entries().is_empty(),"log search empty match")
	for entry in log_control.filtered_entries():check("Archer 19" in entry,"log filter wrong event")
	check(log_control.entries==before,"search deletes retained history")
	completed.append(9)
	await click(log_control.jump_latest);await settle()
	check(log_control.search.text=="" and log_control.unread==0,"latest does not clear filter/unread")
	check(log_control._following_latest(),"latest did not scroll to end")
	check(log_control.history.text=="\n".join(log_control.entries),"clear log filter did not restore every retained event")
	completed.append(10)
	log_control.history.get_v_scroll_bar().value=0
	log_control.append_message("New casualty")
	await settle()
	check(log_control.unread==1 and log_control.history.get_v_scroll_bar().value==0,"new event interrupts reader or unread wrong")
	completed.append(11)
	var before_battle:Dictionary=session.battle.duplicate(true)
	for index in range(3):
		shell._compact_speed_picker.select(index);shell._compact_speed_picker.item_selected.emit(index)
		check(BattleRules.battle_presentation_speed(session)==["normal","fast","instant"][index],"speed selector did not use rule setting")
		check(SettingsService.battle_playback_speed_id()==["normal","fast","instant"][index],"speed not persisted")
	var after_battle:Dictionary=session.battle.duplicate(true)
	before_battle.erase(BattleRules.PRESENTATION_SPEED_KEY);after_battle.erase(BattleRules.PRESENTATION_SPEED_KEY)
	check(before_battle==after_battle,"speed performed battle action")
	check(log_control.search.name in shell._last_battle_keyboard_focus_cycle_names,"log search absent from keyboard cycle")
	bounded(log_control,"log clips");bounded(shell._compact_speed_picker,"speed control clips")
	await capture("battle-reading")
	completed.append(12)
	shell.queue_free();await settle()
func roster_and_hero() -> void:
	var session=SessionState.set_active_session(ScenarioFactory.create_session("river-pass","normal",SessionState.LAUNCH_MODE_SKIRMISH))
	var shell=load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	add_child(shell);await settle()
	for button in shell._hero_actions.get_children():
		var hero:Dictionary=HeroCommandRules.hero_by_id(session,String(button.get_meta("hero_id")))
		check(button.has_node("Movement") and button.get_node("Movement").value==int(hero.movement.current),"roster movement meter")
		check(button.has_node("Mana") and button.get_node("Mana").value==int(hero.spellbook.mana.current),"roster mana meter")
		bounded(button,"roster hero clips")
	completed.append(13);completed.append(14)
	for button in shell._town_actions.get_children():
		var town:Dictionary={}
		for value in session.overworld.towns:
			if value.placement_id==button.get_meta("town_placement_id"):town=value
		var troops:=int(HeroCommandRules.town_defense_force(session,town).troops)
		check(button.get_node("DefenderCount").text==(str(troops) if troops>0 else "0 !"),"defender count differs from rules")
		check(button.get_meta("roster_owner")=="player","non-owned town badge")
	completed.append(15)
	var before:Dictionary=session.to_dict().duplicate(true)
	shell._end_turn_commit_in_progress=true
	shell._select_next_movable_hero()
	check(session.to_dict()==before,"next hero bypasses turn guard")
	shell._end_turn_commit_in_progress=false
	await click(shell._next_movable_hero);await settle()
	check(session.overworld.hero_position==before.overworld.hero_position,"single hero cycle moves hero")
	bounded(shell._next_movable_hero,"next hero button clips")
	await capture("owned-roster-readiness")
	# A second owned commander proves real cycling skips exhausted entries.
	var active:String=session.overworld.active_hero_id
	var other:Dictionary={}
	for template in ContentService.load_json("res://content/heroes.json").items:
		if template.id!=active:other=HeroCommandRules.build_hero_from_template(template,session.overworld.hero.position,{"stacks":[]},session);break
	other.position=session.overworld.hero.position.duplicate(true)
	other.movement.current=2
	session.overworld.player_heroes.append(other)
	HeroCommandRules.normalize_session(session)
	shell._refresh();await settle()
	shell._select_next_movable_hero();await settle()
	check(session.overworld.active_hero_id==other.id,"next movable hero does not cycle")
	session.overworld.hero.movement.current=0;session.overworld.movement.current=0
	HeroCommandRules.commit_active_hero(session)
	shell._select_next_movable_hero();await settle()
	check(session.overworld.active_hero_id==active,"next hero did not skip depleted commander")
	completed.append(16)
	check(shell._open_hero_sheet(active),"hero sheet failed to open")
	await settle()
	var sheet=shell._hero_sheet
	var xp=sheet.find_child("HeroExperienceProgress",true,false)
	check(xp!=null and xp.max_value==int(sheet.hero.next_level_experience) and xp.value==int(sheet.hero.experience),"experience progress wrong")
	completed.append(17)
	for unit in ContentService.load_json("res://content/units.json").items:
		var width:=int(ContentService.load_json("res://content/unit_battle_size_manifest.json").units[unit.id].footprint)
		var text:String=sheet._unit_description(unit,1)
		check("Occupies %d hex"%width in text,"body size description wrong: "+String(unit.id))
		check(("Ranged" if bool(unit.ranged) else "Melee") in text,"unit attack type wrong")
	completed.append(18)
	await capture("hero-experience-unit-details")
	var snapshot:Dictionary=sheet.hero.duplicate(true)
	var artifacts:Array=ContentService.load_json("res://content/artifacts.json").items
	snapshot.artifacts.inventory=[]
	for artifact in artifacts:
		if ArtifactRules.artifact_slot(artifact.id)!="" and not ArtifactRules.has_artifact(snapshot,artifact.id):snapshot.artifacts.inventory.append(artifact.id)
		if snapshot.artifacts.inventory.size()>=8:break
	sheet.open_hero(snapshot,null);sheet._tabs.current_tab=1;await settle()
	var frozen:Dictionary=sheet.hero.duplicate(true)
	await type_query(sheet._artifact_search,"no_such_artifact_123")
	check(sheet._artifact_rows.all(func(row):return not row.visible),"artifact search admits mismatch")
	check(sheet._artifact_empty.visible,"artifact empty-state message missing")
	check(sheet._artifact_empty_slots.all(func(row):return not row.visible),"empty equipment slots crowd artifact search results")
	var first:String=ArtifactRules.artifact_name(snapshot.artifacts.inventory[0])
	await search_text(sheet._artifact_search,first.to_upper())
	check(sheet._artifact_rows.any(func(row):return row.visible),"artifact search loses match")
	completed.append(19)
	var id:String=snapshot.artifacts.inventory[0]
	var expected:Dictionary=ArtifactRules.equip_artifact(snapshot.duplicate(true),id)
	check(expected.ok,"artifact comparison fixture cannot equip")
	var comparison:=Details.artifact_comparison(snapshot,id)
	check("Preview only" in comparison and ArtifactRules.artifact_decision_summary(snapshot.duplicate(true),id) in comparison,"comparison lacks actual replacement target")
	var original:Dictionary=snapshot.duplicate(true)
	for artifact_id in snapshot.artifacts.inventory:
		var simulated:Dictionary=ArtifactRules.equip_artifact(snapshot.duplicate(true),artifact_id)
		var old_stats:=ArtifactRules.aggregate_bonuses(snapshot.duplicate(true))
		var new_stats:=ArtifactRules.aggregate_bonuses(simulated.hero.duplicate(true))
		var text:=Details.artifact_comparison(snapshot,artifact_id)
		for stat in ["battle_attack","battle_defense","battle_initiative","overworld_movement","scouting_radius"]:
			var change:=float(new_stats.get(stat,0))-float(old_stats.get(stat,0))
			if not is_zero_approx(change):check(("%s: %s%s"%[String(stat).replace("battle_", "").replace("_", " ").capitalize(),"+" if change>0 else "",str(change)]) in text,"artifact delta differs from real equip rule")
	check(snapshot==original,"comparison simulation mutates source snapshot")
	check(sheet.hero==frozen,"comparison mutates hero")
	for row in sheet._artifact_rows:
		if row.visible:
			await click(row.get_child(0));break
	await settle()
	bounded(sheet._panel,"artifact comparison panel clips")
	await capture("artifact-comparison")
	await search_text(sheet._artifact_search,"")
	check(sheet._artifact_rows.all(func(row):return row.visible),"clearing artifact search hides rows")
	sheet._tabs.current_tab=3
	sheet._spellbook_view.configure(snapshot,ContentService.load_json("res://content/spells.json").items.map(func(spell):return spell.id))
	await settle()
	check(sheet._spellbook_view._grid.columns>=2,"hero spell catalog failed to respond after hidden-tab layout")
	for control in [sheet._spellbook_view._search,sheet._spellbook_view._school,sheet._spellbook_view._sort,sheet._spellbook_view._affordable]:bounded(control,"hero spell controls clip")
	await capture("hero-spell-discovery")
	completed.append(20)
	shell.queue_free();await settle()
func run() -> void:
	out=OS.get_environment("BATTLE_READABILITY_OUT")
	var parts:=OS.get_environment("TOWN_OVERLAY_RESOLUTION").split("x")
	requested=Vector2i(int(parts[0]),int(parts[1]))
	SettingsService.set_presentation_mode("windowed")
	SettingsService.set_presentation_resolution(OS.get_environment("TOWN_OVERLAY_RESOLUTION"))
	get_tree().root.size=requested;get_tree().root.content_scale_size=requested
	if DisplayServer.get_name()!="headless": DisplayServer.window_set_size(requested)
	await spells();await construction();await battle_controls();await roster_and_hero()
	check(completed.size()==20,"not all twenty improvements exercised")
	print("BATTLE_READABILITY_REPORT "+JSON.stringify({"ok":failures.is_empty(),"checks":checks,"failures":failures,"improvements":completed,"resolution":[requested.x,requested.y]}))
	get_tree().quit(0 if failures.is_empty() else 1)
'''


def main():
    if '--platform' in sys.argv:
        import packaged_menu_and_turn_readability_regression as package
        package.ui = sys.modules[__name__]
        label = sys.argv[sys.argv.index('--label') + 1]
        code = package.main()
        receipt = json.loads((runner.Path(os.environ.get('HEROES_BATTLE_READABILITY_ARTIFACT_DIR', str(OUTPUT))) / label / 'packaged-report.json').read_text())
        # A metadata-only pass must not masquerade as exported execution.
        if not receipt.get('original_probe_sha256') or receipt.get('original_probe_sha256') != receipt.get('packaged_probe_sha256'):
            print('FAIL: exact probe did not execute through the release bootstrap')
            return 1
        return code
    runner.OUTPUT = OUTPUT
    runner.SCRIPT = SCRIPT
    runner.run_probe = run_probe
    runner.probe_environment = probe_environment
    return runner.main()


if __name__ == '__main__':
    raise SystemExit(main())
