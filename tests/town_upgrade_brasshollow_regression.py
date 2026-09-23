"""Headless live-rule trigger coverage for all twelve Brasshollow upgrades."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import tempfile

from battle_readability_regression import run_probe

ROOT = Path(__file__).resolve().parents[1]
MARKER = 'BRASS_UPGRADE_REPORT '
SCRIPT = r'''extends Node
const B = preload("res://scripts/core/BattleRules.gd")
const S = preload("res://scripts/core/SpellRules.gd")
var checks := 0
var failures := []
func check(ok: bool, message: String):
	checks += 1
	if not ok: failures.append(message)
func unit(suffix: String, upgraded: bool=true, side: String="player", index: int=0) -> Dictionary:
	var u:Dictionary=B._build_battle_stack("unit_brasshollow_"+suffix+("_veteran" if upgraded else ""),10,side,index)
	u.hex={"q":2 if side=="player" else 5,"r":3}
	u.control_resistance_pct=0
	return u
func field(stacks: Array) -> Dictionary:
	return {"stacks":stacks,"round":1,"distance":2,"terrain_tags":[],"field_objectives":[],"presentation_events":[]}
func hit(b: Dictionary, a: Dictionary, d: Dictionary, ranged: bool=true):
	B._apply_attack_ability_effects(b,a,d,ranged,2 if ranged else 0,d.duplicate(true))
func mark(b: Dictionary, d: Dictionary, id: String):
	B._apply_stack_effect(b,d.battle_id,S.build_battle_effect(id,id,{},2,b,"ability","probe"))
func effect(d: Dictionary,b: Dictionary,id: String) -> bool:
	return S.has_effect_id(d,b,id)
func modifier(a:Dictionary,d:Dictionary,b:Dictionary,ranged:bool=true,retaliation:bool=false) -> float:
	return B._ability_damage_modifier(a,d,b,ranged,retaliation,2 if ranged else 0)
func _ready(): call_deferred("run")
func run():
	# Porters and bailiffs must actually defend before their new stagger fires.
	for suffix in ["scrip_haulers","gaugeplate_bailiffs"]:
		var a=unit(suffix);var d=unit("scrip_haulers",false,"enemy");var b=field([a,d])
		B._apply_retaliation_ability_effects(b,a,d)
		check(not effect(d,b,"status_staggered"),suffix+" must defend to stagger")
		a.defending=true
		var plain:float=modifier(a,d,b,false,false)
		check(modifier(a,d,b,false,true)>plain,suffix+" defending retaliation damage")
		B._apply_retaliation_ability_effects(b,a,d)
		check(effect(d,b,"status_staggered"),suffix+" retaliation staggers attacker")
		check(S.effect_bonus_for_kind(d,b,"initiative")<0,suffix+" stagger changes initiative")
		var base=unit(suffix,false);var base_target=unit("scrip_haulers",false,"enemy",1);base.defending=true
		var base_b=field([base,base_target]);B._apply_retaliation_ability_effects(base_b,base,base_target)
		check(not effect(base_target,base_b,"status_staggered"),suffix+" new stagger differs from base")
		if suffix=="gaugeplate_bailiffs":check(a.retaliations_left==2 and base.retaliations_left==1,"anvil has two runtime retaliation opportunities")
	# Throwers create exactly one stagger opening, and an allied volley consumes it.
	var a=unit("tallyspring_throwers");var d=unit("scrip_haulers",false,"enemy");var b=field([a,d])
	var shooter=unit("quenchspool_slingers",false,"player",1);b.stacks.append(shooter)
	var before:float=modifier(shooter,d,b)
	hit(b,a,d);check(effect(d,b,"status_staggered"),"writwheel creates stagger")
	check(modifier(shooter,d,b)>before,"writwheel opens allied volley payoff")
	d.effects=[];hit(b,a,d);check(not effect(d,b,"status_staggered"),"writwheel cannot repeat opening")
	# Hounds need adjacent support, may expose twice, and alter actual defense.
	a=unit("rivet_hounds");d=unit("gaugeplate_bailiffs",false,"enemy");b=field([a,d])
	hit(b,a,d,false);check(not effect(d,b,"status_rivet_exposed"),"unsupported hound cannot expose")
	var support=unit("scrip_haulers",false,"player",1);support.hex={"q":5,"r":2};b.stacks.append(support)
	for i in range(2):
		d.effects=[];hit(b,a,d,false)
		check(S.effect_bonus_for_kind(d,b,"defense")==-2,"supported hound defense exposure "+str(i))
	d.effects=[];hit(b,a,d,false);check(not effect(d,b,"status_rivet_exposed"),"hound limited to two exposures")
	# Spoolers do not consume the arrestor on ranged targets; its mark delays melee turns.
	a=unit("quenchspool_slingers");d=unit("gaugefire_arbalists",false,"enemy");b=field([a,d])
	hit(b,a,d);check(not effect(d,b,"status_rooted") and a.ability_uses.get("harry",0)==0,"arrestor ignores ranged target")
	d=unit("gaugeplate_bailiffs",false,"enemy");b.stacks[1]=d
	var initiative_before:int=B._stack_initiative_total(d,b);hit(b,a,d)
	check(effect(d,b,"status_rooted"),"arrestor roots melee target")
	check(B._stack_initiative_total(d,b)<initiative_before,"arrestor delays target initiative")
	var collector=unit("debt_engine_exactors");var unmarked=d.duplicate(true);unmarked.effects=[]
	check(modifier(collector,d,b,false)>modifier(collector,unmarked,b,false),"arrestor opens foreclosure collection payoff")
	d.effects=[];hit(b,a,d);check(not effect(d,b,"status_rooted"),"arrestor use limit")
	# Kilnwall screens friendly shooters, without applying its armor to an unshielded melee ally.
	a=unit("furnace_pavis_teams");d=unit("tallyspring_throwers",false,"player",1)
	var attacker=unit("tallyspring_throwers",false,"enemy");b=field([a,d,attacker])
	var bare=field([d,attacker]);check(modifier(attacker,d,b,false)<modifier(attacker,d,bare,false),"kilnwall protects allied shooter from melee")
	var melee=d.duplicate(true);melee.ranged=false;melee.abilities=[]
	check(is_equal_approx(modifier(attacker,melee,b,false),modifier(attacker,melee,bare,false)),"kilnwall does not grant unrelated melee armor")
	# Datum bolts pay off exposed/overheated targets; their opening only suppresses ranged units.
	a=unit("gaugefire_arbalists");d=unit("gaugeplate_bailiffs",false,"enemy");b=field([a,d])
	before=modifier(a,d,b);mark(b,d,"status_rivet_exposed")
	check(modifier(a,d,b)>before,"datum consumes seam mark")
	d.effects=[];mark(b,d,"status_overheated");check(modifier(a,d,b)>before,"datum consumes heat")
	d.effects=[];hit(b,a,d);check(not effect(d,b,"status_harried"),"counterbattery ignores melee")
	d=unit("gaugefire_arbalists",false,"enemy");b.stacks[1]=d;hit(b,a,d)
	check(S.effect_bonus_for_kind(d,b,"defense")==-1 and S.effect_bonus_for_kind(d,b,"initiative")==-2,"counterbattery debuffs shooter")
	# Twinboiler fragments can cross a two-hex separation; the base cannot.
	a=unit("boiler_rivetcasters");d=unit("scrip_haulers",false,"enemy")
	var secondary=unit("scrip_haulers",false,"enemy",1);secondary.hex={"q":7,"r":3};b=field([a,d,secondary])
	var health:int=secondary.total_health;hit(b,a,d)
	check(secondary.total_health<health and effect(a,b,"status_overheated"),"twinboiler two-hex fragments and self heat")
	var base=unit("boiler_rivetcasters",false);b.stacks[0]=base;secondary.total_health=health;hit(b,base,d)
	check(secondary.total_health==health,"base boiler cannot hit two-hex secondary")
	secondary.hex={"q":9,"r":3};b.stacks[0]=a;hit(b,a,d)
	check(secondary.total_health==health,"twinboiler cannot hit beyond fan")
	# Foreclosure rewards prepared primary melee only and recovers heat earlier than the base.
	a=unit("debt_engine_exactors");d=unit("gaugeplate_bailiffs",false,"enemy");b=field([a,d])
	before=modifier(a,d,b,false);var retaliation_before:float=modifier(a,d,b,false,true)
	mark(b,d,"status_rivet_exposed");check(modifier(a,d,b,false)>before,"foreclosure prepared melee payoff")
	check(is_equal_approx(modifier(a,d,b,false,true),retaliation_before),"foreclosure payoff excludes retaliation")
	hit(b,a,d,false);check(effect(a,b,"status_overheated"),"foreclosure creates heat")
	check(modifier(a,d,b,false)<before,"foreclosure hot damage penalty")
	base=unit("debt_engine_exactors",false);var base_b=field([base,d]);hit(base_b,base,d,false)
	b.round=2;base_b.round=2
	check(not effect(a,b,"status_overheated") and effect(base,base_b,"status_overheated"),"foreclosure cools one round before base")
	# Staybell's writ reduces retaliation, more strongly on a braced veteran; only one use.
	a=unit("quenchbell_mortars");d=unit("gaugeplate_bailiffs",false,"enemy");b=field([a,d])
	d.defending=true;before=modifier(d,a,b,false,true);hit(b,a,d)
	check(S.effect_bonus_for_kind(d,b,"retaliation")==-20,"staybell enhanced braced suppression")
	check(modifier(d,a,b,false,true)<before,"staybell changes retaliation damage")
	d.effects=[];hit(b,a,d);check(not effect(d,b,"status_obituary_marked"),"staybell one use")
	a=unit("quenchbell_mortars");d=unit("scrip_haulers",false,"enemy");b=field([a,d]);hit(b,a,d)
	check(S.effect_bonus_for_kind(d,b,"retaliation")==-10,"staybell ordinary suppression")
	# Crawlers now produce adjacent damage and heat; the base only has direct volley payoff.
	a=unit("crucible_crawlers");d=unit("scrip_haulers",false,"enemy");secondary=unit("scrip_haulers",false,"enemy",1)
	secondary.hex={"q":6,"r":3};b=field([a,d,secondary]);health=secondary.total_health;hit(b,a,d)
	check(secondary.total_health==health-16,"crawler bounded adjacent slag damage")
	check(effect(a,b,"status_overheated"),"crawler opens heat repair window")
	base=unit("crucible_crawlers",false);b.stacks[0]=base;secondary.total_health=health;hit(b,base,d)
	check(secondary.total_health==health and not effect(base,b,"status_overheated"),"base crawler has no fragments or heat")
	# Saint hardens cool allies; repairs living health only, with an additional heat payoff.
	a=unit("foundry_saint");d=unit("debt_engine_exactors",false,"player",1);b=field([a,d])
	var inert_saint=a.duplicate(true);inert_saint.abilities=[];bare=field([inert_saint,d])
	check(B._stack_defense_total(d,b)==B._stack_defense_total(d,bare)+1,"last furnace hardens cool ally")
	base=unit("foundry_saint",false);base_b=field([base,d]);check(B._stack_defense_total(d,base_b)==B._stack_defense_total(d,bare),"base saint requires heat")
	mark(base_b,d,"status_overheated");check(B._stack_defense_total(d,base_b)==B._stack_defense_total(d,bare)+1,"base saint heat gate remains live")
	d.effects=[];d.total_health=9*d.unit_hp-20;health=d.total_health
	B._apply_foundry_aura_round_repair(b);var cool_repair:int=d.total_health-health
	check(cool_repair>0,"saint cool repair")
	d.total_health=health;mark(b,d,"status_overheated");B._apply_foundry_aura_round_repair(b)
	check(d.total_health-health>cool_repair,"saint overheated repair bonus")
	check(B._alive_count(d)==9,"saint never resurrects casualties")
	print("BRASS_UPGRADE_REPORT "+JSON.stringify({"checks":checks,"failures":failures,"ok":failures.is_empty()}))
	get_tree().quit(0 if failures.is_empty() else 1)
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='brass-upgrade-', dir=output) as directory:
        work = Path(directory)
        (work / 'probe.gd').write_text(SCRIPT, encoding='utf-8')
        scene = work / 'probe.tscn'
        scene.write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="probe.gd" id="1"]\n[node name="BrassUpgradeProbe" type="Node"]\nscript=ExtResource("1")\n', encoding='utf-8')
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
