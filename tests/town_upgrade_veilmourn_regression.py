"""Focused Veilmourn upgrade battle effects through the live Godot rules."""
import argparse
import subprocess
from pathlib import Path
from unittest.mock import patch

from unified_mines_regression import run_probe

SCRIPT = r'''extends Node
const B = preload("res://scripts/core/BattleRules.gd")
const S = preload("res://scripts/core/SpellRules.gd")
var checks := 0
var failures := []
func check(ok: bool, label: String):
	checks += 1
	if not ok: failures.append(label)
func _ready(): call_deferred("run")
func unit(suffix: String, upgraded: bool = true, side: String = "player", index: int = 0) -> Dictionary:
	var stack=B._build_battle_stack("unit_veilmourn_"+suffix+("_veteran" if upgraded else ""),8,side,index)
	stack.hex={"q":2 if side=="player" else 4,"r":3+index}
	return stack
func target(index: int = 0, ranged: bool = false) -> Dictionary:
	var t=unit("gloamkeel_bulwarks",false,"enemy",index)
	t.abilities=[]; t.effects=[]; t.ranged=ranged; t.status_immunity_ids=[]
	return t
func field(stacks: Array, round_number: int = 1, tags: Array = []) -> Dictionary:
	var b={"round":round_number,"terrain":"plains","distance":1,"battlefield_tags":tags,"stacks":stacks}
	B._ensure_battle_hex_state(b)
	return b
func fresh(b: Dictionary, t: Dictionary) -> Dictionary:
	return B._get_stack_by_id(b,t.battle_id)
func marked(b: Dictionary, t: Dictionary, id: String) -> bool:
	return S.has_effect_id(fresh(b,t),b,id)
func strike(b: Dictionary, a: Dictionary, t: Dictionary, ranged: bool = true, gap: int = 1):
	B._apply_attack_ability_effects(b,a,t,ranged,gap)
func mark(b: Dictionary, t: Dictionary, id: String):
	B._apply_stack_effect(b,t.battle_id,S.build_battle_effect(id,id,{},2,b,"test",id))
func damage(a: Dictionary,t: Dictionary,b: Dictionary,ranged: bool=false,gap: int=0,retaliation: bool=false)->float:
	return B._ability_damage_modifier(a,fresh(b,t),b,ranged,retaliation,gap)
func without(a: Dictionary,id: String)->Dictionary:
	var copy=a.duplicate(true)
	copy.abilities=copy.abilities.filter(func(x):return x.id!=id)
	return copy
func oars():
	for upgraded in [false,true]:
		for defending in [false,true]:
			var a=unit("bellwake_oars",upgraded);var t=target();var b=field([a,t])
			a.defending=defending
			B._apply_retaliation_ability_effects(b,a,t)
			check(marked(b,t,"status_staggered")==bool(upgraded and defending),"oar defending retaliation %s/%s"%[upgraded,defending])
			if upgraded and defending:
				check(S.effect_bonus_for_kind(fresh(b,t),b,"initiative")==-1,"oar stagger lowers initiative")
func limited_marks():
	for suffix in ["saltbell_casters","mourning_lanterns","obituary_scribes"]:
		var a=unit(suffix);var b=field([a]);var id="status_fogbound" if suffix=="saltbell_casters" else ("status_harried" if suffix=="mourning_lanterns" else "status_obituary_marked")
		if suffix!="obituary_scribes":
			var invalid=target(9,false);invalid.tier=1
			b.stacks.append(invalid);strike(b,a,invalid)
			check(not marked(b,invalid,id),suffix+" rejects ineligible target")
			check(a.ability_uses.get("harry",0)==0,suffix+" preserves charge on ineligible target")
		for n in range(3):
			var t=target(n,true);b.stacks.append(t);strike(b,a,t)
			check(marked(b,t,id)==(n<2),suffix+" bounded charge "+str(n))
			if n<2:
				var next=b.duplicate(true);next.round=2
				check(marked(next,t,id)==(suffix!="saltbell_casters"),suffix+" duration round two")
				if suffix=="obituary_scribes":check(S.effect_bonus_for_kind(fresh(b,t),b,"retaliation")==-10,"notice retaliation penalty")
		var base=unit(suffix,false);var bt=target(0,true);bt.tier=2;var bb=field([base,bt]);strike(bb,base,bt)
		if suffix=="mourning_lanterns":check(not marked(bb,bt,id),"base lantern cannot mark tier two")
		else:
			var second=target(1,true);bb.stacks.append(second);strike(bb,base,second)
			check(not marked(bb,second,id),suffix+" base has only one charge")
func hooks():
	for suffix in ["tidehook_deckhands","wakechain_boarders"]:
		for upgraded in [false,true]:
			var a=unit(suffix,upgraded);var t=target();var b=field([a,t])
			check(B._can_make_melee_attack(a,b,t)==bool(upgraded and suffix=="tidehook_deckhands"),suffix+" opening reach eligibility "+str(upgraded))
			b.round=2
			check(B._can_make_melee_attack(a,b,t),suffix+" round two reach")
			check(B._stack_hex_distance(a,t)==2,"hook fixture one-gap geometry")
			strike(b,a,t,false,1)
			check(B._stack_hex_distance(a,fresh(b,t))==1,suffix+" actual pull into contact")
			check(marked(b,t,"status_rooted"),suffix+" rooted combo mark")
			check(not B._hookline_available(a,b),suffix+" spent hook")
			b.round=3
			check(marked(b,t,"status_rooted")==bool(upgraded and suffix=="wakechain_boarders"),suffix+" rooted mark second round "+str(upgraded))
func corsairs():
	for id in ["status_fogbound","status_obituary_marked"]:
		for upgraded in [false,true]:
			var a=unit("maskglass_corsairs",upgraded);var t=target();var b=field([a,t]);var before=damage(a,t,b)
			mark(b,t,id)
			check(is_equal_approx(damage(a,t,b),before*(1.16 if upgraded else 1.0)),"corsair combo "+id+str(upgraded))
func harpoons():
	var a=unit("undertow_harpooners");var t=target();var b=field([a,t]);var bare=without(a,"volley")
	check(is_equal_approx(damage(a,t,b,true),damage(bare,t,b,true)),"keelbreaker no unconditional bonus")
	for id in ["status_rooted","status_fogbound"]:
		t.effects=[];b=field([a,t]);mark(b,t,id)
		check(is_equal_approx(damage(a,t,b,true),damage(bare,t,b,true)*1.15),"keelbreaker payoff "+id)
func bulwarks():
	var guard=unit("gloamkeel_bulwarks");var shooter=unit("mourning_lanterns",false,"player",1);var enemy=target();var b=field([guard,shooter,enemy]);var bare=field([without(guard,"shielding"),shooter,enemy])
	check(is_equal_approx(damage(enemy,shooter,b),damage(enemy,shooter,bare)*0.9),"mournhull protects ranged ally at contact")
	check(is_equal_approx(damage(enemy,shooter,b,false,1),damage(enemy,shooter,bare,false,1)),"mournhull screen excludes gap strike")
	check(is_equal_approx(damage(enemy,guard,b,true),damage(enemy,fresh(bare,guard),bare,true)*0.9),"mournhull self ranged screen")
func scribes_brace():
	var a=unit("obituary_scribes");var t=unit("gloamkeel_bulwarks",false,"enemy");var b=field([a,t]);strike(b,a,t)
	check(S.effect_bonus_for_kind(fresh(b,t),b,"retaliation")==-20,"registrar anti-brace penalty")
func pilots():
	for upgraded in [false,true]:
		var a=unit("wakeglass_navigators",upgraded);var t=target();var b=field([a,t])
		check(B._can_make_melee_attack(a,b,t)==upgraded,"pilot gap attack legal "+str(upgraded))
		if upgraded:
			check(is_equal_approx(damage(a,t,b,false,1),damage(without(a,"reach"),t,b,false,1)*0.55),"pilot reduced force at gap")
			strike(b,a,t,false,1);check(marked(b,t,"status_harried"),"pilot reach delivers false bearing")
func reavers():
	var a=unit("mirrorkeel_reavers");var enemy=target();var fog=field([a,enemy],1,["fog_bank"]);var clear=field([a,enemy])
	check(is_equal_approx(damage(enemy,a,fog),damage(enemy,a,clear)*0.88),"duskpass fog incoming reduction")
	var base=unit("mirrorkeel_reavers",false);var basefog=field([base,enemy],1,["fog_bank"]);var baseclear=field([base,enemy])
	check(is_equal_approx(damage(enemy,base,basefog),damage(enemy,base,baseclear)),"base reaver lacks fog protection")
	for id in ["status_fogbound","status_obituary_marked"]:
		var t=target();var b=field([a,t]);var before=damage(a,t,b);mark(b,t,id)
		check(is_equal_approx(damage(a,t,b),before*1.05),"duskpass combo "+id)
func sovereign():
	for isolated in [false,true]:
		var a=unit("fogbound_leviathan");var t=target();var b=field([a,t]);var friend=target(1)
		if not isolated:
			b.stacks.append(friend);friend.hex={"q":t.hex.q,"r":t.hex.r+1}
		strike(b,a,t,false,0)
		check(marked(b,t,"status_fogbound")==isolated,"sovereign isolation trigger "+str(isolated))
		b.round=2;check(marked(b,t,"status_fogbound")==isolated,"sovereign fog second round "+str(isolated))
	var hook=unit("tidehook_deckhands");var apex=unit("fogbound_leviathan",true,"enemy");var b=field([hook,apex])
	strike(b,hook,apex,false,1)
	check(not marked(b,apex,"status_rooted"),"sovereign root immunity blocks hook mark")
	var base=unit("fogbound_leviathan",false,"enemy");var second=unit("tidehook_deckhands");var bb=field([second,base])
	strike(bb,second,base,false,1)
	check(marked(bb,base,"status_rooted"),"base leviathan accepts rooted mark")
	var lantern=unit("mourning_lanterns");var other=field([lantern,apex]);strike(other,lantern,apex)
	check(marked(other,apex,"status_harried"),"sovereign immunity leaves non-root marks effective")
func immunity_and_readiness():
	for innate in [false,true]:
		var t=unit("fogbound_leviathan",innate,"enemy");var b=field([t])
		var ward=S.build_battle_effect("status_readiness_prepared","Ready",{},3,b)
		ward.blocked_status_ids=["status_rooted"];ward.protected_side="enemy"
		t.effects=[ward]
		if not innate:t.effects.append(S.build_battle_effect("test_root_ward","Root Ward",{},1,b,"test","",["status_rooted"]))
		var root=S.build_battle_effect("status_rooted","Rooted",{},1,b)
		var result=B._apply_stack_effect(b,t.battle_id,root)
		check(result.get("immune",false) and not result.get("applied",false),"innate/active immunity rejects ability status "+str(innate))
		check(marked(b,t,"status_readiness_prepared"),"immune target preserves readiness "+str(innate))
		if not innate:
			b.round=2;root=S.build_battle_effect("status_rooted","Rooted",{},1,b)
			result=B._apply_stack_effect(b,t.battle_id,root)
			check(result.get("blocked",false) and not result.get("immune",false),"expired immunity falls back to readiness")
			check(not marked(b,t,"status_readiness_prepared") and not marked(b,t,"status_rooted"),"readiness blocks once after immunity expires")
			result=B._apply_stack_effect(b,t.battle_id,root)
			check(result.get("applied",false) and marked(b,t,"status_rooted"),"root applies after both defenses exhaust")
func run():
	oars();limited_marks();hooks();corsairs();harpoons();bulwarks();scribes_brace();pilots();reavers();sovereign();immunity_and_readiness()
	print("VEILMOURN_UPGRADE_REPORT "+JSON.stringify({"checks":checks,"failures":failures}))
	get_tree().quit(0 if failures.is_empty() else 1)
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    original = subprocess.run
    def headless(command, **kwargs):
        if command[:2] == ['xvfb-run', '-a']:
            command = command[2:]
        return original([command[0], '--headless', *command[1:]], **kwargs)
    with patch('unified_mines_regression.subprocess.run', headless):
        return run_probe(SCRIPT, args.godot, args.output, 'VEILMOURN_UPGRADE_REPORT')


if __name__ == '__main__':
    raise SystemExit(main())
