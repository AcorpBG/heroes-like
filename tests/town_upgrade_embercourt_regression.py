"""Headless actual-combat regression for twelve Embercourt dwelling upgrades."""
import argparse
from pathlib import Path
from unittest.mock import patch
import unified_mines_regression as runner

SCRIPT = r'''extends Node
const Factory=preload("res://scripts/core/ScenarioFactory.gd")
const B=preload("res://scripts/core/BattleRules.gd")
const S=preload("res://scripts/core/SpellRules.gd")
var checks:=0
var failures:=[]
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label)
func _ready():call_deferred("run")
func stack(uid:String,side:String,index:int,q:int,r:int)->Dictionary:
	var x:Dictionary=B._build_battle_stack(uid,100,side,index)
	# Equal numeric strength isolates authored tactical behavior from upgrade stats.
	x.unit_hp=100;x.total_health=10000;x.base_count=100;x.attack=5;x.defense=5
	x.min_damage=5;x.max_damage=5;x.hex={"q":q,"r":r};x.effects=[]
	x.battle_footprint=1;x.shots_remaining=20
	return x
func fixture(aid:String,did:String,gap:int=1):
	var s=Factory.create_session("river-pass","normal",SessionState.LAUNCH_MODE_SKIRMISH)
	s.battle=B.create_battle_payload(s,s.overworld.encounters[0])
	var a=stack(aid,"enemy",0,3,3);var d=stack(did,"player",0,3+gap,3)
	var spare=stack("unit_river_guard","player",6,10,6);spare.abilities=[]
	s.battle.stacks=[a,d,spare];s.battle.round=1;s.battle.battlefield_tags=[]
	s.battle[B.FIELD_OBJECTIVES_KEY]=[];s.battle.player_hero={};s.battle.enemy_hero={}
	s.game_state="battle"
	B._sync_occupied_hexes(s.battle);B._sync_distance_from_hexes(s.battle)
	return s
func hit(s,a:Dictionary,d:Dictionary,ranged:bool)->Dictionary:
	s.battle.turn_order=[a.battle_id,s.battle.stacks[2].battle_id,d.battle_id]
	s.battle.turn_index=0;s.battle.active_stack_id=a.battle_id;s.battle.selected_target_id=d.battle_id
	B._sync_occupied_hexes(s.battle);B._sync_distance_from_hexes(s.battle)
	return B._resolve_ai_attack(s,a,d,ranged)
func current(s,x:Dictionary)->Dictionary:return B._get_stack_by_id(s.battle,x.battle_id)
func effect(s,x:Dictionary,id:String)->bool:return S.has_effect_id(current(s,x),s.battle,id)
func bonus(s,x:Dictionary,kind:String)->int:return S.effect_bonus_for_kind(current(s,x),s.battle,kind)
func add_support(s,uid:String,side:String,q:int=1,r:int=6)->Dictionary:
	var x=stack(uid,side,4,q,r);s.battle.stacks.append(x);return x
func unit_id(stem:String,up:bool)->String:return stem+("_veteran" if up else "")
func passive_damage(stem:String,up:bool,ranged:bool,support:bool=false,target_ranged:bool=true)->Array:
	var defender=unit_id(stem,up) if not support else ("unit_ember_archer" if target_ranged else "unit_river_guard")
	var s=fixture("unit_ember_archer" if ranged else "unit_river_guard",defender,3 if ranged else 1)
	var a:Dictionary=s.battle.stacks[0];var d:Dictionary=s.battle.stacks[1]
	a.abilities=[]
	if support:
		d.abilities=[];add_support(s,unit_id(stem,up),"player")
	var ah:int=a.total_health;var dh:int=d.total_health
	check(hit(s,a,d,ranged).get("ok",false),stem+" damage action")
	return [dh-int(current(s,d).total_health),ah-int(current(s,a).total_health)]
func run():
	# 1. Missile protection is tactical, not generic damage reduction.
	var old=passive_damage("unit_river_guard",false,true)
	var new=passive_damage("unit_river_guard",true,true)
	check(new[0]<old[0],"sentinel does not screen ranged damage")
	old=passive_damage("unit_river_guard",false,false);new=passive_damage("unit_river_guard",true,false)
	check(new[0]==old[0],"sentinel missile shield affects melee")
	# 2. One pull with a repeatable half-open reach, even without an objective.
	for up in [false,true]:
		var s=fixture(unit_id("unit_embercourt_fordhook_cadets",up),"unit_ember_archer",2)
		var a:Dictionary=s.battle.stacks[0];var d:Dictionary=s.battle.stacks[1];d.abilities=[]
		var result=hit(s,a,d,false)
		check(bool(result.get("ok",false))==up,"chainford no-objective reach "+str(up))
		if up:
			check(effect(s,d,"status_rooted") and B._stack_hex_distance(current(s,a),current(s,d))==1,"chainford pull/root")
			d=current(s,d);d.hex={"q":5,"r":3};d.effects=[]
			check(hit(s,current(s,a),d,false).ok,"chainford repeat reach")
			check(not effect(s,d,"status_rooted") and B._stack_hex_distance(current(s,a),current(s,d))==2,"chainford repeats spent pull")
	# 3. Harried arrows now soften the target's counterattack.
	for up in [false,true]:
		var s=fixture(unit_id("unit_ember_archer",up),"unit_river_guard",3)
		var a:Dictionary=s.battle.stacks[0];var d:Dictionary=s.battle.stacks[1]
		check(hit(s,a,d,true).ok,"cinderwake shot")
		check(bonus(s,d,"retaliation")==(-10 if up else 0),"cinderwake retaliation suppression "+str(up))
	# 4. Sapper flare is a once-only offensive answer to shooters.
	for target in ["unit_river_guard","unit_ember_archer"]:
		var s=fixture("unit_embercourt_lantern_sappers_veteran",target)
		var a:Dictionary=s.battle.stacks[0];var d:Dictionary=s.battle.stacks[1];d.abilities=[]
		check(hit(s,a,d,false).ok,"flarepot strike")
		check(effect(s,d,"status_staggered")==bool(d.ranged),"flarepot target-role trigger")
		if d.ranged:
			current(s,d).effects=[]
			check(hit(s,current(s,a),current(s,d),false).ok and not effect(s,d,"status_staggered"),"flarepot repeats spent flare")
	# 5. Defending phalanx answers two attacks, then exhausts retaliation.
	for up in [false,true]:
		var s=fixture("unit_river_guard",unit_id("unit_citadel_pikeward",up))
		var a:Dictionary=s.battle.stacks[0];var d:Dictionary=s.battle.stacks[1];a.abilities=[];d.defending=true
		for n in range(3):
			a=current(s,a);a.effects=[]
			var before:int=a.total_health
			check(hit(s,a,current(s,d),false).ok,"gateward incoming strike")
			check((int(current(s,a).total_health)<before)==(n<(2 if up else 1)),"gateward retaliation budget "+str([up,n]))
			check(effect(s,a,"status_staggered")==bool(up and n<2),"gateward defensive stagger "+str([up,n]))
	# 6. Barge suppression requires a separate ally adjacent to its target.
	for supported in [false,true]:
		var s=fixture("unit_embercourt_bargebow_crews_veteran","unit_river_guard",3)
		var a:Dictionary=s.battle.stacks[0];var d:Dictionary=s.battle.stacks[1]
		if supported:
			var ally=add_support(s,"unit_river_guard","enemy",6,4);ally.abilities=[]
		check(hit(s,a,d,true).ok,"winchbow shot")
		check(effect(s,d,"status_staggered")==supported,"winchbow adjacent support trigger")
		if supported:
			current(s,d).effects=[]
			check(hit(s,current(s,a),current(s,d),true).ok and not effect(s,d,"status_staggered"),"winchbow repeats spent suppression")
	# 7. A proactive warrant applies before the counterattack, not only on brace.
	for up in [false,true]:
		var s=fixture(unit_id("unit_embercourt_ash_oath_bailiffs",up),"unit_river_guard")
		var a:Dictionary=s.battle.stacks[0];var d:Dictionary=s.battle.stacks[1];d.abilities=[]
		check(hit(s,a,d,false).ok,"ashseal strike")
		check(bonus(s,d,"retaliation")==(-10 if up else 0),"ashseal offensive citation "+str(up))
		if up:
			current(s,d).effects=[]
			check(hit(s,current(s,a),current(s,d),false).ok and bonus(s,d,"retaliation")==0,"ashseal repeats spent warrant")
	# 8. The injunction punishes a brace-equipped target, even before it defends.
	for up in [false,true]:
		for braced in [false,true]:
			var s=fixture(unit_id("unit_embercourt_lockglass_writcasters",up),"unit_embercourt_ash_oath_bailiffs" if braced else "unit_embercourt_lockglass_writcasters",3)
			var a:Dictionary=s.battle.stacks[0];var d:Dictionary=s.battle.stacks[1];d.defending=false
			check(hit(s,a,d,true).ok,"prismwrit shot")
			check(bonus(s,d,"retaliation")==((-20 if braced else -10) if up else 0),"prismwrit brace payoff "+str([up,braced]))
	# 9. Lector intercept protects low-tier shooters from actual hook rooting.
	for up in [false,true]:
		var s=fixture("unit_embercourt_fordhook_cadets_veteran","unit_ember_archer",2)
		var a:Dictionary=s.battle.stacks[0];var d:Dictionary=s.battle.stacks[1];d.abilities=[]
		var lector=add_support(s,unit_id("unit_embercourt_beacon_lectors",up),"player")
		check(hit(s,a,d,false).ok,"dawnwrit incoming hook")
		check(effect(s,d,"status_rooted")==not up,"dawnwrit low-tier ranged root protection "+str(up))
		if up:check(int(current(s,lector).ability_uses.get("readiness_writ",0))==1,"dawnwrit response not spent")
	# 10. Wardens protect engaged shooters, not every melee body.
	old=passive_damage("unit_embercourt_beaconline_writguard",false,false,true,true)
	new=passive_damage("unit_embercourt_beaconline_writguard",true,false,true,true)
	check(new[0]<old[0],"lanternwall allied shooter screen")
	old=passive_damage("unit_embercourt_beaconline_writguard",false,false,true,false)
	new=passive_damage("unit_embercourt_beaconline_writguard",true,false,true,false)
	check(new[0]==old[0],"lanternwall screen affects unshielded melee")
	# 11. Long-neck reach opens a previously illegal gap attack.
	for up in [false,true]:
		var s=fixture(unit_id("unit_embercourt_sluicefire_lindworms",up),"unit_river_guard",2)
		var a:Dictionary=s.battle.stacks[0];var d:Dictionary=s.battle.stacks[1]
		d.effects=[S.build_battle_effect("status_harried","Prepared",{"initiative":-1},2,s.battle,"fixture","fixture")]
		var before:int=d.total_health;var result=hit(s,a,d,false)
		check(bool(result.get("ok",false))==up,"floodpyre half-open attack "+str(up))
		check((int(current(s,d).total_health)<before)==up,"floodpyre prepared gap damage "+str(up))
	# 12. Marching covenant now helps low-tier advancing melee retaliation.
	old=passive_damage("unit_embercourt_charter_colossus",false,false,true,false)
	new=passive_damage("unit_embercourt_charter_colossus",true,false,true,false)
	check(new[1]>old[1],"covenant low-tier undefended retaliation")
	old=passive_damage("unit_embercourt_charter_colossus",false,false,true,true)
	new=passive_damage("unit_embercourt_charter_colossus",true,false,true,true)
	check(new[1]==old[1],"covenant aura affects ranged retaliation")
	print("EMBER_UPGRADE_REPORT "+JSON.stringify({"checks":checks,"failures":failures}))
	get_tree().quit(0 if failures.is_empty() else 1)
'''

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot',required=True)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args()
    original=runner.subprocess.run
    def headless(command,**kwargs):
        command=list(command)
        # Reuse the isolated-profile runner, with no graphics server needed.
        if command[:2]==['xvfb-run','-a']: command=command[2:]
        command.insert(1,'--headless')
        return original(command,**kwargs)
    with patch.object(runner.subprocess,'run',headless):
        return runner.run_probe(SCRIPT,args.godot,args.output,'EMBER_UPGRADE_REPORT')

if __name__=='__main__':raise SystemExit(main())
