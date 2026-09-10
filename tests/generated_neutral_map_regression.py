#!/usr/bin/env python3
"""Real native Medium/Large adoption, battle roster, save and rendered evidence."""
import argparse
from contextlib import contextmanager
import hashlib
import json
import os
from pathlib import Path
import subprocess
import shutil
import tempfile

ROOT=Path(__file__).resolve().parents[1]
OUTPUT=ROOT/'.artifacts/generated_neutral_variety_20260910'

@contextmanager
def preserve_generated_map_files(size):
    # These deterministic source cases use the production res://maps policy.
    # Preserve their exact existing files instead of leaving test-generated
    # packages in the owner's map browser. Exported tests use isolated user://.
    stem={'medium':'medium-moon-field-fen-32ad55a3','large':'large-fallow-lantern-fen-4587a983'}[size]
    paths=[ROOT/'maps'/(stem+suffix) for suffix in ('.amap','.ascenario')]
    with tempfile.TemporaryDirectory(prefix='heroes-neutral-map-backup-') as tmp:
        backups={}
        for path in paths:
            if path.is_symlink(): raise ValueError('refusing symlink map output '+str(path))
            if path.exists():
                backup=Path(tmp)/path.name
                shutil.copy2(path,backup)
                backups[path]=backup
        try: yield
        finally:
            for path in paths:
                if path in backups:
                    shutil.copy2(backups[path],path)
                    assert hashlib.sha256(path.read_bytes()).digest()==hashlib.sha256(backups[path].read_bytes()).digest()
                elif path.is_file(): path.unlink()

def probe_environment(environment):
    return environment

def run_probe(command, environment, log, timeout_seconds=900):
    return subprocess.run(command,env=environment,stdout=log,stderr=subprocess.STDOUT,timeout=timeout_seconds).returncode

SCRIPT=r'''extends Node
const Setup = preload("res://scripts/core/ScenarioSelectRules.gd")
const Store = preload("res://scripts/core/SessionStateStore.gd")
const Battle = preload("res://scripts/core/BattleRules.gd")
const Neutral = preload("res://scripts/persistence/GeneratedNeutralEncounterRules.gd")
var failures := []
var checks := 0
var out := ""
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures.append(message)
func _ready() -> void:
	get_tree().current_scene=null
	call_deferred("run")
func settle() -> void:
	for frame in range(12): await get_tree().process_frame
func capture(name: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png(out.path_join(name+".png"))==OK,"screenshot failed")
func run() -> void:
	out=OS.get_environment("NEUTRAL_OUT")
	var size := OS.get_environment("NEUTRAL_SIZE")
	var seed := "10" if size=="medium" else "large-runtime-profile-10225"
	var players := 2 if size=="medium" else 4
	var config := Setup.build_random_map_player_config(seed,"translated_rmg_template_042_v1","translated_rmg_profile_042_v1",players,"land",false,"homm3_"+size,Setup.RANDOM_MAP_TEMPLATE_SELECTION_MODE_SIZE_DEFAULT,"faction_embercourt","")
	var setup := Setup.build_random_map_skirmish_setup_with_retry(config,"normal",Setup.RANDOM_MAP_PLAYER_RETRY_POLICY)
	check(bool(setup.get("ok",false)),"native generation/setup failed")
	if not bool(setup.get("ok",false)):
		finish({"setup":setup});return
	var session=Setup.start_random_map_skirmish_session_from_setup(setup)
	if session==null or String(session.scenario_id)=="":
		check(false,"native session adoption failed");finish({});return
	session=SessionState.set_active_session(session)
	var identities := {}
	var identity_counts := {}
	var quantities := {}
	var stack_counts := {}
	var compositions := {}
	var rows := []
	var guards := []
	var supplemental_ids := {}
	var rendered_guards := []
	for encounter in session.overworld.get("encounters",[]):
		if encounter.has("generated_neutral_profile"): rendered_guards.append(encounter)
		if String(encounter.get("generated_package_guard_policy",""))=="rare_economy_source_requires_runtime_guard_link":
			check(encounter.encounter_id!="encounter_mire_raid" and encounter.has("generated_neutral_profile"),"rare-source guard kept the fixed raid fallback")
			supplemental_ids[encounter.encounter_id]=true
		if not encounter.has("native_guard_quantity"): continue
		guards.append(encounter)
		check(encounter.has("generated_neutral_profile"),"native guard still bypasses content mapping")
		if not encounter.has("generated_neutral_profile"): continue
		var expected := Neutral.resolve(encounter)
		check(expected.ok,"repeat guard mapping rejected")
		if not expected.ok: continue
		check(encounter.encounter_id==expected.encounter.encounter_id and encounter.enemy_army.stacks==expected.encounter.enemy_army.stacks,"normalization changed deterministic roster")
		var count := 0
		for stack in encounter.enemy_army.stacks: count+=int(stack.count)
		check(count==int(encounter.native_guard_quantity),"native headcount differs after live normalization")
		identities[encounter.encounter_id]=true
		identity_counts[encounter.encounter_id]=int(identity_counts.get(encounter.encounter_id,0))+1
		quantities[count]=true
		stack_counts[encounter.enemy_army.stacks.size()]=true
		compositions[JSON.stringify(encounter.enemy_army.stacks)]=true
		rows.append({"placement_id":encounter.placement_id,"source_subtype":encounter.native_guard_creature_subtype,"source_level":encounter.native_guard_level,"quantity":count,"encounter_id":encounter.encounter_id,"army":encounter.enemy_army,"asset_id":encounter.generated_neutral_profile.asset_id})
	check(guards.size()>=10,"real native guards not exercised")
	check(identities.size()>=8,"generated map still has little encounter identity variety")
	for count in identity_counts.values():
		check(float(count)/float(maxi(1,guards.size()))<0.3,"one translated encounter dominates the representative map")
	check(quantities.size()>=5 and stack_counts.size()>=3,"generated map lacks quantity/formation variety")
	var saved: Dictionary=JSON.parse_string(JSON.stringify(session.to_dict()))
	check(SaveService.save_session(saved,1)!="","isolated generated save failed")
	var restored=SaveService.restore_manual_session(1)
	check(restored!=null,"generated save restore failed")
	if restored!=null:
		check(JSON.parse_string(JSON.stringify(restored.overworld.encounters))==saved.overworld.encounters,"restored guard identities/armies changed")
	var battle_cases := []
	for index in range(mini(5,guards.size())):
		var probe=Store.new_session_data()
		probe.from_dict(saved)
		var encounter: Dictionary=guards[index]
		var battle := Battle.create_battle_payload(probe,encounter)
		var stacks := []
		for stack in battle.get("stacks",[]):
			if String(stack.get("side",""))=="enemy": stacks.append({"unit_id":stack.unit_id,"count":int(stack.base_count)})
		check(stacks==encounter.enemy_army.stacks,"actual battle creation changed encounter roster")
		battle_cases.append({"placement_id":encounter.placement_id,"stacks":stacks})
	AppRouter.go_to_overworld()
	await settle()
	await capture("opening-normal-fog")
	var shell=get_tree().current_scene
	if shell!=null and shell.get("_map_view")!=null:
		var view=shell._map_view
		for encounter in rendered_guards:
			var asset := String(encounter.generated_neutral_profile.asset_id)
			check(view._encounter_identity_asset_id(encounter)==asset,"renderer selected another identity")
			check(view._object_texture_for_asset(asset) is Texture2D,"renderer has no original raster")
		# Diagnostic scouting reveals art at real placements; no object is moved.
		# Keep normal-fog opening evidence separately and do not save this state.
		var explored := []
		for y in range(session.overworld.map.size()):
			var row := []
			for x in range(session.overworld.map[y].size()): row.append(true)
			explored.append(row)
		session.overworld.fog.explored_tiles=explored
		session.overworld.fog.visible_tiles=explored.duplicate(true)
		shell._refresh()
		await settle()
		for index in range(mini(3,guards.size())):
			var encounter: Dictionary=guards[index * guards.size() / mini(3,guards.size())]
			view.focus_on_tile(Vector2i(int(encounter.x),int(encounter.y)))
			await settle()
			await capture("guard-region-%d-diagnostic" % index)
	finish({"size":size,"seed":seed,"guard_count":guards.size(),"identities":identities.size(),"identity_counts":identity_counts,"supplemental_identities":supplemental_ids.keys(),"quantities":quantities.size(),"stack_counts":stack_counts.keys(),"compositions":compositions.size(),"guards":rows,"battle_cases":battle_cases,"screenshots":"normal-fog opening and explicitly scouted diagnostic regions; original placements unchanged"})
func finish(report: Dictionary) -> void:
	report["checks"]=checks
	report["failures"]=failures
	report["ok"]=failures.is_empty()
	print("NEUTRAL_MAP_REPORT "+JSON.stringify(report))
	get_tree().quit(0 if failures.is_empty() else 1)
'''

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--size',choices=['medium','large'],required=True)
    p.add_argument('--render',action='store_true')
    p.add_argument('--resolution',default='1280x720')
    p.add_argument('--label',required=True)
    a=p.parse_args()
    out=OUTPUT/a.label
    out.mkdir(parents=True,exist_ok=False)
    with tempfile.TemporaryDirectory(prefix='probe-',dir=out.parent) as work,tempfile.TemporaryDirectory(prefix='heroes-neutral-map-user-') as user,preserve_generated_map_files(a.size):
        work=Path(work)
        (work/'probe.gd').write_text(SCRIPT)
        scene=work/'probe.tscn'
        scene.write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="probe.gd" id="1"]\n[node name="Probe" type="Node"]\nscript=ExtResource("1")\n')
        env=probe_environment(dict(os.environ,XDG_DATA_HOME=user,XDG_CONFIG_HOME=user,XDG_CACHE_HOME=user,NEUTRAL_OUT=str(out),NEUTRAL_SIZE=a.size,TOWN_OVERLAY_RESOLUTION=a.resolution))
        cmd=['godot','--path',str(ROOT),'--audio-driver','Dummy','--accessibility','disabled','--quit-after','600','--resolution',a.resolution]
        if a.render: cmd=['xvfb-run','-a','-s','-screen 0 '+a.resolution+'x24']+cmd+['--rendering-method','gl_compatibility']
        else: cmd+=['--headless']
        cmd+=['res://'+str(scene.relative_to(ROOT))]
        with (out/'runtime.log').open('w') as log:
            code=run_probe(cmd,env,log)
        output=(out/'runtime.log').read_text()
        lines=[x.partition('NEUTRAL_MAP_REPORT ')[2] for x in output.splitlines() if x.startswith('NEUTRAL_MAP_REPORT ')]
        report=json.loads(lines[-1]) if lines else {'ok':False,'failures':['no runtime report']}
        report['exit_code']=code
        report['ok']=report['ok'] and code==0 and 'SCRIPT ERROR' not in output and 'ERROR:' not in output
        (out/'report.json').write_text(json.dumps(report,indent=2)+'\n')
        print(json.dumps({k:v for k,v in report.items() if k not in ('guards','battle_cases')}))
        return 0 if report['ok'] else 1

if __name__=='__main__': raise SystemExit(main())
