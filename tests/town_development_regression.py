"""Focused construction, reserves, town services and saved-state regression."""
import argparse
import json
from pathlib import Path
from unified_mines_regression import ROOT, run_probe


def inspect_content():
    read = lambda n: json.loads((ROOT/'content'/f'{n}.json').read_text(encoding='utf-8'))
    data = read('town_development')
    buildings = {b['id']: b for b in read('buildings')['items']}
    units = {u['id']: u for u in read('units')['items']}
    art = {a['unit_id']: a for a in read('unit_art_manifest')['items']}
    animation = {a['unit_id']: a for a in read('unit_animation_manifest')['items']}
    for town in read('towns')['items']:
        roster = data['rosters'][town['faction_id']]
        assert len(roster) == 12
        for tier in range(1, 8):
            rows = [r for r in roster if r['tier'] == tier]
            assert len(rows) == (2 if tier <= 5 else 1)
        for r in roster:
            base, veteran = units[r['unit_id']], units[r['upgraded_unit_id']]
            assert veteran['upgrade_from'] == base['id']
            assert veteran['hp'] > base['hp'] and veteran['attack'] > base['attack']
            assert veteran['id'] in art and veteran['id'] in animation
            assert buildings[r['upgrade_building_id']]['upgrade_from'] == r['building_id']
        assert all(not buildings[b].get('retired_from_town_tree') for b in town['buildable_building_ids'])
        # Either branch can independently reach tiers 6/7; no requirement on the excluded branch.
        for branch in (1, 2):
            pending = {b for b in town['buildable_building_ids'] if not buildings[b].get('choice_group') or buildings[b]['choice_branch'] == branch}
            done = set(town['starting_building_ids'])
            while pending:
                ready = {b for b in pending if set(buildings[b].get('requires', [])) <= done}
                assert ready, (town['id'], pending)
                done |= ready
                pending -= ready
    assert len(data['unit_upgrades']) == 72
    print('Content: all six faction trees, both branches, 72 upgrade/art/animation bindings pass.')


SCRIPT = r'''extends Node
const Factory = preload("res://scripts/core/ScenarioFactory.gd")
const Rules = preload("res://scripts/core/OverworldRules.gd")
const Dev = preload("res://scripts/core/TownDevelopmentRules.gd")
const Towns = preload("res://scripts/core/TownRules.gd")
const Heroes = preload("res://scripts/core/HeroCommandRules.gd")
const Enemy = preload("res://scripts/core/EnemyTurnRules.gd")
const Store = preload("res://scripts/core/SessionStateStore.gd")
const Battle = preload("res://scripts/core/BattleRules.gd")
const Shell = preload("res://scenes/town/TownShell.gd")
var checks := 0
var failures := []
func check(ok: bool, text: String):
	checks+=1
	if not ok: failures.append(text)
func fixture(tid: String):
	var s=Factory.create_session("river-pass","normal",SessionState.LAUNCH_MODE_SKIRMISH)
	# Keep this construction fixture independent of River Pass's Day-9 deadline
	# and named-town loss condition; UI orders must remain in an active match.
	s.scenario_id="town-development-fixture"
	s.scenario_status="in_progress"
	s.flags["native_random_map_runtime_scenario_record"]={"id":s.scenario_id,"objectives":{"victory":[{"type":"flag_true","flag":"fixture_finished"}],"defeat":[]}}
	s.overworld.encounters=[];s.overworld.resource_nodes=[];s.overworld.map_objects=[];s.overworld.artifact_nodes=[]
	s.overworld.towns=[{"placement_id":"development_town","town_id":tid,"x":3,"y":3,"owner":"player","built_buildings":["building_town_hall"],"available_recruits":{},"garrison":[],"last_build_day":0}]
	Rules._set_active_hero_position(s,Vector2i(3,3),0)
	for id in s.overworld.resources:s.overworld.resources[id]=999999
	Rules.invalidate_spatial_lookup(s);Rules.normalize_overworld_state(s)
	Rules.set_active_town_visit(s,"development_town")
	return s
func build(s, id: String):
	s.day+=1
	var r=Rules.build_in_active_town(s,id)
	check(bool(r.get("ok",false)),"build "+id+": "+String(r.get("message","")))
	return s.overworld.towns[0]
func service(s, id: String):
	var r=Towns.perform_response_action(s,id)
	check(bool(r.get("ok",false)),"service "+id+": "+String(r.get("message","")))
	return r
func _ready():call_deferred("run")
func run():
	for template in ContentService.load_json(ContentService.TOWNS_PATH).items:
		var s=fixture(template.id)
		var t:Dictionary=s.overworld.towns[0]
		var fid:String=template.faction_id
		var roster:Array=Dev.data().rosters[fid]
		var resource:Dictionary=ContentService.get_faction(fid).town_resources
		check(Dev.income(t)=={"gold":500},"initial hall income")
		t=build(s,"building_dev_hall_2")
		check(Dev.income(t).gold==1000 and "building_town_hall" not in t.built_buildings,"hall effects stack")
		check(not Rules.build_in_active_town(s,"building_dev_storehouse_1").get("ok",false),"same-day build allowed")
		t=build(s,"building_dev_storehouse_1")
		check(Dev.income(t).wood==1 and Dev.income(t).ore==1,"storehouse I")
		t=build(s,"building_dev_storehouse_2")
		check(Dev.income(t).wood==1 and Dev.income(t).ore==1 and Dev.income(t).get(resource.main,0)==1,"storehouse II")
		t=build(s,"building_dev_growth_1")
		check(Dev.growth(t).is_empty(),"growth support created unbuilt creatures")
		for tier in range(1,6):
			var pair:Array=roster.filter(func(r): return r.tier==tier)
			var row:Dictionary=pair[0];var excluded:Dictionary=pair[1]
			t=build(s,row.building_id)
			check(not Rules.get_town_build_status(t,excluded.building_id).buildable,"exclusive branch allowed")
			check(not Rules.get_town_build_status(t,excluded.upgrade_building_id).buildable,"excluded branch upgrade allowed")
			var count:int=t.available_recruits[row.unit_id]
			t=build(s,row.upgrade_building_id)
			check(t.available_recruits.get(row.upgraded_unit_id,0)==count and not t.available_recruits.has(row.unit_id),"upgrade duplicates or loses reserves")
			check(Dev.growth(t).has(row.upgraded_unit_id) and not Dev.growth(t).has(row.unit_id),"upgraded weekly growth duplicates base")
			check(not Rules.get_town_build_status(t,row.building_id).buildable,"downgrade/rebuild allowed")
			check(Enemy._building_growth_payload(row.upgrade_building_id).is_empty(),"AI upgrade grants extra recruits")
			check(ContentService.get_unit_animation(row.upgraded_unit_id).size()>0,"veteran animations missing")
		var first:Dictionary=roster[0]
		check(Dev.growth(t)[first.upgraded_unit_id]==ContentService.get_unit(first.unit_id).growth+4,"growth bonus missing")
		t=build(s,"building_dev_hall_3");t=build(s,"building_dev_fort_1")
		for tier in [6,7]:
			var row:Dictionary=roster.filter(func(r):return r.tier==tier)[0]
			var rare:String=resource.secondary if tier==6 else resource.main
			var b:=ContentService.get_building(row.building_id)
			check(b.cost.has(rare) and ContentService.get_unit(row.unit_id).cost.has(rare),"wrong T6/T7 cost resource")
			var reserve:int=s.overworld.resources[rare];s.overworld.resources[rare]=0;s.day+=1
			check(not Rules.build_in_active_town(s,row.building_id).get("ok",false),"building ignores rare cost")
			s.overworld.resources[rare]=reserve;t=build(s,row.building_id)
			reserve=s.overworld.resources[rare];s.overworld.resources[rare]=0
			check(not Rules.recruit_in_active_town(s,row.unit_id,1).get("ok",false),"recruit ignores rare cost")
			s.overworld.resources[rare]=reserve;t=build(s,row.upgrade_building_id)
		check(Enemy._normalized_built_buildings(t)==Dev.active_buildings(t),"AI stage interpretation differs")
		var before_growth:Dictionary=t.available_recruits.duplicate(true)
		var delta:Dictionary=Rules._growth_tick_town(s,t)
		for uid in delta:check(t.available_recruits[uid]==int(before_growth.get(uid,0))+int(delta[uid]),"weekly stock increment")
		var veteran:String=first.upgraded_unit_id
		var before_count:int=t.available_recruits[veteran]
		check(Rules.recruit_in_active_town(s,veteran,1).get("ok",false),"veteran recruitment failed")
		t=s.overworld.towns[0]
		check(t.available_recruits[veteran]==before_count-1,"veteran stock consumption")
		var troops:Array=[{"side":"player","defense":10},{"side":"enemy","defense":10}]
		Dev.apply_defender_bonus(troops,t,"town_assault")
		check(troops[0].defense==10 and troops[1].defense==12,"fortification buffs wrong side")
		for id in ["building_dev_training_attack","building_dev_training_defense","building_dev_training_experience"]:t=build(s,id)
		var attack:int=s.overworld.hero.command.attack
		service(s,"town_train:building_dev_training_attack")
		check(s.overworld.hero.command.attack==attack+1,"attack training")
		check(not Towns.perform_response_action(s,"town_train:building_dev_training_attack").ok,"repeat training")
		t=build(s,"building_dev_training_defense") if "building_dev_training_defense" not in t.built_buildings else s.overworld.towns[0]
		Rules._set_active_hero_position(s,Vector2i(10,10),0)
		check(not Dev.perform_service(s,t,"town_train:building_dev_training_defense").ok,"remote hero used training")
		Rules._set_active_hero_position(s,Vector2i(3,3),0)
		var xp:int=s.overworld.hero.experience
		service(s,"town_train:building_dev_training_experience")
		check(s.overworld.hero.experience==xp+1000 and s.overworld.hero.level>1,"training experience/level")
		t=s.overworld.towns[0];t.garrison=[{"unit_id":first.unit_id,"count":5}]
		var gold:int=s.overworld.resources.gold
		service(s,"town_upgrade:garrison:"+String(first.unit_id))
		check(s.overworld.towns[0].garrison[0].unit_id==first.upgraded_unit_id and s.overworld.towns[0].garrison[0].count==5,"garrison upgrade")
		check(s.overworld.resources.gold==gold-int(Dev.upgrade_cost(first.unit_id,first.upgraded_unit_id,5).gold),"upgrade charge")
		t=build(s,"building_market_square");var rates:Dictionary=Rules.town_market_state(t)
		t=build(s,"building_dev_trade_exchange");var improved:Dictionary=Rules.town_market_state(t)
		check(improved.buy_rates.wood<rates.buy_rates.wood and improved.sell_rates.ore>rates.sell_rates.ore,"market upgrade rates")
		t=build(s,"building_dev_artifact_exchange")
		var offers:Array=Dev.offers(t,s.day)
		check(offers.size()==3,"merchant offers missing")
		if not offers.is_empty():
			var aid:String=offers[0];gold=s.overworld.resources.gold
			service(s,"town_buy:"+aid)
			check(s.overworld.resources.gold==gold-Dev.price(ContentService.get_artifact(aid)),"buy price")
			check(not Towns.perform_response_action(s,"town_buy:"+aid).ok,"duplicate buy")
			service(s,"town_sell:"+aid)
			check(s.overworld.resources.gold==gold-Dev.price(ContentService.get_artifact(aid))/2,"sell price/no arbitrage")
			check(not Towns.perform_response_action(s,"town_sell:"+aid).ok,"duplicate sell")
		var saved=Store.SessionData.new();saved.from_dict(s.to_dict());Rules.normalize_overworld_state(saved)
		check(saved.overworld.hero.get("town_training_claims",[])==s.overworld.hero.town_training_claims,"training claims lost")
		check(saved.overworld.towns[0].built_buildings==s.overworld.towns[0].built_buildings,"stages lost on save")
		check(saved.overworld.towns[0].get("artifact_shop_purchases",{})==s.overworld.towns[0].get("artifact_shop_purchases",{}),"shop stock lost on save")
		for bid in template.buildable_building_ids:
			if "_unique_" in String(bid):
				t=build(s,String(bid))
		check(Dev.active_buildings(t).filter(func(id):return "_unique_" in String(id)).size()==3,"unique faction buildings unavailable")
		# Old upgrades and conflicting choice branches migrate deterministically, preserving stored troops.
		var mapping:Dictionary=Dev.data().migration[fid]
		var legacy:Dictionary={"town_id":template.id,"built_buildings":mapping.keys(),"available_recruits":{first.unit_id:31},"garrison":[{"unit_id":first.unit_id,"count":19}]}
		Dev.migrate_town(legacy);var once:Dictionary=legacy.duplicate(true);Dev.migrate_town(legacy)
		check(legacy==once and legacy.garrison[0].count==19,"migration not idempotent/preserving")
		var total:=0
		for n in legacy.available_recruits.values():total+=int(n)
		check(total==31 and legacy.legacy_built_buildings==mapping.keys(),"legacy reserve/history lost")
	await inspect_ui()
	print("TOWN_DEVELOPMENT_REPORT "+JSON.stringify({"checks":checks,"failures":failures}))
	get_tree().quit(0 if failures.is_empty() else 1)
func inspect_ui():
	var s=fixture("town_riverwatch")
	var t:Dictionary=s.overworld.towns[0]
	var template:Dictionary=ContentService.get_town(t.town_id)
	t.built_buildings=template.buildable_building_ids.duplicate()
	Dev.migrate_town(t)
	t.available_recruits=Dev.growth(t)
	t.garrison=[{"unit_id":"unit_river_guard","count":12}]
	s=SessionState.set_active_session(s);s.game_state="town"
	var shell=load("res://scenes/town/TownShell.tscn").instantiate()
	add_child(shell)
	for i in range(8):await get_tree().process_frame
	var out:String=OS.get_cmdline_user_args()[0]
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out+"/town.png")
	for mode in ["muster","trade","log","build"]:
		shell._open_town_catalog(mode)
		for i in range(3):await get_tree().process_frame
		check(shell._town_catalog_mode==mode,"town dialog failed "+mode)
		if mode=="muster":check(shell._response_actions.get_child_count()>0 and shell._response_actions.is_visible_in_tree(),"upgrade UI not visible")
		if mode=="muster":
			check(Towns.get_muster_catalog(s).size()==7,"Muster shows excluded or superseded creatures")
			check(shell._domain_actions.get_index()<shell._recruit_actions.get_index(),"upgrade orders below recruits")
		if mode=="trade":check(shell._response_actions.get_child_count()>0 and shell._response_actions.is_visible_in_tree(),"artifact UI not visible")
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out+"/"+mode+".png")
		# Exercise the redraw path as well as first-open population.
		shell._refresh()
		for i in range(2):await get_tree().process_frame
		if mode=="trade":
			var aid:String=Dev.offers(s.overworld.towns[0],s.day)[0]
			shell._on_response_action_pressed("town_buy:"+aid)
			for i in range(3):await get_tree().process_frame
			check(Dev.Artifacts.has_artifact(s.overworld.hero,aid),"artifact purchase button not wired")
			check(shell._town_catalog_mode=="trade","purchase closed market")
	shell.queue_free()
	await get_tree().process_frame
'''


if __name__ == '__main__':
    p=argparse.ArgumentParser()
    p.add_argument('--godot',type=Path,required=True)
    p.add_argument('--output',type=Path,required=True)
    args=p.parse_args()
    inspect_content()
    raise SystemExit(run_probe(SCRIPT,args.godot,args.output,'TOWN_DEVELOPMENT_REPORT'))
