#!/usr/bin/env python3
"""Mireclaw variant art batch: real authored opening orders and labeled fixtures.

The seven developed compositions and six isolated build controls are detached
fixtures, not earned progression. Two existing authored scenarios also exercise
their naturally offered Moonbite orders without any injected state. This probe
reuses the existing input, complete-save and isolated package adapters.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import sys
import tempfile

import town_scene_layer_regression as layers
import town_overlay_ownership_regression as overlay

ROOT, OUTPUT = layers.ROOT, layers.OUTPUT
IDS = ['building_floodtide_forge', 'building_nightglass_dominion',
       'building_smugglers_flotilla', 'building_mireclaw_hollowreed_moonwax_ossuary',
       'building_mireclaw_moonbite_votive_drum_court', 'building_mireclaw_moonbite_mirehorn_chain_pen']
AUTHORED_ORDERS = {
    'votivejaw-moonbite-drum-trial': IDS[4],
    'votivejaw-moonbite-mirehorn-works': IDS[5],
}

BODY = r'''
func save_variant(label: String) -> void:
	var before: Dictionary=normalized(session.to_dict())
	var path: String=SaveService.save_session(session.to_dict(),3)
	check(path!="","variant save failed: "+label)
	if path=="": return
	DirAccess.copy_absolute(path,out.path_join(label+"_save.json"))
	session=SessionState.restore_session(SaveService.load_session(3))
	check(normalized(session.to_dict())==before,"complete variant save/resume changed: "+label)
	AppRouter.go_to_town()
	await settle()
func capture_variant(label: String) -> void:
	await clear_layer_capture_focus()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(label+".png"))
func pay_variant(id: String, label: String) -> void:
	var shell=get_tree().current_scene
	var stage=shell.get_node("%TownStage")
	check(not stage.validation_building_hotspot_summary(id).visible,"unbuilt variant visible: "+id)
	var actions: Array=TownRules.get_build_actions(session).filter(func(a):return a.id=="build:"+id and not a.get("disabled",true) and a.get("direct_affordable",true))
	check(actions.size()==1,"variant order not legitimately offered by rules: "+label+" "+id)
	if actions.size()!=1: return
	var prior: Dictionary=normalized(session.to_dict())
	var cost: Dictionary=actions[0].cost
	var prior_ids: Array=TownRules.get_active_town(session).built_buildings.duplicate()
	shell._select_build_action("build:"+id)
	check(shell._selected_build_action_id=="build:"+id and normalized(session.to_dict())==prior,"build selection mutated full state")
	var expected: Dictionary=mireclaw_expected_build(id,actions[0])
	shell._on_confirm_build_pressed()
	await settle()
	session=SessionState.ensure_active_session()
	check(normalized(session.to_dict())==expected,"UI build differs from complete independent rule/recap control: "+label+" "+id)
	var town: Dictionary=TownRules.get_active_town(session)
	check(town.built_buildings==prior_ids+[id],"variant build changed unrelated built ids")
	check(town.last_build_day==session.day,"variant daily limit not consumed")
	check(TownRules.get_build_actions(session).filter(func(a):return String(a.id).begins_with("build:") and not a.get("disabled",true)).is_empty(),"second same-day construction allowed")
	shell._close_town_catalog(false)
	check(stage.validation_building_hotspot_summary(id).visible,"paid variant not visible")
	await save_variant(label)
	await inspect_scene_layers([id])
	await capture_variant(label)
	rows.append({"label":label,"building_id":id,"cost":cost,"day":session.day,"complete_build_control_equal":normalized(session.to_dict())==expected})
func enter_variant() -> void:
	var town: Dictionary=session.overworld.towns.filter(func(t):return t.owner=="player")[0]
	var visit: Dictionary=OverworldRules.set_active_town_visit(session,town.placement_id)
	check(visit.get("ok",false),"authored Town visit unavailable")
	AppRouter.go_to_town()
	await settle()
func run() -> void:
	get_tree().current_scene=null
	out=OS.get_environment("TOWN_OVERLAY_OUTPUT")
	SettingsService.set_presentation_mode("windowed")
	SettingsService.set_presentation_resolution(OS.get_environment("TOWN_OVERLAY_RESOLUTION"))
	var earned: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("TOWN_OVERLAY_SAVE")))
	session=SessionState.restore_session(earned)
	await enter_variant()
	await inspect("unchanged_earned_duskfen")
	await save_variant("unchanged_earned_duskfen")
	# Real authored Day-1 orders: content supplies these prerequisites and stores.
	# No army/resources/ownership/built-id manipulation in this section.
	for scenario_id in __AUTHORED__:
		var created=ScenarioFactory.create_session(scenario_id,"normal",SessionState.LAUNCH_MODE_SKIRMISH)
		session=SessionState.restore_session(created.to_dict())
		await enter_variant()
		await capture_variant("authored_"+scenario_id+"_opening")
		await pay_variant(__AUTHORED__[scenario_id],"authored_"+scenario_id)
	# Detached developed view fixtures: never labeled as legitimate progression.
	var exercised := []
	for town_id in ContentService.get_content_ids(ContentService.TOWNS_PATH):
		var template: Dictionary=ContentService.get_town(town_id)
		if template.faction_id!="faction_mireclaw": continue
		var catalog: Array=template.starting_building_ids.duplicate()
		for id in template.buildable_building_ids:
			if id not in catalog: catalog.append(id)
		var fixture: Dictionary=earned.duplicate(true)
		var town: Dictionary=fixture.overworld.towns.filter(func(t):return t.owner=="player")[0]
		town.town_id=town_id
		town.built_buildings=catalog.duplicate()
		town.built_buildings=OverworldRules._normalize_built_buildings_for_town_state(town)
		session=SessionState.restore_session(fixture)
		await enter_variant()
		var shell=get_tree().current_scene
		var stage=shell.get_node("%TownStage")
		var entries: Array=stage._town_building_scene_entries(stage._town_scene_rect())
		var visible := []
		for entry in entries:
			var id: String=entry.visible_building_id
			if id=="" or entry.embedded_in_base: continue
			visible.append(id)
			check(entry.scene_layer and entry.source_contained and entry.destination_contained,"variant still has catalog/floating cropped bounds: "+town_id+" "+id)
			check(stage.validation_building_hotspot_summary(id).visible,"variant hotspot missing: "+id)
		await inspect("fixture_"+town_id+"_developed")
		await save_variant("fixture_"+town_id+"_developed")
		if town_id=="town_moonbite_reedshrine":
			await inspect_scene_layers(visible)
			await capture_variant("fixture_"+town_id+"_final_input")
		rows.append({"label":"detached_developed_not_earned_progression","town_id":town_id,"visible_ids":visible})
		for id in __IDS__:
			if id not in catalog or id in exercised: continue
			# Independent isolated construction control. Only fixture setup edits
			# resources/prerequisites; the actual paid action is the shipped ledger.
			var purchase: Dictionary=fixture.duplicate(true)
			var target: Dictionary=purchase.overworld.towns.filter(func(t):return t.owner=="player")[0]
			target.built_buildings=template.starting_building_ids.duplicate()
			for prerequisite in ContentService.get_building(id).get("requires",[]):
				OverworldRules._append_building_with_requirements(target.built_buildings,prerequisite)
			target.built_buildings=OverworldRules._normalize_built_buildings_for_town_state(target)
			target.last_build_day=0
			for resource in purchase.overworld.resources: purchase.overworld.resources[resource]=100000
			session=SessionState.restore_session(purchase)
			await enter_variant()
			await pay_variant(id,"fixture_paid_"+id)
			exercised.append(id)
	check(exercised.size()==6,"not all six variant identities exercised")
	print("TOWN_OVERLAY_OWNERSHIP "+JSON.stringify({"ok":errors.is_empty(),"checks":checks,"errors":errors,"rows":rows}))
	get_tree().quit(0 if errors.is_empty() else 1)
'''


def script_text():
    helper = layers.mireclaw_script(layers.SCRIPT).split('func mireclaw_expected_build(', 1)[1]
    script = overlay.SCRIPT.split('func run() -> void:', 1)[0] + layers.EXTRA
    script = script.replace('if not ok: errors.append(message)', 'if not ok:\n\t\terrors.append(message)\n\t\tprint("VARIANT_FAILURE "+message)')
    script += '\nfunc mireclaw_expected_build(' + helper
    script += BODY.replace('__IDS__', json.dumps(IDS)).replace('__AUTHORED__', json.dumps(AUTHORED_ORDERS))
    return script


def script_for_resolution(resolution, *, script=None):
    if resolution not in ('1280x720', '1920x1080', '2048x1079'):
        raise ValueError('unsupported capture resolution: ' + resolution)
    script = script_text() if script is None else script
    if resolution == '2048x1079':
        # This annotated size is not a selectable SettingsService preset.
        # Use the established custom-window probe path instead of its fallback.
        script = script.replace(
            'SettingsService.set_presentation_resolution(OS.get_environment("TOWN_OVERLAY_RESOLUTION"))',
            'get_window().content_scale_size = Vector2i(2048,1079)\n\tget_window().size = Vector2i(2048,1079)')
    return script


def main(*, expected_save_sha256=layers.MIRECLAW_FACTION_DEVELOPED_SAVE_SHA256,
         save_description='exact earned Day-51 Duskfen control save',
         script_factory=None, additional_owners=(), description=__doc__):
    parser = argparse.ArgumentParser(description=description, allow_abbrev=False)
    parser.add_argument('--label', required=True)
    parser.add_argument('--save', type=Path, required=True)
    parser.add_argument('--resolution', choices=['1280x720','1920x1080','2048x1079'], required=True)
    args = parser.parse_args()
    if not args.label or any(c not in 'abcdefghijklmnopqrstuvwxyz0123456789_-' for c in args.label):
        parser.error('fresh lowercase label required')
    save = args.save.resolve(strict=True)
    before_hash = hashlib.sha256(save.read_bytes()).hexdigest()
    if before_hash != expected_save_sha256:
        parser.error('requires ' + save_description)
    out = OUTPUT / args.label
    out.mkdir(exist_ok=False)
    owners = ['scenes/town/TownShell.gd','scenes/town/TownStageView.gd','scenes/town/TownBuildingHotspot.gd',
              'scripts/autoload/LiveValidationHarness.gd','content/town_building_scene_art_manifest.json',
              'tests/town_scene_layer_regression.py','tests/town_mireclaw_variant_regression.py']
    owners.extend(additional_owners)
    hashes = {p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in owners}
    with tempfile.TemporaryDirectory(prefix='town-variant-', dir=OUTPUT) as temporary:
        work = Path(temporary)
        (work/'probe.gd').write_text((script_factory or script_for_resolution)(args.resolution))
        scene = work/'probe.tscn'
        scene.write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://%s/probe.gd" id="1"]\n[node name="TownVariant" type="Node"]\nscript = ExtResource("1")\n' % work.relative_to(ROOT))
        command = ['dbus-run-session','--','xvfb-run','-a','-s','-screen 0 2200x1200x24','godot4','--path',str(ROOT),'--audio-driver','Dummy','--accessibility','disabled','--resolution',args.resolution,'res://'+str(scene.relative_to(ROOT))]
        env = dict(os.environ, XDG_DATA_HOME=str(out/'data'), TOWN_OVERLAY_SAVE=str(save), TOWN_OVERLAY_OUTPUT=str(out), TOWN_OVERLAY_RESOLUTION=args.resolution)
        with (out/'runtime.log').open('w') as log:
            code = layers.run_probe(command,env,log,timeout_seconds=900)
    lines = (out/'runtime.log').read_text().splitlines()
    marker = 'TOWN_OVERLAY_OWNERSHIP '
    reports = [json.loads(line[len(marker):]) for line in lines if line.startswith(marker)]
    report = reports[-1] if reports else {'ok':False,'errors':['missing report']}
    report.update(returncode=code, resolution=args.resolution, save_sha256=before_hash,
                  source_hashes=hashes, source_unchanged=hashes=={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in owners},
                  input_unchanged=before_hash==hashlib.sha256(save.read_bytes()).hexdigest(),
                  runtime_errors=[line for line in lines if line.startswith(('ERROR:','SCRIPT ERROR:')) or 'leaked' in line])
    report['ok'] = bool(report['ok']) and code==0 and report['source_unchanged'] and report['input_unchanged'] and not report['runtime_errors']
    (out/'report.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(report))
    return 0 if report['ok'] else 1


if __name__ == '__main__':
    if '--platform' in sys.argv:
        import packaged_town_scene_layer_regression as packaged
        packaged.layers.main = main
        raise SystemExit(packaged.main())
    raise SystemExit(main())
