"""Twelve Thornwake upgrade mechanics through live BattleRules combat fixtures."""
import argparse
import subprocess
from pathlib import Path
from unittest.mock import patch

from unified_mines_regression import run_probe

SCRIPT = r'''extends Node
const Battle=preload("res://scripts/core/BattleRules.gd")
const Factory=preload("res://scripts/core/ScenarioFactory.gd")
const Spells=preload("res://scripts/core/SpellRules.gd")
var checks:=0
var failures:=[]
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label)
func close(actual:float,expected:float,label:String):
	check(is_equal_approx(actual,expected),label+" actual="+str(actual)+" expected="+str(expected))
func _ready():call_deferred("run")
func fixture(short_id:String,upgraded:bool=true,count:int=10):
	var s=Factory.create_session("river-pass","normal",SessionState.LAUNCH_MODE_SKIRMISH)
	s.battle=Battle.create_battle_payload(s,s.overworld.encounters[0])
	var uid:String="unit_thornwake_"+short_id+("_veteran" if upgraded else "")
	var actor:Dictionary=Battle._build_battle_stack(uid,count,"player",0)
	var foe:Dictionary=Battle._build_battle_stack("unit_river_guard",100,"enemy",0)
	var ally:Dictionary=Battle._build_battle_stack("unit_thornwake_worldroot_bastion",3,"player",1)
	actor.hex={"q":2,"r":3};foe.hex={"q":6,"r":3};ally.hex={"q":2,"r":6}
	foe.abilities=[];foe.control_resistance_pct=0;foe.spell_resistance_pct=0;foe.status_immunity_ids=[]
	foe.total_health=100000;foe.unit_hp=1000;foe.base_count=100;foe.attack=0;foe.defense=0
	ally.control_resistance_pct=0;ally.spell_resistance_pct=0;ally.status_immunity_ids=[]
	s.battle.stacks=[actor,foe,ally];s.battle.round=2;s.battle.terrain="grass";s.battle.battlefield_tags=[]
	s.battle[Battle.FIELD_OBJECTIVES_KEY]=[];s.battle.erase("town_defenses")
	s.battle.turn_order=[actor.battle_id,foe.battle_id,ally.battle_id];s.battle.turn_index=0
	s.battle.active_stack_id=actor.battle_id;s.battle.selected_target_id=foe.battle_id
	Battle._sync_occupied_hexes(s.battle);Battle._sync_distance_from_hexes(s.battle)
	s.game_state="battle"
	return s
func actor(s)->Dictionary:return s.battle.stacks[0]
func foe(s)->Dictionary:return s.battle.stacks[1]
func ally(s)->Dictionary:return s.battle.stacks[2]
func effect(s,target:Dictionary,id:String,modifiers:Dictionary={}):
	target.effects=[Spells.build_battle_effect(id,id,modifiers,2,s.battle,"ability","test")]
func mod(s,ranged:bool=false,retaliation:bool=false,distance:int=0)->float:
	return Battle._ability_damage_modifier(actor(s),foe(s),s.battle,ranged,retaliation,distance)
func wound_cases():
	var s=fixture("seedcutters")
	close(mod(s),1.0,"Reapers healthy target")
	foe(s).total_health=50000
	close(mod(s),1.1,"Reapers half-health harvest")
	close(mod(s,false,true),1.0,"Reapers no harvest on retaliation")
	close(mod(s,true),1.0,"Reapers no harvest on ranged branch")
	var base=fixture("seedcutters",false);foe(base).total_health=50000
	close(mod(base),1.0,"Seedcutter base lacks harvest")
	var clean:Dictionary=actor(s).duplicate(true);clean.abilities=[]
	check(Battle._damage_for_roll(actor(s),foe(s),s.battle,3,false)>Battle._damage_for_roll(clean,foe(s),s.battle,3,false),"Reaper harvest changes resolved damage")
func volley_case(id:String,status:String,bonus:float):
	var s=fixture(id)
	close(mod(s,true,false,3),1.0,id+" clean shot")
	effect(s,foe(s),status)
	close(mod(s,true,false,3),bonus,id+" prepared shot")
	close(mod(s,false),1.0,id+" no ranged payoff in melee")
	var base=fixture(id,false);effect(base,foe(base),status)
	close(mod(base,true,false,3),1.0,id+" base lacks payoff")
	var clean:Dictionary=actor(s).duplicate(true);clean.abilities=[]
	check(Battle._damage_for_roll(actor(s),foe(s),s.battle,4,true)>Battle._damage_for_roll(clean,foe(s),s.battle,4,true),id+" changes resolved damage")
func lash_cases():
	var s=fixture("thornwhip_carriers");foe(s).hex={"q":4,"r":3}
	check(Battle._can_make_melee_attack(actor(s),s.battle,foe(s)),"Lashkeeper reaches across one step")
	close(mod(s,false,false,1),.7,"Lashkeeper reach force")
	var base=fixture("thornwhip_carriers",false);foe(base).hex={"q":4,"r":3}
	check(not Battle._can_make_melee_attack(actor(base),base.battle,foe(base)),"Base cannot reach")
	foe(s).hex={"q":5,"r":3}
	check(not Battle._can_make_melee_attack(actor(s),s.battle,foe(s)),"Lashkeeper cannot reach three hexes")
	actor(s).defending=true
	Battle._apply_retaliation_ability_effects(s.battle,actor(s),foe(s))
	check(Spells.has_effect_id(foe(s),s.battle,"status_rooted"),"Lashkeeper retains rooting retaliation")
func mender_cases():
	var s=fixture("sporeglass_menders")
	effect(s,ally(s),"status_rooted",{"initiative":-2})
	Battle._apply_attack_ability_effects(s.battle,actor(s),foe(s),true,3)
	check(not Spells.has_effect_id(ally(s),s.battle,"status_rooted"),"Dewglass ranged action cleanses root")
	effect(s,ally(s),"status_rooted",{"initiative":-2})
	Battle._apply_attack_ability_effects(s.battle,actor(s),foe(s),true,3)
	check(Spells.has_effect_id(ally(s),s.battle,"status_rooted"),"Dewglass cleanse only once")
	var base=fixture("sporeglass_menders",false);effect(base,ally(base),"status_rooted")
	Battle._apply_attack_ability_effects(base.battle,actor(base),foe(base),true,3)
	check(Spells.has_effect_id(ally(base),base.battle,"status_rooted"),"Base mender does not cleanse")
	var fresh=fixture("sporeglass_menders")
	var root:Dictionary=Spells.build_battle_effect("status_rooted","Root",{"initiative":-2},2,fresh.battle,"ability","test")
	Battle._apply_stack_effect(fresh.battle,ally(fresh).battle_id,root)
	check(not Spells.has_effect_id(ally(fresh),fresh.battle,"status_rooted"),"Dewglass intercepts incoming ally root")
	Battle._apply_stack_effect(fresh.battle,ally(fresh).battle_id,root)
	check(Spells.has_effect_id(ally(fresh),fresh.battle,"status_rooted"),"Dewglass interception consumes charge")
	var unrelated=fixture("sporeglass_menders")
	Battle._apply_stack_effect(unrelated.battle,ally(unrelated).battle_id,Spells.build_battle_effect("status_staggered","Stagger",{"initiative":-2},2,unrelated.battle,"ability","test"))
	check(Spells.has_effect_id(ally(unrelated),unrelated.battle,"status_staggered"),"Dewglass does not cleanse other control")
	var heal=fixture("sporeglass_menders");ally(heal).total_health=72
	check(Battle._resolve_attack_action(heal,actor(heal),foe(heal),true).ok,"Dewglass committed ranged attack")
	check(ally(heal).total_health==80 and Battle._alive_count(ally(heal))==1,"Dewglass keeps capped 8HP healing without resurrection")
func warden_cases():
	var s=fixture("seedshield_wardens");ally(s).defending=true
	close(Battle._ability_damage_modifier(ally(s),foe(s),s.battle,false,true,0),1.08,"Heartseed boosts defending allied retaliation")
	ally(s).defending=false
	close(Battle._ability_damage_modifier(ally(s),foe(s),s.battle,false,true,0),1.0,"Heartseed requires allied defend")
	ally(s).defending=true
	close(Battle._ability_damage_modifier(ally(s),foe(s),s.battle,false,false,0),1.0,"Heartseed does not boost primary attacks")
	actor(s).total_health=0
	close(Battle._ability_damage_modifier(ally(s),foe(s),s.battle,false,true,0),1.0,"Dead Heartseed supplies no aura")
	var base=fixture("seedshield_wardens",false);ally(base).defending=true
	close(Battle._ability_damage_modifier(ally(base),foe(base),base.battle,false,true,0),1.0,"Base wardens lack aura")
func rampart_cases():
	for upgraded in [true,false]:
		for ranged in [true,false]:
			var s=fixture("barkmantle_rams",upgraded)
			var before:Dictionary=actor(s).duplicate(true)
			Battle._apply_damage_to_stack(s.battle,actor(s).battle_id,50)
			Battle._apply_ranged_damage_return(s.battle,foe(s).battle_id,before,ranged,"attack")
			check(foe(s).total_health==100000-(4 if upgraded and ranged else 0),"Corkheart damage return "+str([upgraded,ranged]))
	var dead=fixture("barkmantle_rams");var before:Dictionary=actor(dead).duplicate(true)
	Battle._apply_damage_to_stack(dead.battle,actor(dead).battle_id,100000)
	Battle._apply_ranged_damage_return(dead.battle,foe(dead).battle_id,before,true,"attack")
	check(foe(dead).total_health==100000,"Dead Corkheart does not reflect")
func bolter_cases():
	var s=fixture("dawnseed_bolters")
	close(mod(s,true,false,3),1.0,"Dawnburst unprotected lane")
	ally(s).defending=true;ally(s).hex={"q":2,"r":4}
	close(mod(s,true,false,3),1.14*1.02,"Dawnburst adjacent guard")
	effect(s,foe(s),"status_rooted")
	close(mod(s,true,false,3),1.14*1.02*1.04,"Dawnburst guarded root payoff")
	ally(s).hex={"q":2,"r":6}
	close(mod(s,true,false,3),1.0,"Distant defender cannot enable lane")
	ally(s).defending=false;foe(s).effects=[]
	s.battle[Battle.FIELD_OBJECTIVES_KEY]=[{"type":"cover_line","control_side":"player"}]
	close(mod(s,true,false,3),1.14,"Controlled cover enables Dawnburst")
	s.battle[Battle.FIELD_OBJECTIVES_KEY][0].control_side="enemy"
	close(mod(s,true,false,3),1.0,"Enemy cover cannot enable Dawnburst")
func strider_cases():
	var s=fixture("stagknot_runners");effect(s,foe(s),"status_rooted")
	close(mod(s),1.12,"Antlerloom rooted primary")
	close(mod(s,false,false,1),.95*1.12,"Antlerloom reach combines root payoff")
	close(mod(s,false,true),1.0,"Antlerloom retaliation no payoff")
	close(mod(s,true),1.0,"Antlerloom ranged branch no payoff")
	foe(s).effects=[];close(mod(s),1.0,"Antlerloom clean enemy")
	var base=fixture("stagknot_runners",false);effect(base,foe(base),"status_rooted")
	close(mod(base),1.0,"Base runner lacks rooted payoff")
func cantor_cases():
	var s=fixture("seedglass_cantors")
	var ranged:Dictionary=Battle._build_battle_stack("unit_thornwake_pollenhook_whistlers",10,"player",3)
	ranged.hex={"q":5,"r":5};s.battle.stacks.append(ranged)
	close(Battle._ability_damage_modifier(foe(s),ranged,s.battle,false,false,0),.95,"Blossomchoir contact screen for ranged ally")
	close(Battle._ability_damage_modifier(foe(s),ranged,s.battle,false,false,1),1.0,"Blossomchoir does not screen reach")
	close(Battle._ability_damage_modifier(foe(s),ranged,s.battle,true,false,3),1.0,"Blossomchoir does not screen missiles")
	close(Battle._ability_damage_modifier(foe(s),ally(s),s.battle,false,false,0),.95,"Blossomchoir screens shield-bearing ally")
	ally(s).abilities=[]
	close(Battle._ability_damage_modifier(foe(s),ally(s),s.battle,false,false,0),1.0,"Blossomchoir does not screen unshielded melee")
	actor(s).total_health=0
	close(Battle._ability_damage_modifier(foe(s),ranged,s.battle,false,false,0),1.0,"Dead cantor loses screen")
func matriarch_cases():
	for upgraded in [true,false]:
		var s=fixture("graft_matriarchs",upgraded,4);ally(s).total_health=72
		var shots:int=actor(s).shots_remaining
		check(Battle._resolve_attack_action(s,actor(s),foe(s),true).ok,"Matriarch committed shot "+str(upgraded))
		check(ally(s).total_health==(84 if upgraded else 72),"Matriarch actual healing cap/base distinction "+str(upgraded))
		check(actor(s).shots_remaining==shots-1,"Matriarch shot spent "+str(upgraded))
		check(Battle._alive_count(ally(s))==1,"Matriarch cannot resurrect")
	var melee=fixture("graft_matriarchs");ally(melee).total_health=72
	Battle._apply_attack_ability_effects(melee.battle,actor(melee),foe(melee),false,0)
	check(ally(melee).total_health==72,"Matriarch melee cannot mend")
	var small=fixture("graft_matriarchs",true,1);ally(small).total_health=72
	Battle._apply_attack_ability_effects(small.battle,actor(small),foe(small),true,3)
	check(ally(small).total_health==76,"One Matriarch heals four")
func colossus_cases():
	for upgraded in [true,false]:
		for defending in [true,false]:
			var s=fixture("worldroot_bastion",upgraded);actor(s).defending=defending
			foe(s).hex={"q":3,"r":3};foe(s).min_damage=1;foe(s).max_damage=1
			check(Battle._resolve_attack_action(s,foe(s),actor(s),false).ok,"Enemy hits colossus "+str([upgraded,defending]))
			check(Spells.has_effect_id(foe(s),s.battle,"status_rooted")==bool(upgraded and defending),"Rootlock committed retaliation trigger "+str([upgraded,defending]))
			check(actor(s).retaliations_left==0,"Retaliation consumed "+str([upgraded,defending]))
			if upgraded and defending:
				# A committed action can also trigger the defender commander's spell.
				# Isolate Rootlock's contribution from those independent active effects.
				var unrooted:Dictionary=foe(s).duplicate(true)
				unrooted.effects=unrooted.effects.filter(func(e):return e.effect_id!="status_rooted")
				close(Spells.effect_bonus_for_kind(foe(s),s.battle,"initiative")-Spells.effect_bonus_for_kind(unrooted,s.battle,"initiative"),-1,"Rootlock initiative penalty applied")
func run():
	wound_cases()
	volley_case("pollenhook_whistlers","status_rooted",1.1)
	volley_case("bramblekite_needlers","status_harried",1.08)
	lash_cases();mender_cases();warden_cases();rampart_cases();bolter_cases();strider_cases();cantor_cases();matriarch_cases();colossus_cases()
	print("THORNWAKE_UPGRADE_REPORT "+JSON.stringify({"checks":checks,"failures":failures,"upgrades":12}))
	get_tree().quit(0 if failures.is_empty() else 1)
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    # Reuse the repository's isolated-profile run_probe, without a display server.
    actual_run = subprocess.run
    def headless(command, **kwargs):
        if command[:2] == ['xvfb-run', '-a']:
            command = command[2:]
        return actual_run([command[0], '--headless', *command[1:]], **kwargs)
    with patch('unified_mines_regression.subprocess.run', side_effect=headless):
        return run_probe(SCRIPT, args.godot, args.output, 'THORNWAKE_UPGRADE_REPORT')


if __name__ == '__main__':
    raise SystemExit(main())
