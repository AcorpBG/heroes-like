"""Focused faction services and actual town battle effects, without the full suite."""
import argparse
from pathlib import Path
from unified_mines_regression import run_probe
from town_development_regression import SCRIPT as TOWN_SCRIPT

SCRIPT = TOWN_SCRIPT.split('func run():')[0] + r'''
const FactionServices = preload("res://scripts/core/FactionTownServices.gd")
const TownBattle = preload("res://scripts/core/TownBattleRules.gd")
const AIService = preload("res://scripts/core/EnemyTownServices.gd")
const Adventure = preload("res://scripts/core/EnemyAdventureRules.gd")
const Spells = preload("res://scripts/core/SpellRules.gd")
func run():
	for template in ContentService.load_json(ContentService.TOWNS_PATH).items:
		var s=fixture(template.id)
		s.day=4
		var t:Dictionary=s.overworld.towns[0]
		var service_building:Dictionary={}
		var defense_building:Dictionary={}
		for id in template.buildable_building_ids:
			var b:Dictionary=ContentService.get_building(String(id))
			if "_unique_" in String(id):t.built_buildings.append(id)
			if b.has("faction_service"):service_building=b
			if b.has("town_defense_effect"):defense_building=b
		for row in Dev.data().rosters[template.faction_id]:
			if row.tier<=3 and row.branch==1:t.built_buildings.append(row.upgrade_building_id)
		Dev.migrate_town(t)
		check(not service_building.is_empty() and not defense_building.is_empty(),"distinct faction content "+template.id)
		if service_building.is_empty() or defense_building.is_empty():continue
		s.overworld.hero=Spells.ensure_hero_spellbook(s.overworld.hero)
		s.overworld.hero.spellbook.mana.current=0
		var b:Dictionary=service_building
		var spec:Dictionary=b.faction_service
		var action:String="town_faction:"+String(b.id)
		var before:Dictionary=s.overworld.resources.duplicate(true)
		var xp:int=s.overworld.hero.experience
		var recruit_before:Dictionary=t.available_recruits.duplicate(true)
		var recruits:Dictionary=FactionServices.recruit_reward(t,spec)
		check(Dev.service_actions(s,t).any(func(a):return a.id==action and not a.disabled),"missing available faction action "+template.id)
		var result:Dictionary=Towns.perform_response_action(s,action)
		check(result.ok,"faction service failed "+template.id)
		t=s.overworld.towns[0]
		for key in before:
			check(s.overworld.resources[key]==int(before[key])-int(spec.get("cost",{}).get(key,0))+int(spec.get("reward",{}).get(key,0)),"service transaction "+template.id+"/"+key)
		if spec.kind=="experience":check(s.overworld.hero.experience==xp+int(spec.experience),"memory lesson XP")
		if spec.kind=="restore_mana":check(s.overworld.hero.spellbook.mana.current==s.overworld.hero.spellbook.mana.max,"calibration mana")
		if spec.kind=="recruits":
			check(recruits.size()==(1 if template.faction_id=="faction_mireclaw" else 3),"levy/bloom selected tiers")
			for uid in recruits:
				check(t.available_recruits[uid]==int(recruit_before.get(uid,0))+int(recruits[uid]),"extra reserve "+uid)
		var after:Dictionary=s.overworld.resources.duplicate(true)
		check(not Towns.perform_response_action(s,action).ok and s.overworld.resources==after,"weekly service repeated "+template.id)
		var loaded=Store.SessionData.new();loaded.from_dict(s.to_dict());Rules.normalize_overworld_state(loaded)
		check(not Towns.perform_response_action(loaded,action).ok,"save lost weekly service claim "+template.id)
		check(loaded.overworld.towns[0].get("town_service_claims",{})==t.get("town_service_claims",{}),"town claim not saved "+template.id)
		check(loaded.overworld.hero.get("town_service_claims",{})==s.overworld.hero.get("town_service_claims",{}),"hero claim not saved "+template.id)
		s.day=8;s.overworld.hero.spellbook.mana.current=0
		check(Towns.perform_response_action(s,action).ok,"weekly reset "+template.id)
		var other_hero:Dictionary=s.overworld.hero.duplicate(true)
		other_hero.town_service_claims={};other_hero.spellbook.mana.current=0
		var other_reason:String=FactionServices.unavailable_reason(other_hero,s.overworld.towns[0],b,8,s.overworld.resources)
		check((other_reason=="")== (spec.scope=="hero"),"per-hero versus per-town weekly scope "+template.id)
		Rules._set_active_hero_position(s,Vector2i(9,9),0);s.day=15
		check(not Towns.perform_response_action(s,action).ok,"remote faction service "+template.id)
		t=s.overworld.towns[0];t.owner="enemy";t.controlling_faction_id=template.faction_id
		var hero:Dictionary=Adventure.build_roster_commander_state(String(ContentService.get_faction(template.faction_id).hero_ids[0]),template.faction_id)
		hero.spellbook.mana.current=0
		var visitor:Dictionary={"spawned_by_faction_id":template.faction_id,"x":3,"y":3,"enemy_commander_state":hero,"enemy_army":{"stacks":[]}}
		var cash:Dictionary=before.duplicate(true);cash.gold=5000;cash.wood=100;cash.ore=100;cash.embergrain=0
		t.available_recruits={}
		check(FactionServices.useful_to_ai(hero,t,b,15,cash),"AI does not value useful service "+template.id)
		AIService.visit(t,visitor,cash,15,template.faction_id)
		var holder:Dictionary=visitor.enemy_commander_state if spec.scope=="hero" else t
		check(holder.get("town_service_claims",{}).get(b.id,-1)==2,"AI service not used "+template.id)
		var rebuilt:Dictionary=Adventure.build_roster_commander_state(hero.roster_hero_id,template.faction_id,visitor.enemy_commander_state)
		check(rebuilt.get("town_service_claims",{})==visitor.enemy_commander_state.get("town_service_claims",{}),"AI weekly claims lost "+template.id)
		check(not FactionServices.useful_to_ai(rebuilt,t,b,15,cash),"AI repeats weekly service "+template.id)
		inspect_battle(s,t,defense_building)
	await inspect_services_ui()
	print("TOWN_FACTION_REPORT "+JSON.stringify({"checks":checks,"failures":failures}))
	get_tree().quit(0 if failures.is_empty() else 1)
func inspect_battle(s,t:Dictionary,building:Dictionary):
	t.garrison=[{"unit_id":"unit_river_guard","count":20},{"unit_id":"unit_ember_archer","count":10}]
	var b:Dictionary=Battle.create_town_assault_payload(s,String(t.placement_id))
	check(not b.is_empty() and b.get("town_defenses",{}).get("side","")=="enemy","town defense not in real battle "+building.id)
	if b.is_empty():return
	var defender:Dictionary=b.stacks.filter(func(x):return x.side=="enemy")[0]
	var attacker:Dictionary=b.stacks.filter(func(x):return x.side=="player")[0]
	var bare:Dictionary=b.duplicate(true);bare.erase("town_defenses")
	var kind:String=building.town_defense_effect.id
	check(TownBattle.summary(b,defender)!="" or TownBattle.summary(b,attacker)!="","missing battle explanation "+kind)
	match kind:
		"beacon_volley":
			var baseline:float=Battle._damage_modifier(defender,attacker,bare,true)
			check(is_equal_approx(Battle._damage_modifier(defender,attacker,b,true),baseline*1.25),"beacon opening volley")
			b.round=2;bare.round=2
			check(is_equal_approx(Battle._damage_modifier(defender,attacker,b,true),Battle._damage_modifier(defender,attacker,bare,true)),"beacon volley did not expire")
		"chainboom":
			check(Battle._stack_movement_points(attacker,b)==maxi(1,Battle._stack_movement_points(attacker,bare)-1),"chainboom movement cost")
			check(Battle._stack_movement_points(defender,b)==Battle._stack_movement_points(defender,bare),"chainboom slowed defender")
			b.round=3;check(Battle._stack_movement_points(attacker,b)==Battle._stack_movement_points(attacker,bare),"chainboom did not expire")
		"prism_ward":
			var spell:Dictionary={"school_id":"mire"}
			var baseline:int=Spells.spell_damage_resistance_pct(bare,defender,spell)
			check(Spells.spell_damage_resistance_pct(b,defender,spell)==mini(Spells.MAX_SPELL_RESISTANCE_PCT,baseline+30),"prism spell resistance")
			b.round=3;check(Spells.spell_damage_resistance_pct(b,defender,spell)==baseline,"prism ward did not expire")
		"root_ward":
			defender.total_health=10*int(defender.unit_hp)-5
			var health:int=defender.total_health
			Battle._prepare_round(b,2)
			defender=Battle._get_stack_by_id(b,defender.battle_id)
			check(defender.total_health>health and Battle._alive_count(defender)==10,"root healing or no-resurrection cap")
			health=defender.total_health;Battle._prepare_round(b,2)
			check(Battle._get_stack_by_id(b,defender.battle_id).total_health==health,"root ward replays same-round healing")
			Battle._get_stack_by_id(b,defender.battle_id).total_health=0;Battle._prepare_round(b,3)
			check(Battle._get_stack_by_id(b,defender.battle_id).total_health==0,"root ward resurrected dead stack")
		"pressure_shield":
			var shield:int=defender.town_shield_hp
			var health:int=defender.total_health
			check(shield==int(ceil(float(health)*0.15)),"pressure shield starting amount")
			check(Battle._unit_loss_range(defender,shield,shield).max_units==0,"shield casualty preview")
			Battle._apply_damage_to_stack(b,defender.battle_id,shield-1)
			check(defender.total_health==health and defender.town_shield_hp==1,"shield did not absorb damage")
			Battle._apply_damage_to_stack(b,defender.battle_id,6)
			check(defender.total_health==health-5 and defender.town_shield_hp==0,"shield overflow damage")
			s.battle=JSON.parse_string(JSON.stringify(b));Battle.normalize_battle_state(s)
			check(Battle._get_stack_by_id(s.battle,defender.battle_id).town_shield_hp==0,"save refilled shield")
		"bellwake_fog":
			var baseline:float=Battle._damage_modifier(attacker,defender,bare,true)
			check(is_equal_approx(Battle._damage_modifier(attacker,defender,b,true),baseline*0.65),"bellwake ranged protection")
			check(is_equal_approx(Battle._damage_modifier(attacker,defender,b,false),Battle._damage_modifier(attacker,defender,bare,false)),"bellwake changed melee damage")
			b.round=3;bare.round=3
			check(is_equal_approx(Battle._damage_modifier(attacker,defender,b,true),Battle._damage_modifier(attacker,defender,bare,true)),"bellwake fog did not expire")
	# Exercise the opposite battle orientation through the real payload builder.
	s.overworld.towns[0].owner="player"
	var defense:Dictionary=Battle.create_battle_payload(s,{"placement_id":"defense_probe","encounter_id":"encounter_town_assault","enemy_army":{"stacks":[{"unit_id":"unit_river_guard","count":10}]},"battle_context":{"type":"town_defense","town_placement_id":t.placement_id}})
	check(defense.get("town_defenses",{}).get("side","")=="player","player-owned defense side "+kind)
func inspect_services_ui():
	var s=fixture("town_riverwatch")
	s.overworld.towns[0].built_buildings.append("building_dev_embercourt_unique_1")
	s=SessionState.set_active_session(s);s.game_state="town"
	var shell=load("res://scenes/town/TownShell.tscn").instantiate();add_child(shell)
	for i in range(8):await get_tree().process_frame
	shell._open_town_catalog("log")
	for i in range(3):await get_tree().process_frame
	var found:=false
	for button in shell._response_actions.get_children():
		if button is Button and button.text.begins_with("Commission a supply convoy"):
			found=button.is_visible_in_tree() and not button.disabled and "3 wood" in button.text and "3 ore" in button.text
	check(found,"faction service action not visible in actual town UI")
	check(shell._response_actions.get_index()<shell._army_management.get_index(),"services hidden below formation panel")
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0]+"/faction-services.png")
	var gold:int=s.overworld.resources.gold
	shell._on_response_action_pressed("town_faction:building_dev_embercourt_unique_1")
	for i in range(3):await get_tree().process_frame
	check(s.overworld.resources.gold==gold+1200,"faction UI callback did not execute")
	shell.queue_free();await get_tree().process_frame
'''

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--godot', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    raise SystemExit(run_probe(SCRIPT, args.godot, args.output, 'TOWN_FACTION_REPORT'))
