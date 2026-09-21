"""Focused live AI town services, ownership, budgets and saved commander state."""
import argparse
from pathlib import Path
from unified_mines_regression import run_probe
from town_development_regression import SCRIPT as TOWN_SCRIPT

SCRIPT = TOWN_SCRIPT.split('func run():')[0] + r'''
const Adventure = preload("res://scripts/core/EnemyAdventureRules.gd")
const Services = preload("res://scripts/core/EnemyTownServices.gd")
func run():
	for template in ContentService.load_json(ContentService.TOWNS_PATH).items:
		var s=fixture(template.id)
		var t:Dictionary=s.overworld.towns[0]
		var fid:String=template.faction_id
		var row:Dictionary=Dev.data().rosters[fid][0]
		t.owner="enemy";t.controlling_faction_id=fid
		t.built_buildings=["building_town_hall",row.upgrade_building_id,"building_dev_training_attack","building_dev_training_defense","building_dev_training_experience","building_dev_artifact_exchange"]
		t.garrison=[{"unit_id":row.unit_id,"count":8}]
		var hid:String=""
		for h in ContentService.load_json("res://content/heroes.json").items:
			if h.faction_id==fid:hid=h.id;break
		var commander:Dictionary=Adventure.build_roster_commander_state(hid,fid)
		var original:Dictionary=commander.duplicate(true)
		var raid:Dictionary={"placement_id":"service_visitor","encounter_id":"","spawned_by_faction_id":fid,"x":3,"y":3,"enemy_commander_state":commander,"enemy_army":{"stacks":[{"unit_id":row.unit_id,"count":10}]}}
		s.overworld.encounters=[raid]
		var treasury:Dictionary=s.overworld.resources.duplicate(true)
		treasury.gold=100000
		var state:Dictionary={"faction_id":fid,"treasury":treasury,"commander_roster":[{"roster_hero_id":hid,"commander_state":commander,"status":"active","active_placement_id":"service_visitor"}]}
		s.overworld.enemy_states=[state]
		var player_before:Dictionary=s.overworld.hero.duplicate(true)
		var resources_before:Dictionary=s.overworld.resources.duplicate(true)
		var result:Dictionary=Enemy._use_enemy_town_services(s,{"faction_id":fid},state,treasury,fid)
		commander=raid.enemy_commander_state
		check(result.messages.size()>=2,"garrison and visitor orders missing "+fid)
		check(commander.get("town_training_claims",[]).size()==3,"training claims "+fid)
		check(int(commander.command.attack)>=int(original.command.attack)+1,"attack training "+fid)
		check(int(commander.command.defense)>=int(original.command.defense)+1,"defense training "+fid)
		check(int(commander.experience)>=1000,"experience training "+fid)
		check(raid.enemy_army.stacks[0].unit_id==row.upgraded_unit_id and raid.enemy_army.stacks[0].count==10,"visitor paid upgrade "+fid)
		check(t.garrison[0].unit_id==row.upgraded_unit_id and t.garrison[0].count==8,"garrison paid upgrade "+fid)
		check(Services.loadout_value(commander)>Services.loadout_value(original),"useful artifact purchased/equipped "+fid)
		check(treasury.gold>=Services.GOLD_RESERVE and treasury.gold<100000,"treasury spend and reserve "+fid)
		check(s.overworld.hero==player_before and s.overworld.resources==resources_before,"AI touched player state "+fid)
		var repeat:Dictionary=commander.duplicate(true)
		var gold:int=treasury.gold
		Enemy._use_enemy_town_services(s,{"faction_id":fid},result.state,treasury,fid)
		check(raid.enemy_commander_state.command==repeat.command and raid.enemy_commander_state.experience==repeat.experience and treasury.gold==gold,"repeat visit gave rewards or repeated trade "+fid)
		# Exercise the real commander roster reconstruction after a JSON save roundtrip.
		s.overworld=JSON.parse_string(JSON.stringify(s.overworld))
		Adventure.normalize_all_commander_rosters(s)
		var loaded:Dictionary=Adventure.commander_roster_for_faction(s,fid)[0].commander_state
		for entry in Adventure.commander_roster_for_faction(s,fid):
			if entry.roster_hero_id==hid:loaded=entry.commander_state
		check(loaded.get("town_training_claims",[]).size()==3 and loaded.get("last_town_trade_day",-1)==s.day,"save/normalization lost claims "+fid)
		check(loaded.army_continuity.stacks[0].unit_id==row.upgraded_unit_id,"roster lost upgraded army "+fid)
		check(loaded.artifacts==repeat.artifacts,"roster lost equipment "+fid)
		# Services are spatial and controller-scoped, including same-faction rivals.
		var wrong:Dictionary=raid.duplicate(true);wrong.x=30
		check(not Services.can_visit(t,wrong,fid),"remote visit "+fid)
		wrong=raid.duplicate(true);wrong.level=1
		check(not Services.can_visit(t,wrong,fid),"cross-level visit "+fid)
		wrong=raid.duplicate(true);wrong.spawned_by_player_id="other-controller"
		check(not Services.can_visit(t,wrong,fid),"same-faction rival visit "+fid)
		var neutral:Dictionary=t.duplicate(true);neutral.owner="neutral"
		check(not Services.can_visit(neutral,raid,fid),"neutral services "+fid)
		var poor:Dictionary={"gold":Services.GOLD_RESERVE}
		var failed:Dictionary=Services.upgrade_stacks(t,[{"unit_id":row.unit_id,"count":8}],poor)
		check(failed.upgrades.is_empty() and poor.gold==Services.GOLD_RESERVE,"reserve spent "+fid)
		var locked:Dictionary=t.duplicate(true);locked.built_buildings=["building_town_hall"]
		var cash:Dictionary={"gold":100000}
		failed=Services.upgrade_stacks(locked,[{"unit_id":row.unit_id,"count":8}],cash)
		check(failed.upgrades.is_empty() and cash.gold==100000,"missing dwelling upgrade accepted "+fid)
		# Route-arrival hook operates even without garrison reserve or a resupply need.
		s.overworld.encounters[0].enemy_commander_state=original.duplicate(true)
		s.overworld.encounters[0].enemy_army={"stacks":[{"unit_id":row.unit_id,"count":3}]}
		s.overworld.towns[0].garrison=[]
		var arrival:Dictionary=Adventure.use_town_services_for_raid(s,{"faction_id":fid},s.overworld.encounters[0],fid)
		check(not arrival.messages.is_empty() and s.overworld.encounters[0].enemy_commander_state.town_training_claims.size()==3,"arrival service hook "+fid)
		# The public economy entry point must retain services through all normalizers.
		s.overworld.players=[]
		s.overworld.encounters[0].enemy_commander_state=original.duplicate(true)
		s.overworld.towns[0].last_build_day=s.day
		var economy:Dictionary=Enemy.run_enemy_town_economy_turn(s,fid)
		check(economy.ok and s.overworld.encounters[0].enemy_commander_state.town_training_claims.size()==3,"public economy turn "+fid)
		if template.id=="town_riverwatch":
			s.overworld.encounters[0].enemy_commander_state=original.duplicate(true)
			var turn:Dictionary=Enemy.run_enemy_turn(s)
			var retained:=false
			for entry in Adventure.commander_roster_for_faction(s,fid):
				if entry.roster_hero_id==hid:retained=entry.commander_state.get("town_training_claims",[]).size()==3
			check(turn.ok and retained,"full enemy turn overwrote service state")
			s.overworld.encounters=[]
			var defended:Dictionary=s.overworld.towns[0]
			defended.ai_defender_commander_state=original.duplicate(true)
			defended.ai_defender_roster_hero_id=hid
			defended.ai_defended_by_faction_id=fid
			defended.ai_defense_until_day=99
			defended.front={"state":"defend","faction_id":fid,"defense_until_day":99,"last_change_day":s.day}
			var defender_entry:Dictionary=Adventure._active_town_defender_entry(s,defended,fid)
			check(not defender_entry.is_empty(),"stationed defender fixture")
			state=s.overworld.enemy_states[0]
			Enemy._use_enemy_town_services(s,{"faction_id":fid},state,state.treasury,fid)
			check(defended.ai_defender_commander_state.get("town_training_claims",[]).size()==3,"stationed town defender did not train")
	inspect_artifact_policy()
	print("TOWN_AI_SERVICES_REPORT "+JSON.stringify({"checks":checks,"failures":failures}))
	get_tree().quit(0 if failures.is_empty() else 1)
func inspect_artifact_policy():
	var s=fixture("town_riverwatch")
	var t:Dictionary=s.overworld.towns[0]
	t.owner="enemy";t.controlling_faction_id="faction_embercourt";t.built_buildings.append("building_dev_artifact_exchange")
	var fid:String=t.controlling_faction_id
	var hero:Dictionary={"id":"test","command":{},"artifacts":{"equipped":{"trinket":"artifact_quarry_tally_rod","trinket_2":"artifact_choir_tuning_fork"},"inventory":["artifact_pressure_gauge_reliquary"]}}
	var equipment:Dictionary=Services.best_equipment(hero,"artifact_pressure_gauge_reliquary")
	check(equipment.gain>0 and equipment.hero.artifacts.equipped.trinket=="artifact_pressure_gauge_reliquary","equipment swap did not improve weak slot")
	check(equipment.hero.artifacts.equipped.trinket_2=="artifact_choir_tuning_fork","equipment discarded stronger second trinket")
	var second:Dictionary=hero.duplicate(true)
	second.artifacts.equipped={"trinket":"artifact_choir_tuning_fork","trinket_2":"artifact_quarry_tally_rod"}
	equipment=Services.best_equipment(second,"artifact_pressure_gauge_reliquary")
	check(equipment.hero.artifacts.equipped.trinket=="artifact_choir_tuning_fork" and equipment.hero.artifacts.equipped.trinket_2=="artifact_pressure_gauge_reliquary","second-slot replacement broken")
	var raid:Dictionary={"spawned_by_faction_id":fid,"x":3,"y":3,"enemy_commander_state":equipment.hero,"enemy_army":{"stacks":[]}}
	# Leave only sale funds: no purchase can obscure the exact resale amount.
	var cash:Dictionary={"gold":0}
	var before:Dictionary=raid.enemy_commander_state.artifacts.equipped.duplicate(true)
	Services.visit(t,raid,cash,1,fid)
	check(cash.gold==Dev.price(ContentService.get_artifact("artifact_quarry_tally_rod"))/2,"surplus resale price")
	check(raid.enemy_commander_state.artifacts.equipped==before,"sale removed equipped artifact")
	check(not Dev.Artifacts.has_artifact(raid.enemy_commander_state,"artifact_quarry_tally_rod"),"sold artifact remained owned")
	check(not Dev.trade_artifact(raid.enemy_commander_state,t,1,"artifact_choir_tuning_fork",false,cash).ok,"shared commerce sold equipped item")
	var income_state:Dictionary={"commander_roster":[{"status":"active","commander_state":hero}],"captured_artifact_ids":["artifact_quarry_tally_rod"]}
	check(Enemy._captured_artifact_income(income_state).gold==120,"equipped purchased income missing or captured income counted twice")
	income_state.commander_roster[0].commander_state=equipment.hero
	check(Enemy._captured_artifact_income(income_state).gold==0,"unequipped captured item still pays income")
	# Selling through the live adapter clears the legacy empire-income binding.
	var hid:String=ContentService.get_faction(fid).hero_ids[0]
	raid.enemy_commander_state=Adventure.build_roster_commander_state(hid,fid,equipment.hero)
	raid.enemy_commander_state.erase("last_town_trade_day")
	raid.placement_id="sale_visitor";raid.encounter_id=""
	s.overworld.encounters=[raid]
	s.overworld.enemy_states=[{"faction_id":fid,"treasury":{"gold":0},"captured_artifact_ids":["artifact_quarry_tally_rod"],"commander_roster":[{"roster_hero_id":hid,"status":"active","active_placement_id":"sale_visitor","commander_state":raid.enemy_commander_state}]}]
	Adventure.use_town_services_for_raid(s,{"faction_id":fid},raid,fid)
	check("artifact_quarry_tally_rod" not in s.overworld.enemy_states[0].captured_artifact_ids,"sold captured item kept empire ownership")
	check(Enemy._captured_artifact_income(s.overworld.enemy_states[0]).gold==0,"sold item still pays empire income")
'''

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--godot', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    raise SystemExit(run_probe(SCRIPT, args.godot, args.output, 'TOWN_AI_SERVICES_REPORT'))
