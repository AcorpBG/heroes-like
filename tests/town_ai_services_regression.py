"""Focused live AI town services, ownership, budgets and saved commander state."""
import argparse
from pathlib import Path
from unified_mines_regression import run_probe
from town_development_regression import SCRIPT as TOWN_SCRIPT

SCRIPT = TOWN_SCRIPT.split('func run():')[0] + r'''
const Adventure = preload("res://scripts/core/EnemyAdventureRules.gd")
const Services = preload("res://scripts/core/EnemyTownServices.gd")
const AiHeroes = preload("res://scripts/core/AiHeroRules.gd")
const Levels = preload("res://scripts/core/OverworldLevelRules.gd")
# A computer player's hero visiting its own town uses the town's services the
# way AiHeroRules does it on the map (_visit_own_town_if_inside).
func visit_with_hero(s, fid: String, state: Dictionary) -> Dictionary:
	var context: Dictionary = AiHeroes._new_context(s, {"faction_id": fid}, state)
	return AiHeroes._visit_own_town_if_inside(s, context, 0)
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
		var entrance:Dictionary=Levels.town_entrance(t)
		var hero:Dictionary={"placement_id":"service_visitor","encounter_id":AiHeroes.AI_HERO_ENCOUNTER_ID,"spawned_by_faction_id":fid,"x":int(entrance.x),"y":int(entrance.y),"enemy_commander_state":commander,"enemy_army":{"stacks":[{"unit_id":row.unit_id,"count":10}]},AiHeroes.AI_HERO_KEY:{"hero_id":hid,"movement":{"current":10,"max":10},"goal":{}}}
		s.overworld.encounters=[hero]
		Rules.invalidate_spatial_lookup(s)
		var treasury:Dictionary=s.overworld.resources.duplicate(true)
		treasury.gold=100000
		var state:Dictionary={"faction_id":fid,"treasury":treasury,"commander_roster":[{"roster_hero_id":hid,"commander_state":commander,"status":"active","active_placement_id":"service_visitor"}]}
		s.overworld.enemy_states=[state]
		# The human's hero shares this small fixture; without an army it does not
		# make the town count as threatened, so the main hero takes the garrison.
		for index in range(s.overworld.player_heroes.size()):
			s.overworld.player_heroes[index].army={"stacks":[]}
		var player_before:Dictionary=s.overworld.hero.duplicate(true)
		var resources_before:Dictionary=s.overworld.resources.duplicate(true)
		visit_with_hero(s,fid,state)
		hero=s.overworld.encounters[0]
		commander=hero.enemy_commander_state
		check(commander.get("town_training_claims",[]).size()==3,"training claims "+fid)
		check(int(commander.command.attack)>=int(original.command.attack)+1,"attack training "+fid)
		check(int(commander.command.defense)>=int(original.command.defense)+1,"defense training "+fid)
		check(int(commander.experience)>=1000,"experience training "+fid)
		# The main hero takes the garrison along, and the town upgrades all of it.
		check(hero.enemy_army.stacks.size()==1 and hero.enemy_army.stacks[0].unit_id==row.upgraded_unit_id and hero.enemy_army.stacks[0].count==18,"hero and garrison troops paid upgrade "+fid)
		check(t.garrison.is_empty(),"main hero left the garrison behind "+fid)
		check(Services.loadout_value(commander)>Services.loadout_value(original),"useful artifact purchased/equipped "+fid)
		check(treasury.gold>=Services.GOLD_RESERVE and treasury.gold<100000,"treasury spend and reserve "+fid)
		check(s.overworld.hero==player_before and s.overworld.resources==resources_before,"AI touched player state "+fid)
		var repeat:Dictionary=commander.duplicate(true)
		var gold:int=treasury.gold
		visit_with_hero(s,fid,state)
		check(s.overworld.encounters[0].enemy_commander_state.command==repeat.command and s.overworld.encounters[0].enemy_commander_state.experience==repeat.experience and treasury.gold==gold,"repeat visit gave rewards or repeated trade "+fid)
		# Services are spatial and controller-scoped, including same-faction rivals.
		var wrong:Dictionary=hero.duplicate(true);wrong.x=30
		check(not Services.can_visit(t,wrong,fid),"remote visit "+fid)
		wrong=hero.duplicate(true);wrong.level=1
		check(not Services.can_visit(t,wrong,fid),"cross-level visit "+fid)
		wrong=hero.duplicate(true);wrong.spawned_by_player_id="other-controller"
		check(not Services.can_visit(t,wrong,fid),"same-faction rival visit "+fid)
		var neutral:Dictionary=t.duplicate(true);neutral.owner="neutral"
		check(not Services.can_visit(neutral,hero,fid),"neutral services "+fid)
		var poor:Dictionary={"gold":Services.GOLD_RESERVE}
		var failed:Dictionary=Services.upgrade_stacks(t,[{"unit_id":row.unit_id,"count":8}],poor)
		check(failed.upgrades.is_empty() and poor.gold==Services.GOLD_RESERVE,"reserve spent "+fid)
		var locked:Dictionary=t.duplicate(true);locked.built_buildings=["building_town_hall"]
		var cash:Dictionary={"gold":100000}
		failed=Services.upgrade_stacks(locked,[{"unit_id":row.unit_id,"count":8}],cash)
		check(failed.upgrades.is_empty() and cash.gold==100000,"missing dwelling upgrade accepted "+fid)
		if template.id=="town_riverwatch":
			# A full enemy turn keeps what the visit gave the hero.
			s.day+=1
			var turn:Dictionary=Enemy.run_enemy_turn(s)
			var retained:=false
			for entry in AiHeroes.active_hero_entries(s,fid):
				if String(entry.placement_id)=="service_visitor":retained=entry.enemy_commander_state.get("town_training_claims",[]).size()==3
			check(turn.ok and retained,"full enemy turn overwrote service state")
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
'''

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--godot', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    raise SystemExit(run_probe(SCRIPT, args.godot, args.output, 'TOWN_AI_SERVICES_REPORT'))
