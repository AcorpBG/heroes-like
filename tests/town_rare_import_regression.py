"""Fully tradeable rare resources (owner, 2026-10-07): Marketplace and Trade Exchange
rare buys, sales and conversions, persistent weekly limits, old import counters
and goal-directed AI banking through the same buy path."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import tempfile
from battle_readability_regression import run_probe
from town_development_regression import SCRIPT as TOWN_SCRIPT
ROOT = Path(__file__).resolve().parents[1]
MARKER = 'RARE_IMPORT_REPORT '
SCRIPT = TOWN_SCRIPT.split('func run():')[0] + r'''
const RARES := ["aetherglass","embergrain","peatwax","verdant_grafts","brass_scrip","memory_salt"]
func run():
	for template in ContentService.load_json(ContentService.TOWNS_PATH).items:
		var s=fixture(template.id);s.day=2
		var t:Dictionary=s.overworld.towns[0]
		var pair:Dictionary=ContentService.get_faction(template.faction_id).town_resources
		var main:String=pair.main;var rare:String=pair.secondary
		var offpair:String=""
		for r in RARES:
			if r not in [main,rare]:offpair=r;break
		t.built_buildings.append("building_market_square");Dev.migrate_town(t)
		# Every rare trades at the Marketplace too (owner, 2026-10-07): bought, sold, converted.
		var square:Dictionary=Rules.town_market_state(t)
		for r in RARES:
			check(r in square.rare_resources and square.buy_rates[r]>square.buy_rates.wood and square.sell_rates[r]>square.sell_rates.wood,"rare priced above wood "+r+" "+template.id)
			check(square.buy_caps[r]==2 and square.sell_caps[r]==3,"Marketplace rare limits "+r+" "+template.id)
			check(not Rules._market_quote_from_state(square,"buy",r,1).is_empty() and not Rules._market_quote_from_state(square,"sell",r,1).is_empty(),"Marketplace quotes "+r+" "+template.id)
		check(Rules._market_quote_from_state(square,"buy",rare,2).gold_value==2*int(square.buy_rates[rare]),"no rare bulk discount "+template.id)
		for r in [main,rare,offpair]:s.overworld.resources[r]=0
		var before:int=s.overworld.resources.gold
		check(Towns.perform_market_action(s,"market:buy:"+rare+":2").ok,"paid rare purchase "+template.id)
		t=s.overworld.towns[0]
		check(s.overworld.resources.gold==before-2*int(square.buy_rates[rare]) and s.overworld.resources[rare]==2,"exact paid transaction "+template.id)
		check(not Towns.perform_market_action(s,"market:buy:"+rare+":1").ok,"third Marketplace purchase blocked "+template.id)
		check(Towns.perform_market_action(s,"market:buy:"+offpair+":1").ok,"off-pair rare purchase "+template.id)
		before=s.overworld.resources.gold
		check(Towns.perform_market_action(s,"market:sell:"+rare+":2").ok,"rare sale "+template.id)
		check(s.overworld.resources.gold==before+2*int(square.sell_rates[rare]) and s.overworld.resources[rare]==0,"exact rare sale "+template.id)
		var wood:int=s.overworld.resources.wood
		var to_wood:Dictionary=Towns.market_trade_quote(square,Rules._normalize_town_market_usage_state(s.overworld.towns[0].market_usage,s.day),s.overworld.resources,offpair,"wood",1)
		check(to_wood.ok and Towns.perform_market_action(s,to_wood.action_id).ok and s.overworld.resources.wood==wood+1 and s.overworld.resources[offpair]==1-int(to_wood.give_amount),"rare converts into wood "+template.id)
		var snapshot:Dictionary=s.to_dict()
		var loaded=Store.SessionData.new();loaded.from_dict(JSON.parse_string(JSON.stringify(snapshot)));Rules.normalize_overworld_state(loaded)
		var restored:Dictionary=loaded.overworld.towns[0]
		check(restored.market_usage.buy[rare]==2 and restored.market_usage.sell[rare]==2,"weekly rare usage survives full save normalize "+template.id)
		# Town ownership/hero identity must not define the consumed allowance.
		restored.owner="enemy";restored.controlling_faction_id="other_owner"
		var captured:Array=Rules._normalize_towns([restored],s.day);restored=captured[0]
		restored.owner="player";restored.controlling_faction_id=""
		check(Rules._market_cap_state_for_quote(restored,square,Rules._market_quote_from_state(square,"buy",rare,1),s.day).remaining==0,"capture preserves town allowance "+template.id)
		# The Trade Exchange raises the limits and improves every rate; this week's usage still counts.
		t=s.overworld.towns[0]
		t.built_buildings.append("building_dev_trade_exchange");Dev.migrate_town(t)
		var state:Dictionary=Rules.town_market_state(t)
		for r in RARES:
			check(state.buy_caps[r]==5 and state.sell_caps[r]==5 and state.buy_rates[r]<square.buy_rates[r] and state.sell_rates[r]>square.sell_rates[r],"Trade Exchange rare terms "+r+" "+template.id)
		s.overworld.hero.id="different_hero"
		check(Towns.perform_market_action(s,"market:buy:"+rare+":3").ok,"second hero spends remaining town allowance "+template.id)
		check(not Towns.perform_market_action(s,"market:buy:"+rare+":1").ok,"sixth purchase blocked "+template.id)
		t=s.overworld.towns[0]
		t.built_buildings.erase("building_dev_trade_exchange");Dev.migrate_town(t)
		t.built_buildings.append("building_dev_trade_exchange");Dev.migrate_town(t)
		check(not Towns.perform_market_action(s,"market:buy:"+rare+":1").ok,"rebuilt exchange does not refill allowance "+template.id)
		check(Towns.perform_market_action(s,"market:buy:"+main+":1").ok,"independent main allowance "+template.id)
		t=s.overworld.towns[0]
		check(not Rules.can_afford_cost_with_town_market(t,s.overworld.resources,{rare:6},s.day),"auto coverage respects exhausted allowance "+template.id)
		var lines:String=Rules.describe_town_market(s,t)
		check("Rare resources buy" in lines and "reset Day 8" in lines,"visible rare rates and reset "+template.id)
		var action:Dictionary=Rules.get_town_market_actions(s,t).filter(func(x):return x.id=="market:buy:"+rare+":1")[0]
		check(action.disabled and action.cap_remaining==0,"disabled rare purchase button "+template.id)
		s.day=8;before=s.overworld.resources.gold
		check(Towns.perform_market_action(s,"market:buy:"+rare+":1").ok,"new week allows purchase "+template.id)
		check(s.overworld.resources.gold==before-int(state.buy_rates[rare]),"weekly reset grants no free resources "+template.id)
		# A shared cost transaction pays exact rare purchases and consumes the same allowance.
		t=s.overworld.towns[0];var pool:Dictionary={"gold":10000,rare:0}
		var cost:Dictionary={"gold":3000,rare:4}
		check(Rules.can_afford_cost_with_town_market(t,pool,cost,s.day),"shared affordable rare path "+template.id)
		var exchanges:Array=Rules.apply_market_cost_coverage(t,pool,cost,s.day)
		check(exchanges.size()==4 and pool.gold==10000-4*int(state.buy_rates[rare]) and pool[rare]==4,"shared costs charge rare purchases "+template.id)
		check(t.market_usage.buy[rare]==5,"shared costs consume allowance "+template.id)
		var exhausted:Dictionary=pool.duplicate(true)
		check(Rules.apply_market_cost_coverage(t,pool,{rare:5},s.day).is_empty() and pool==exhausted,"failed coverage is atomic "+template.id)
		check(not Rules.can_afford_cost_with_town_market(t,pool,{rare:5}),"dateless caller cannot bypass rare cap "+template.id)
		check(not Rules.can_afford_cost_with_town_market(t,{"gold":0,main:100},{"gold":1200},s.day),"automatic coverage keeps rare stock "+template.id)
		# Old saves: no market_usage starts unused; an old import count already in the buy bucket still counts.
		var legacy:Dictionary=t.duplicate(true);legacy.erase("market_usage")
		legacy=Rules._normalize_towns([legacy],s.day)[0]
		check(Rules._market_cap_state_for_quote(legacy,state,Rules._market_quote_from_state(state,"buy",rare,1),s.day).remaining==5,"legacy save allowance migration "+template.id)
		var counted:Dictionary=t.duplicate(true);counted.market_usage={"week":2,"buy":{"wood":0,"ore":0,rare:3},"sell":{"wood":0,"ore":0}}
		counted=Rules._normalize_towns([counted],s.day)[0]
		check(Rules._market_cap_state_for_quote(counted,state,Rules._market_quote_from_state(state,"buy",rare,1),s.day).remaining==2,"saved import counter counts against the rare limit "+template.id)
	validate_ai_banking()
	validate_actual_unlock()
	print("RARE_IMPORT_REPORT "+JSON.stringify({"checks":checks,"failures":failures,"ok":failures.is_empty()}))
	get_tree().quit(0 if failures.is_empty() else 1)
func advanced_town(s):
	var t:Dictionary=s.overworld.towns[0]
	t.built_buildings.append_array(["building_dev_hall_3","building_dev_fort_1","building_market_square","building_dev_trade_exchange"])
	# A late-game fixture with earned prerequisites; chosen orders remain legal.
	for row in Dev.data().rosters["faction_veilmourn"]:
		if row.tier<=6 and row.branch==1:t.built_buildings.append(row.building_id)
	Dev.migrate_town(t)
	return t
func validate_ai_banking():
	var s=fixture("town_veilmourn_bellwake_harbor");s.day=40
	var t:Dictionary=advanced_town(s)
	var salt:int=int(Rules.town_market_state(t).buy_rates.memory_salt)
	var cost:Dictionary=ContentService.get_building("building_dev_veilmourn_t7_1").cost
	var pool:Dictionary={"gold":50000,"wood":100,"ore":100,"memory_salt":0,"verdant_grafts":100}
	var original:Dictionary=pool.duplicate(true)
	check(not Rules.bank_town_rare_imports(t,pool,cost,s.day).is_empty(),"AI banks first legal five-unit shipment")
	check(pool.memory_salt==5 and pool.gold==50000-5*salt,"AI pays first shipment")
	check(Rules.bank_town_rare_imports(t,pool,cost,s.day).is_empty(),"AI cannot repeat exhausted shipment")
	s.day=43
	check(not Rules.bank_town_rare_imports(t,pool,cost,s.day).is_empty(),"AI banks second week")
	check(pool.memory_salt==10 and pool.gold==50000-10*salt,"AI reaches exactly target")
	check(Rules.bank_town_rare_imports(t,pool,cost,s.day+7).is_empty(),"AI never buys beyond target")
	var boundary:int=int(cost.gold)+10*salt+2000
	var poor:Dictionary=original.duplicate(true);poor.gold=boundary-1
	var clean:Dictionary=t.duplicate(true);clean.erase("market_usage")
	check(Rules.bank_town_rare_imports(clean,poor,cost,s.day).is_empty() and poor.memory_salt==0,"AI reserves full project plus entire rare bill plus 2000")
	poor.gold=boundary
	check(not Rules.bank_town_rare_imports(clean,poor,cost,s.day).is_empty() and poor.gold==boundary-5*salt,"AI exact funding boundary")
	# Execute governor construction with a genuine legal T7 candidate.
	t.owner="enemy";t.controlling_faction_id="faction_veilmourn";t.erase("market_usage")
	var cfg:Dictionary={"faction_id":"faction_veilmourn","label":"Veil test"}
	var choice:Dictionary=Enemy._enemy_rare_import_target(s,t,original,"faction_veilmourn",cfg)
	check(not choice.is_empty(),"AI governor selects legal rare dwelling")
	if not choice.is_empty():
		check(Rules.get_town_build_status(t,choice.id).buildable,"AI rare target prerequisites satisfied")
		var goal_pool:Dictionary=original.duplicate(true)
		goal_pool.verdant_grafts=100
		var result:Dictionary=Enemy._build_in_enemy_towns(s,[{"index":0}],s.overworld.towns,goal_pool,"faction_veilmourn",cfg)
		check(goal_pool.memory_salt==5,"actual governor banks T7 rather than softlocking")
		s.day+=7
		Enemy._build_in_enemy_towns(s,[{"index":0}],s.overworld.towns,goal_pool,"faction_veilmourn",cfg)
		check(Dev.satisfies(t.built_buildings,"building_dev_veilmourn_t7_1"),"actual governor builds T7 after second shipment")
func validate_actual_unlock():
	var s=fixture("town_veilmourn_bellwake_harbor");s.day=50
	var t:Dictionary=advanced_town(s)
	t.built_buildings.erase("building_dev_veilmourn_t6_1");Dev.migrate_town(t)
	s.overworld.resources.verdant_grafts=0;s.overworld.resources.gold=50000
	var grafts:int=int(Rules.town_market_state(t).buy_rates.verdant_grafts)
	var before:int=s.overworld.resources.gold
	var result:Dictionary=Rules.build_in_active_town(s,"building_dev_veilmourn_t6_1")
	check(not result.ok and s.overworld.resources.gold==before,"base unlock still requires actual paid exchange first")
	t=s.overworld.towns[0]
	check(Rules.town_cost_readiness(t,s.overworld.resources,ContentService.get_building("building_dev_veilmourn_t6_1").cost,s.day).market_affordable,"real T6 readiness offers paid exchange path")
	check(Towns.perform_market_action(s,"market:buy:verdant_grafts:5").ok,"real T6 paid rare purchase")
	result=Rules.build_in_active_town(s,"building_dev_veilmourn_t6_1")
	check(result.ok,"real base T6 unlock after paid exchange: "+str(result))
	var t6_gold:int=int(ContentService.get_building("building_dev_veilmourn_t6_1").cost.gold)
	check(s.overworld.resources.gold==before-t6_gold-5*grafts and s.overworld.resources.verdant_grafts==0,"real T6 includes construction plus rare purchase")
	t=s.overworld.towns[0]
	check(t.get("market_usage",{}).get("buy",{}).get("verdant_grafts",0)==5,"real T6 consumes5 allowance")
	s.day=57;before=s.overworld.resources.gold
	check(Towns.perform_market_action(s,"market:buy:verdant_grafts:4").ok,"real upgrade paid rare purchase")
	check(Rules.build_in_active_town(s,"building_dev_veilmourn_t6_1_upgrade").ok,"real T6 upgrade buys next week")
	var up_gold:int=int(ContentService.get_building("building_dev_veilmourn_t6_1_upgrade").cost.gold)
	check(s.overworld.resources.gold==before-up_gold-4*grafts,"real upgrade includes construction plus rare purchase")
	var uid:String="unit_veilmourn_mirrorkeel_reavers_veteran"
	before=s.overworld.resources.gold
	check(Towns.perform_market_action(s,"market:buy:verdant_grafts:1").ok,"real recruit paid rare purchase")
	check(Rules.recruit_in_active_town(s,uid,1).ok,"real upgraded T6 recruit buys the fifth weekly rare")
	check(s.overworld.resources.gold==before-grafts-int(ContentService.get_unit(uid).cost.gold),"real recruit pays the rare price and unchanged unit cost")
'''

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='rare-import-', dir=output) as directory:
        work = Path(directory)
        (work / 'probe.gd').write_text(SCRIPT, encoding='utf-8')
        scene = work / 'probe.tscn'
        scene.write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="probe.gd" id="1"]\n[node name="RareImportProbe" type="Node"]\nscript=ExtResource("1")\n', encoding='utf-8')
        env = dict(os.environ, APPDATA=str(work / 'profile'), XDG_DATA_HOME=str(work / 'profile'))
        command = [args.godot, '--headless', '--path', str(ROOT), '--audio-driver', 'Dummy', '--log-file', str(output / 'engine.log'), 'res://' + scene.relative_to(ROOT).as_posix()]
        with (output / 'console.log').open('w', encoding='utf-8') as log:
            # The shared Unix process-group runner imports resource, unavailable
            # on Windows. Headless Godot has no child wrapper on this platform.
            if os.name == 'nt':
                code = subprocess.run(command, env=env, stdout=log, stderr=subprocess.STDOUT,
                                      timeout=90, creationflags=subprocess.CREATE_NO_WINDOW).returncode
            else:
                code = run_probe(command, env, log, 90)
        text = (output / 'console.log').read_text(encoding='utf-8')
        print('\n'.join(line for line in text.splitlines() if line.startswith(MARKER) or 'ERROR' in line))
        reports = [json.loads(line[len(MARKER):]) for line in text.splitlines() if line.startswith(MARKER)]
        errors = [line for line in text.splitlines() if 'ERROR' in line and line != 'ERROR: Failed to read the root certificate store.']
        return code or int(bool(errors) or not reports or not reports[-1]['ok'])


if __name__ == '__main__':
    raise SystemExit(main())
