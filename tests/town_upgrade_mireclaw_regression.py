"""Focused Mireclaw upgrade combat actions with isolated headless profiles."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = r'''extends Node
const B = preload("res://scripts/core/BattleRules.gd")
const S = preload("res://scripts/core/SpellRules.gd")
var checks := 0
var failures := []
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label)
func fixture(uid:String,gap:int=0):
	var s=ScenarioFactory.create_session("river-pass","normal",SessionState.LAUNCH_MODE_SKIRMISH)
	s.battle=B.create_battle_payload(s,s.overworld.encounters[0])
	var a=B._build_battle_stack(uid,20,"player",0)
	var t=B._build_battle_stack("unit_river_guard",20,"enemy",0)
	var ally=B._build_battle_stack("unit_river_guard",20,"player",1)
	for st in [a,t,ally]:
		st.total_health=20000;st.unit_hp=1000;st.base_count=20
		st.min_damage=10;st.max_damage=10;st.attack=5;st.defense=5
		st.battle_footprint=1;st.effects=[];st.retaliations_left=0
		st.spell_resistance_pct=0;st.control_resistance_pct=0
		st.cohesion_base=5;st.cohesion=5;st.momentum=0
	t.abilities=[];ally.abilities=[];t.tier=4
	a.hex={"q":3,"r":3};t.hex={"q":4+gap,"r":3};ally.hex={"q":1,"r":1}
	s.battle.stacks=[a,t,ally];s.battle.round=1
	s.battle.turn_order=[a.battle_id,ally.battle_id,t.battle_id]
	s.battle.turn_index=0;s.battle.active_stack_id=a.battle_id;s.battle.selected_target_id=t.battle_id
	s.battle[B.FIELD_OBJECTIVES_KEY]=[]
	s.game_state="battle"
	sync(s)
	return s
func sync(s):
	B._sync_occupied_hexes(s.battle);B._sync_distance_from_hexes(s.battle)
func hit(s,ranged:bool=false)->Dictionary:
	# Each probe starts at this actor's action boundary. Keep a living friendly
	# next in the queue so automatic enemy turns cannot consume the effect.
	s.battle.turn_index=0;s.battle.active_stack_id=s.battle.stacks[0].battle_id
	s.battle.selected_target_id=s.battle.stacks[1].battle_id
	return B._resolve_attack_action(s,s.battle.stacks[0],s.battle.stacks[1],ranged)
func marked(s,id:String)->bool:
	return S.has_effect_id(s.battle.stacks[1],s.battle,id)
func reset_target(s,gap:int=0):
	s.battle.stacks[1].effects=[]
	s.battle.stacks[1].hex={"q":4+gap,"r":3}
	sync(s)
func damage(s,ranged:bool=false)->int:
	var before=int(s.battle.stacks[1].total_health)
	check(hit(s,ranged).ok,"damage comparison attack resolves")
	return before-int(s.battle.stacks[1].total_health)
func _ready():call_deferred("run")
func run():
	# Knifeshade consumes a root that the base Cutthroat cannot exploit.
	var upgraded=fixture("unit_blackbranch_cutthroat_veteran")
	var base=fixture("unit_blackbranch_cutthroat")
	for s in [upgraded,base]:s.battle.stacks[1].effects=[S.build_battle_effect("status_rooted","Pinned",{},1,s.battle)]
	check(damage(upgraded)>damage(base),"Knifeshade newly exploits rooted prey at equal attack stats")
	upgraded=fixture("unit_blackbranch_cutthroat_veteran");base=fixture("unit_blackbranch_cutthroat")
	check(damage(upgraded)==damage(base),"Knifeshade clean target gains no unconditional ability damage")
	# Supported snare, lower-tier access, two uses and no third use.
	var s=fixture("unit_mireclaw_reedsnare_kin_veteran")
	s.battle.stacks[1].tier=2
	check(hit(s).ok and not marked(s,"status_mire_harried"),"Trapper cannot snare without another adjacent ally")
	s.battle.stacks[2].hex={"q":4,"r":4};sync(s)
	for i in range(2):
		reset_target(s)
		check(hit(s).ok and marked(s,"status_mire_harried"),"Trapper supported snare use "+str(i+1))
		check(S.effect_bonus_for_kind(s.battle.stacks[1],s.battle,"initiative")==-1,"Trapper delays actual survivor")
	reset_target(s);check(hit(s).ok and not marked(s,"status_mire_harried"),"Trapper cannot snare a third time")
	# Bulwark protects a different allied ranged stack under real contact attack.
	var screened=fixture("unit_river_guard")
	var unscreened=fixture("unit_river_guard")
	for pair in [[screened,"unit_bog_brute_veteran"],[unscreened,"unit_bog_brute"]]:
		var battle:Dictionary=pair[0].battle
		battle.stacks[0].abilities=[];battle.stacks[1].ranged=true
		var shield=B._build_battle_stack(pair[1],20,"enemy",1)
		shield.hex={"q":8,"r":6};battle.stacks.append(shield);sync(pair[0])
	check(damage(screened)<damage(unscreened),"Bulwark screen reduces actual damage to allied ranged target")
	# Slingers can blind tier three and ranged targets, twice only.
	s=fixture("unit_mireclaw_mudglass_slingers_veteran",4)
	s.battle.stacks[1].tier=3;s.battle.stacks[1].ranged=true
	for i in range(2):
		reset_target(s,4)
		check(hit(s,true).ok and marked(s,"status_mire_harried"),"Slinger ranged-tier-three blind "+str(i+1))
		check(S.effect_bonus_for_kind(s.battle.stacks[1],s.battle,"attack")==-1 and S.effect_bonus_for_kind(s.battle.stacks[1],s.battle,"initiative")==-1,"Slinger applied attack and initiative penalties")
	reset_target(s,4);check(hit(s,true).ok and not marked(s,"status_mire_harried"),"Slinger third shot no blind")
	s=fixture("unit_mireclaw_mudglass_slingers_veteran",4);s.battle.stacks[1].tier=2
	check(hit(s,true).ok and not marked(s,"status_mire_harried"),"Slinger respects lower-tier nontrigger")
	# Redhook gains a single delayed crossing attack and actual pull.
	s=fixture("unit_gorefen_ripper_veteran",1)
	check(not hit(s).ok,"Redhook cannot hook in round one")
	s.battle.round=2
	check(hit(s).ok and marked(s,"status_rooted"),"Redhook roots on round-two gap strike")
	check(B._stack_hex_distance(s.battle.stacks[0],s.battle.stacks[1])==1,"Redhook pulls target into contact")
	reset_target(s,1);check(not hit(s).ok,"Redhook cannot spend hook twice")
	# Gatebreaker has reusable reach, but never displaces its target.
	s=fixture("unit_mireclaw_bogplate_maulers_veteran",1)
	check(hit(s).ok and B._stack_hex_distance(s.battle.stacks[0],s.battle.stacks[1])==2,"Gatebreaker reaches without pulling")
	check(hit(s).ok,"Gatebreaker reach is reusable")
	base=fixture("unit_mireclaw_bogplate_maulers",1);check(not hit(base).ok,"Base mauler cannot cross the same lane")
	upgraded=fixture("unit_mireclaw_bogplate_maulers_veteran");base=fixture("unit_mireclaw_bogplate_maulers")
	for probe in [upgraded,base]:probe.battle.stacks[1].effects=[S.build_battle_effect("status_rooted","Pinned",{},1,probe.battle)]
	check(damage(upgraded)>damage(base),"Gatebreaker newly punishes roots at equal attack stats")
	# Chainmaster opens on round one twice; base lasher waits until round two.
	s=fixture("unit_mireclaw_ferrychain_lashers_veteran",1)
	for i in range(2):
		reset_target(s,1)
		check(hit(s).ok and marked(s,"status_rooted"),"Chainmaster opening pull "+str(i+1))
		check(B._stack_hex_distance(s.battle.stacks[0],s.battle.stacks[1])==1,"Chainmaster actual displacement")
	reset_target(s,1);check(not hit(s).ok,"Chainmaster spent second hook")
	base=fixture("unit_mireclaw_ferrychain_lashers",1);check(not hit(base).ok,"Base lasher opening gate unchanged")
	# Dissonant ranged cast opens tier-three retaliation; melee does not cast.
	s=fixture("unit_mireclaw_mireglass_reedcasters_veteran",4);s.battle.stacks[1].tier=3
	check(hit(s,true).ok and marked(s,"status_mire_harried"),"Dissonant marks tier-three survivor")
	check(S.effect_bonus_for_kind(s.battle.stacks[1],s.battle,"retaliation")==-20,"Dissonant applies retaliation suppression")
	reset_target(s,4);check(hit(s,true).ok and not marked(s,"status_mire_harried"),"Dissonant cast consumed")
	s=fixture("unit_mireclaw_mireglass_reedcasters_veteran")
	check(hit(s).ok and not marked(s,"status_mire_harried"),"Dissonant contact attack cannot cast")
	s=fixture("unit_mireclaw_mireglass_reedcasters_veteran",4);s.battle.stacks[1].tier=2
	check(hit(s,true).ok and not marked(s,"status_mire_harried"),"Dissonant excludes tier-two targets")
	# Cantor lingering calls survive round two and expire at round three.
	s=fixture("unit_mireclaw_sporewake_chanters_veteran",4)
	for i in range(2):
		reset_target(s,4)
		check(hit(s,true).ok and marked(s,"status_harried"),"Cantor repeated rot call "+str(i+1))
		check(S.effect_bonus_for_kind(s.battle.stacks[1],s.battle,"cohesion")==-2,"Cantor survivor cohesion reduced")
	s.battle.round=2;check(marked(s,"status_harried"),"Cantor mark lingers into second round")
	s.battle.round=3;check(not marked(s,"status_harried"),"Cantor mark expires in third round")
	reset_target(s,4);check(hit(s,true).ok and not marked(s,"status_harried"),"Cantor cannot cast third call")
	upgraded=fixture("unit_mireclaw_sporewake_chanters_veteran",4);base=fixture("unit_mireclaw_sporewake_chanters",4)
	for probe in [upgraded,base]:probe.battle.stacks[1].total_health=9000
	check(damage(upgraded,true)>damage(base,true),"Cantor strengthened wounded payoff changes actual shot damage")
	# Tollreaper binds only an elite reached in contact.
	s=fixture("unit_mireclaw_fenbell_chainstalkers_veteran")
	check(hit(s).ok and marked(s,"status_rooted"),"Tollreaper roots a contacted tier-four target")
	check(S.effect_bonus_for_kind(s.battle.stacks[1],s.battle,"defense")==-1,"Tollreaper reduces survivor defense")
	s=fixture("unit_mireclaw_fenbell_chainstalkers_veteran");s.battle.stacks[1].tier=3
	check(hit(s).ok and not marked(s,"status_rooted"),"Tollreaper does not bind low tiers")
	# Packlord's isolated prey payoff and elite quarry mark are separate triggers.
	upgraded=fixture("unit_mireclaw_gorefen_rippers_veteran");base=fixture("unit_mireclaw_gorefen_rippers")
	check(damage(upgraded)>damage(base),"Packlord increases actual isolated-prey damage at equal stats")
	s=fixture("unit_mireclaw_gorefen_rippers_veteran");s.battle.stacks[1].tier=5
	check(hit(s).ok and marked(s,"status_mire_harried"),"Packlord leaves elite quarry mark")
	check(S.effect_bonus_for_kind(s.battle.stacks[1],s.battle,"defense")==-1,"Packlord quarry defense penalty")
	s=fixture("unit_mireclaw_gorefen_rippers_veteran");check(hit(s).ok and not marked(s,"status_mire_harried"),"Packlord tier-four target not marked")
	# Crown's root is a defending retaliation; idle retaliation never roots.
	for defending in [false,true]:
		s=fixture("unit_river_guard")
		var crown=B._build_battle_stack("unit_mireclaw_drowned_antler_sovereign_veteran",20,"enemy",0)
		crown.hex={"q":4,"r":3};crown.battle_footprint=1;crown.total_health=20000;crown.unit_hp=1000
		crown.base_count=20;crown.defending=defending;crown.retaliations_left=1
		s.battle.stacks[1]=crown;s.battle.stacks[0].abilities=[];sync(s)
		check(hit(s).ok,"Crown retaliation attack resolves")
		check(S.has_effect_id(s.battle.stacks[0],s.battle,"status_rooted")==defending,"Crown root requires defending retaliation "+str(defending))
	print("MIRE_UPGRADE_REPORT "+JSON.stringify({"checks":checks,"failures":failures}))
	get_tree().quit(0 if failures.is_empty() else 1)
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='mire-probe-', dir=out) as directory:
        work = Path(directory)
        (work / 'probe.gd').write_text(SCRIPT, encoding='utf-8')
        scene = work / 'probe.tscn'
        scene.write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="probe.gd" id="1"]\n[node name="MireProbe" type="Node"]\nscript=ExtResource("1")\n', encoding='utf-8')
        env = dict(os.environ, APPDATA=str(work / 'profile'), XDG_DATA_HOME=str(work / 'profile'), PYTHONDONTWRITEBYTECODE='1')
        command = [args.godot, '--headless', '--path', str(ROOT), '--audio-driver', 'Dummy', '--log-file', str(out / 'engine.log'), 'res://' + scene.relative_to(ROOT).as_posix()]
        with (out / 'console.log').open('w', encoding='utf-8') as log:
            code = subprocess.run(command, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=120,
                                  creationflags=subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0).returncode
        text = (out / 'console.log').read_text(encoding='utf-8')
        rows = [line.partition('MIRE_UPGRADE_REPORT ')[2] for line in text.splitlines() if line.startswith('MIRE_UPGRADE_REPORT ')]
        report = json.loads(rows[-1]) if rows else {'failures': ['no report']}
        errors = [line for line in text.splitlines() if 'ERROR' in line and line != 'ERROR: Failed to read the root certificate store.']
        print('MIRE_UPGRADE_REPORT ' + json.dumps(report))
        for line in errors:
            print(line)
        return code or int(bool(report['failures']) or bool(errors))


if __name__ == '__main__':
    raise SystemExit(main())
