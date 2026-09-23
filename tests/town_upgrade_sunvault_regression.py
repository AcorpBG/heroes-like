"""Focused headless BattleRules behavior checks for the twelve Sunvault upgrades."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
MARKER = 'SUNVAULT_UPGRADE_REPORT '


def run_probe(command, env, log, timeout_seconds=120):
    """Bounded, hidden Windows or headless Linux child with isolated user data."""
    return subprocess.run(command, cwd=ROOT, env=env, stdout=log,
                          stderr=subprocess.STDOUT, timeout=timeout_seconds,
                          creationflags=subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0).returncode


SCRIPT = r'''extends Node
const B = preload("res://scripts/core/BattleRules.gd")
const S = preload("res://scripts/core/SpellRules.gd")
var checks = 0
var failures = []
func check(value, label):
	checks += 1
	if not value: failures.append(label)
func same(actual, expected, label):
	check(is_equal_approx(float(actual),float(expected)),label+" (actual="+str(actual)+", expected="+str(expected)+")")
func unit(id, side="player", index=0, x=2, y=3):
	var row = B._build_battle_stack(id,10,side,index)
	row.hex={"x":x,"y":y}
	return row
func enemy(tier=4, ranged=false, x=6, y=3):
	var row=unit("unit_river_guard","enemy",0,x,y)
	row.tier=tier;row.ranged=ranged;row.abilities=[];row.effects=[]
	row.control_resistance_pct=0;row.spell_resistance_pct=0;row.spell_school_resistance_pct={}
	row.unit_hp=100;row.base_count=10;row.total_health=1000
	return row
func battle(stacks):
	return {"stacks":stacks,"round":1,"distance":2,"terrain":"grass","field_objectives":[],"battlefield_tags":[],"heroes":{},"log":[],"presentation_events":[]}
func current(b,s):return B._get_stack_by_id(b,s.battle_id)
func hit_effects(b,a,d,ranged=true,distance=2):
	B._apply_attack_ability_effects(b,current(b,a),current(b,d),ranged,distance,current(b,d).duplicate(true))
func modifier(a,d,b,ranged=true,retaliation=false,distance=2):
	return B._ability_damage_modifier(a,d,b,ranged,retaliation,distance)
func status(b,s,id):return S.has_effect_id(current(b,s),b,id)
func _ready():call_deferred("run")
func run():
	ContentService.clear_cache()
	dawnwall();mirrorback();harriers();conjurers();repeater();parallax();precentors();lockguards();pathfinders();arbiters();bulwarks();colossus()
	print("SUNVAULT_UPGRADE_REPORT "+JSON.stringify({"checks":checks,"failures":failures,"units":12}))
	get_tree().quit(0 if failures.is_empty() else 1)
func dawnwall():
	var a=unit("unit_shard_guard_veteran");var d=enemy(4,false,4,3);var b=battle([a,d])
	check(B._can_make_melee_attack(a,b,d),"Custodian cannot reach across one hex")
	var base=unit("unit_shard_guard")
	check(not B._can_make_melee_attack(base,b,d),"Base pavise unexpectedly has gap reach")
	check(B._can_make_retaliation(a,1,b) and not B._can_make_retaliation(base,1,b),"Custodian gap retaliation difference")
	B._consume_retaliation(b,a.battle_id)
	check(current(b,a).retaliations_left==1,"Custodian lost second retaliation after first answer")
	B._consume_retaliation(b,a.battle_id)
	check(current(b,a).retaliations_left==0,"Custodian retaliation budget not consumed")
	a.defending=true;B._apply_retaliation_ability_effects(b,a,d)
	check(status(b,d,"status_staggered"),"Custodian defending answer did not stagger")
func mirrorback():
	var a=unit("unit_sunvault_shard_wardens_veteran");var d=enemy(4,true);var h=unit("unit_prism_adept_veteran","player",1,3,3);var b=battle([a,d,h])
	same(B._linked_ranged_attack_screen_multiplier(h,b),.95,"Mirrorback upgraded Harrier ranged screen")
	var old=battle([unit("unit_sunvault_shard_wardens"),d,h])
	same(B._linked_ranged_attack_screen_multiplier(h,old),1.0,"Base Warden should not screen Harrier branch")
	same(modifier(d,h,b,false,false,0),.96,"Mirrorback contact screen")
	var before=a.duplicate(true);B._apply_damage_to_stack(b,a.battle_id,50)
	var health=int(d.total_health);B._apply_ranged_damage_return(b,d.battle_id,before,true,"attack")
	check(health-current(b,d).total_health==9,"Mirrorback did not reflect 18 percent actual damage")
	health=current(b,d).total_health;B._apply_ranged_damage_return(b,d.battle_id,before,false,"attack")
	check(current(b,d).total_health==health,"Mirrorback reflected melee attack")
	current(b,a).total_health=0
	same(B._linked_ranged_attack_screen_multiplier(h,b),1.0,"Dead Mirrorback still screens Harriers")
func harriers():
	var a=unit("unit_prism_adept_veteran");var d=enemy();var b=battle([a,d]);var clean=modifier(a,d,b)
	d.total_health=400
	same(modifier(a,d,b),clean*1.2,"Glarewing wounded threshold damage")
	d.total_health=401
	same(modifier(a,d,b),clean,"Glarewing finisher active above 40 percent")
	var base=unit("unit_prism_adept");d.total_health=400
	same(modifier(base,d,b),1.12,"Base Harrier gained upgrade finisher")
	hit_effects(b,a,d)
	check(status(b,d,"status_harried"),"Glarewing lost surviving-target mark")
func conjurers():
	var a=unit("unit_sunvault_prism_adepts_veteran");var d=enemy(2);var b=battle([a,d])
	hit_effects(b,a,d)
	check(not status(b,d,"status_staggered") and a.ability_uses.is_empty(),"Conjurer spent lattice charge on tier two")
	d.tier=3;hit_effects(b,a,d)
	check(status(b,d,"status_staggered"),"Conjurer did not stagger tier three")
	check(S.effect_bonus_for_kind(current(b,d),b,"initiative")==-2,"Conjurer stagger initiative missing")
	d.effects=[];hit_effects(b,a,d);d.effects=[];hit_effects(b,a,d)
	check(not status(b,d,"status_staggered") and a.ability_uses.get("harry",0)==2,"Conjurer exceeded two control charges")
	var base=unit("unit_sunvault_prism_adepts");b=battle([base,d]);hit_effects(b,base,d)
	check(not status(b,d,"status_staggered"),"Base Adept gained lattice control")
func repeater():
	var a=unit("unit_aurora_ballista_veteran");var d=enemy(3,true);var b=battle([a,d])
	hit_effects(b,a,d);check(not status(b,d,"status_harried"),"Repeater suppressed ranged target")
	d.ranged=false;hit_effects(b,a,d)
	check(status(b,d,"status_harried"),"Repeater failed to suppress tier-three melee")
	same(S.effect_bonus_for_kind(current(b,d),b,"retaliation"),-15,"Repeater retaliation suppression")
	var opponent=unit("unit_shard_guard","player",1);var bare=d.duplicate(true);bare.effects=[]
	same(modifier(current(b,d),opponent,b,false,true,0),modifier(bare,opponent,b,false,true,0)*.85,"Suppression does not reduce actual retaliation modifier")
	d.effects=[];hit_effects(b,a,d);d.effects=[];hit_effects(b,a,d)
	check(not status(b,d,"status_harried"),"Repeater exceeded two suppression charges")
func parallax():
	var a=unit("unit_sunvault_mirror_duelists_veteran");var d=enemy(4,false,4,3);var b=battle([a,d])
	check(B._can_make_melee_attack(a,b,d),"Parallax reach still needs held objective")
	check(not B._can_make_melee_attack(unit("unit_sunvault_mirror_duelists"),b,d),"Base Duelist objective gating lost")
	var full=modifier(a,d,b,false,false,0);d.total_health=500
	same(modifier(a,d,b,false,false,0),full*1.12,"Parallax wounded primary melee payoff")
	same(modifier(a,d,b,false,true,0),1.0,"Parallax finisher leaked into retaliation")
	same(modifier(a,d,b,true,false,2),1.0,"Parallax finisher leaked into ranged attack")
func precentors():
	var a=unit("unit_sunvault_resonant_choristers_veteran");var h=unit("unit_prism_adept_veteran","player",1,3,3);var d=enemy(3);var b=battle([a,h,d])
	var old=battle([unit("unit_sunvault_resonant_choristers"),h,d])
	check(B._faction_initiative_bonus(h,b)==B._faction_initiative_bonus(h,old)+1,"Precentor linked Harrier initiative missing")
	hit_effects(b,a,d);check(not status(b,d,"status_harried"),"Precentor censure triggered below tier four")
	d.tier=4;hit_effects(b,a,d)
	check(status(b,d,"status_harried"),"Precentor censure fails tier-four trigger")
	same(S.effect_bonus_for_kind(current(b,d),b,"retaliation"),-15,"Precentor retaliation pressure missing")
	d.effects=[];hit_effects(b,a,d);d.effects=[];hit_effects(b,a,d)
	check(not status(b,d,"status_harried"),"Precentor exceeded two censure charges")
func lockguards():
	var a=unit("unit_sunvault_noonfacet_sentinels_veteran");var d=enemy(4,false,4,3);var b=battle([a,d])
	check(not B._can_make_melee_attack(a,b,d),"Meridian hookline usable before round two")
	b.round=2
	check(B._can_make_melee_attack(a,b,d),"Meridian hookline cannot reach on round two")
	hit_effects(b,a,d,false,1)
	check(B._stack_hex_distance(current(b,a),current(b,d))==1,"Meridian hookline did not pull target into contact")
	check(status(b,d,"status_rooted"),"Meridian lock status missing")
	same(S.effect_bonus_for_kind(current(b,d),b,"initiative"),-2,"Meridian lock initiative missing")
	check(not B._hookline_available(current(b,a),b),"Meridian one-use hookline not consumed")
func pathfinders():
	var a=unit("unit_sunvault_solar_array_striders_veteran");var h=unit("unit_sunvault_zenith_lensbearers","player",1,3,3);var d=enemy();var b=battle([a,h,d])
	same(B._solar_array_lane_melee_multiplier(h,b),.92,"Pathfinder tier-five partner does not activate lane")
	var old=battle([unit("unit_sunvault_solar_array_striders"),h,d])
	same(B._solar_array_lane_melee_multiplier(h,old),1.0,"Base Strider unexpectedly links tier-five partner")
	h.total_health=0
	same(B._solar_array_lane_melee_multiplier(h,b),1.0,"Dead partner keeps Pathfinder network online")
	d.hex={"x":4,"y":3}
	check(B._can_make_melee_attack(a,b,d),"Pathfinder survey blade lacks gap reach")
func arbiters():
	var a=unit("unit_sunvault_zenith_lensbearers_veteran");var h=unit("unit_prism_adept","player",1,1,1)
	var d=unit("unit_sunvault_mirror_duelists_veteran","enemy",0,7,6);var b=battle([a,h,d]);h.total_health=20
	var bare=battle([h,d]);var unguarded=modifier(d,h,bare,false,false,0)
	same(modifier(d,h,b,false,false,0),1+(unguarded-1)*.5,"Horizon audit did not halve wounded backstab bonus")
	var raider=unit("unit_veilmourn_fogbound_leviathan","enemy",0,7,6);b=battle([a,h,raider])
	hit_effects(b,raider,h,false,0)
	check(not status(b,h,"status_fogbound"),"Horizon audit allowed Fogbound")
	check(status(b,raider,"status_flare_revealed"),"Horizon audit did not expose fogwake attacker")
	a.total_health=0;h.effects=[];raider.effects=[];hit_effects(b,raider,h,false,0)
	check(status(b,h,"status_fogbound"),"Dead Arbiter still blocks Fogbound")
func bulwarks():
	var a=unit("unit_sunvault_aurora_ballistae_veteran");var h=unit("unit_prism_adept","player",1,3,3);var d=enemy();var b=battle([a,h,d])
	same(modifier(d,h,b,false,false,0),.92,"Corona general contact screen")
	d.abilities=B._normalize_unit_abilities([{"id":"reach"}])
	same(modifier(d,h,b,false,false,0),.86,"Corona extra linebreaker screen")
	same(modifier(d,h,b,true,false,2),1.0,"Corona contact screen incorrectly reduces ranged fire")
	B._apply_retaliation_ability_effects(b,a,d)
	check(not status(b,d,"status_staggered"),"Corona answer debuffs while not defending")
	a.defending=true;B._apply_retaliation_ability_effects(b,a,d)
	check(status(b,d,"status_staggered"),"Corona defending answer did not dazzle")
	same(S.effect_bonus_for_kind(current(b,d),b,"attack"),-1,"Corona dazzle attack penalty missing")
func colossus():
	var a=unit("unit_sunvault_daybreak_colossus_veteran");var d=enemy(4,false,7,3);var secondary=enemy(4,false,8,3)
	secondary.battle_id="enemy_secondary";var far=enemy(4,false,11,6);far.battle_id="enemy_far"
	var b=battle([a,d,secondary,far]);var health=int(secondary.total_health);hit_effects(b,a,d)
	check(health-current(b,secondary).total_health==24,"Firstlight splash cap damage incorrect")
	check(current(b,far).total_health==1000,"Firstlight splashed outside adjacent target")
	check(status(b,a,"status_overheated"),"Firstlight shot did not heat aperture")
	same(S.effect_bonus_for_kind(current(b,a),b,"initiative"),-1,"Firstlight heat has no initiative cost")
	var base=unit("unit_sunvault_daybreak_colossus");b=battle([base,d,secondary]);health=secondary.total_health;hit_effects(b,base,d)
	check(current(b,secondary).total_health==health and not status(b,base,"status_overheated"),"Base Colossus gained splash or heat")
	a=unit("unit_sunvault_daybreak_colossus_veteran");a.base_count=2;a.total_health=a.unit_hp*2;b=battle([a,d,secondary]);health=secondary.total_health;hit_effects(b,a,d)
	check(health-current(b,secondary).total_health==8,"Firstlight splash does not scale with surviving count")
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='probe-', dir=out) as directory:
        work = Path(directory)
        (work / 'probe.gd').write_text(SCRIPT, encoding='utf-8')
        scene = work / 'probe.tscn'
        scene.write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="probe.gd" id="1"]\n[node name="SunvaultUpgradeProbe" type="Node"]\nscript=ExtResource("1")\n', encoding='utf-8')
        env = dict(os.environ, APPDATA=str(work/'profile'), LOCALAPPDATA=str(work/'local-profile'),
                   XDG_DATA_HOME=str(work/'profile'), XDG_CONFIG_HOME=str(work/'config'))
        command = [args.godot, '--headless', '--path', str(ROOT), '--audio-driver', 'Dummy',
                   '--accessibility', 'disabled', '--log-file', str(out/'engine.log'),
                   'res://'+scene.relative_to(ROOT).as_posix()]
        with (out/'runtime.log').open('w', encoding='utf-8') as log:
            code = run_probe(command, env, log, timeout_seconds=120)
    text = (out/'runtime.log').read_text(encoding='utf-8', errors='replace')
    reports = [json.loads(line[len(MARKER):]) for line in text.splitlines() if line.startswith(MARKER)]
    report = reports[-1] if reports else {'failures': ['missing runtime report']}
    errors = [line for line in text.splitlines() if 'ERROR:' in line and 'root certificate store' not in line]
    report.update(returncode=code, errors=errors)
    report['ok'] = not code and not report['failures'] and not errors
    print(json.dumps(report))
    if not report['ok']:
        print(text)
    return 0 if report['ok'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
