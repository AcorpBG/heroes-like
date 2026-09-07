#!/usr/bin/env python3
"""Compare exact original blocker indexes and authoritative package-mask reads."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile

from ai_path_context_read_regression import instrument
from generated_town_order_profile import ROOT, OUTPUT, run_probe

REFERENCE = '34396ac4029725dc8f66e23324986e908a9a5e15'
OWNER = 'scripts/core/OverworldRules.gd'
METHODS = ['_build_blocked_tile_index', '_map_object_for_resource_node',
           '_world_tiles_from_payload_array', 'resource_node_is_present']
SCRIPT = r'''
extends Node
var errors := []
var checks := 0
var rows := []
var original
var current
var require_reuse := false
func _ready() -> void:
	call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		errors.append(label)
func compare(session, label: String, mask_only := false) -> Dictionary:
	var before: String = JSON.stringify(session.to_dict())
	var actors := ["", "missing_actor"]
	if not session.overworld.get("encounters",[]).is_empty():
		actors.append(String(session.overworld.encounters[0].get("placement_id","")))
	var result := {}
	for level in [-1,0,1]:
		for actor in actors:
			original.measured_reads.clear()
			current.measured_reads.clear()
			var old: Dictionary = original._build_blocked_tile_index(session,level,actor)
			result = current._build_blocked_tile_index(session,level,actor)
			var detail: String = label+": level "+str(level)+" actor "+actor
			check(old == result,detail+": every tile and ownership value")
			check(old.keys() == result.keys(),detail+": insertion order")
			check(original.measured_reads.get("resource_node_is_present",{}).get("count",0) == current.measured_reads.get("resource_node_is_present",{}).get("count",0),detail+": same authoritative presence checks")
			if mask_only and require_reuse:
				check(current.measured_reads.get("_map_object_for_resource_node",{}).get("count",0)==0,detail+": no unused content resolution")
			rows.append({"label":detail,"original":original.measured_reads.duplicate(true),"current":current.measured_reads.duplicate(true),"tile_count":result.size()})
	check(before == JSON.stringify(session.to_dict()),label+": full session unchanged")
	return current._build_blocked_tile_index(session,0,"")
func empty_session():
	var session = ScenarioFactory.create_session("three-hearth-auxiliary-charter","normal",SessionState.LAUNCH_MODE_SKIRMISH)
	for name in ["towns","encounters","map_objects","resource_nodes","artifact_nodes","resolved_encounters"]:
		session.overworld[name] = []
	session.overworld.hero_position = {"x":0,"y":0}
	session.overworld.map_size = {"width":16,"height":16,"level_count":2}
	return session
func masks() -> void:
	var session = empty_session()
	var sites := ["missing_site",""]
	for id in ContentService.get_content_ids(ContentService.RESOURCE_SITES_PATH):
		sites.append(id)
	var nodes := []
	for index in range(sites.size()):
		nodes.append({"placement_id":"mask_"+str(index),"site_id":sites[index],"x":index,"y":2,"package_block_tiles":[{"x":index,"y":2}],"body_tiles":[{"x":999,"y":999}],"blocking_body":false})
	session.overworld.resource_nodes = nodes
	compare(session,"all resource site masks",true)
	var row: Dictionary = rows[-2]
	# Select the surface row independently of the actor/level loop ordering.
	for candidate in rows:
		if candidate.label == "all resource site masks: level 0 actor ":
			row = candidate
	check(int(row.original.get("_map_object_for_resource_node",{}).get("count",0)) == nodes.size(),"original resolves every masked resource definition")
	if require_reuse:
		check(int(row.original.get("_world_tiles_from_payload_array",{}).get("count",0)) > int(row.current.get("_world_tiles_from_payload_array",{}).get("count",0)),"positive duplicate decoding eliminated")
	for node in nodes:
		node.collected = true
	var consumed := compare(session,"consumed and persistent site masks",true)
	for index in range(sites.size()):
		var site: Dictionary = ContentService.get_resource_site(sites[index])
		var expected: bool = bool(site.get("persistent_control",false)) or bool(site.get("repeatable",false)) or String(site.get("family",""))=="repeatable_service"
		check(consumed.has(str(index)+",2") == expected,"authoritative consumed/persistent site "+sites[index])
	# Each mask is a detached boundary fixture, never a changed map package.
	for payload in [[],["invalid",1,null], [{}], [{"x":-1,"y":-2}], [{"x":1.8,"y":2.9}], [{"x":1,"y":2},{"x":1,"y":2}], [{"x":4,"y":5,"level":1}], null, "invalid", {}]:
		session.overworld.resource_nodes = [{"placement_id":"boundary","site_id":"missing_site","object_id":"missing_object","x":3,"y":4,"blocking_body":true,"package_block_tiles":payload,"body_tiles":[{"x":7,"y":8}],"object_footprint_catalog_ref":{"fixture":true}}]
		compare(session,"boundary mask "+JSON.stringify(payload),payload is Array)
		session.overworld.resource_nodes[0].collected = true
		compare(session,"consumed boundary "+JSON.stringify(payload),payload is Array)
	# Authoritative mask changes must be seen on the very next call.
	session.overworld.resource_nodes = [{"placement_id":"fresh","package_block_tiles":[{"x":4,"y":5}]}]
	check(compare(session,"fresh mask",true).has("4,5"),"initial occupied tile")
	session.overworld.resource_nodes[0].package_block_tiles[0].x = 6
	var moved := compare(session,"mutated mask",true)
	check(not moved.has("4,5") and moved.has("6,5"),"no retained stale mask cache")
	session.overworld.resource_nodes[0].package_block_tiles.clear()
	check(compare(session,"cleared mask",true).is_empty(),"explicit empty mask never falls through to body tile")
func authored() -> void:
	var session = empty_session()
	var nodes := []
	for id in ContentService.get_content_ids(ContentService.MAP_OBJECTS_PATH):
		var object: Dictionary = ContentService.get_map_object(id)
		nodes.append({"placement_id":"authored_"+id,"object_id":id,"site_id":object.get("resource_site_id",""),"x":nodes.size(),"y":8})
	session.overworld.resource_nodes = nodes
	compare(session,"every authored direct object without mask")
	for node in nodes:
		node.object_id = "missing_object"
	compare(session,"every authored resource-site fallback without mask")
	for node in nodes:
		node.package_block_tiles = []
	compare(session,"every authored explicit empty mask",true)
func overlap() -> void:
	var session = empty_session()
	var node := {"placement_id":"native_door","x":4,"y":5,"collected":true,"package_block_tiles":[{"x":4,"y":5}],"native_transit":{"schema_version":1,"kind":"paired_cave"}}
	check(original.NativeTransit.is_native(node),"fixture recognized by original native identity owner")
	session.overworld.resource_nodes = [node]
	check(compare(session,"native exclusive mask",true).get("4,5")=="native_door","native ownership token retained after collected flag")
	session.overworld.towns = [{"placement_id":"town_wall","package_block_tiles":[{"x":4,"y":5}]}]
	check(compare(session,"native overlaps town",true).get("4,5")==true,"native overlap not exclusively owned")
	session.overworld.towns = []
	session.overworld.encounters = [{"placement_id":"door_guard","x":4,"y":5}]
	compare(session,"native overlaps actor",true)
	check(current._build_blocked_tile_index(session,0,"door_guard").get("4,5")=="native_door","actor exclusion restores exact exclusive ownership")
	session.overworld.resolved_encounters = ["door_guard"]
	check(compare(session,"resolved actor",true).get("4,5")=="native_door","resolved guard does not block passage")
	session.overworld.map_objects = [{"kind":"decorative_obstacle","x":4,"y":5}]
	check(compare(session,"native overlaps scenery",true).get("4,5")==true,"scenery overlap remains blocked")
	session.overworld.resource_nodes.append(node.duplicate(true))
	session.overworld.map_objects = []
	check(compare(session,"duplicate native masks",true).get("4,5")==true,"duplicate placement overlap not exclusively owned")
	node.level = 1
	compare(session,"changed node level",true)
func run() -> void:
	original = load(OS.get_environment("BLOCK_MASK_ORIGINAL"))
	current = load(OS.get_environment("BLOCK_MASK_CURRENT"))
	require_reuse = OS.get_environment("BLOCK_MASK_REQUIRE_REUSE")=="1"
	check(original._build_blocked_tile_index(null)==current._build_blocked_tile_index(null),"null session")
	for id in ["three-hearth-auxiliary-charter","bogbound-oath","three-banner-field-commission","rootway-graftmarch","ashen-clausemarch","false-channel-pursuit"]:
		var session = ScenarioFactory.create_session(id,"normal",SessionState.LAUNCH_MODE_SKIRMISH)
		OverworldRules.normalize_overworld_state(session)
		compare(session,id)
	var path := OS.get_environment("BLOCK_MASK_SAVE")
	if path != "":
		var session = SessionState.restore_session(JSON.parse_string(FileAccess.get_file_as_string(path)))
		var all_masks := true
		for node in session.overworld.resource_nodes:
			all_masks = all_masks and node.get("package_block_tiles") is Array
		compare(session,"actual generated day "+str(session.day),all_masks)
	masks()
	authored()
	overlap()
	print("OVERWORLD_BLOCKED_MASK_REGRESSION "+JSON.stringify({"ok":errors.is_empty(),"checks":checks,"errors":errors,"rows":rows}))
	get_tree().quit(0 if errors.is_empty() else 1)
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--label', required=True)
    parser.add_argument('--save', type=Path)
    parser.add_argument('--require-mask-reuse', action='store_true')
    args = parser.parse_args()
    if not re.fullmatch('[a-z0-9_-]+', args.label):
        parser.error('label must be a fresh lowercase slug')
    out = OUTPUT / args.label
    out.mkdir(parents=True, exist_ok=False)
    original = subprocess.check_output(['git','show',f'{REFERENCE}:{OWNER}'],cwd=ROOT).decode()
    current = (ROOT/OWNER).read_text()
    saved = args.save.read_bytes() if args.save else None
    if saved:
        json.loads(saved)
        (out/'input_save.json').write_bytes(saved)
    with tempfile.TemporaryDirectory(prefix='block-masks-',dir=OUTPUT) as temp:
        work = Path(temp)
        for name, source in [('original',original),('current',current)]:
            (work/(name+'.gd')).write_text(instrument(source,methods=METHODS,terrain=False))
        (work/'probe.gd').write_text(SCRIPT)
        scene = work/'probe.tscn'
        scene.write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://%s" id="1"]\n[node name="BlockMasks" type="Node"]\nscript = ExtResource("1")\n' % (work/'probe.gd').relative_to(ROOT))
        env = dict(os.environ,XDG_DATA_HOME=str(out/'data'),BLOCK_MASK_ORIGINAL='res://'+str((work/'original.gd').relative_to(ROOT)),BLOCK_MASK_CURRENT='res://'+str((work/'current.gd').relative_to(ROOT)),BLOCK_MASK_SAVE=str(out/'input_save.json') if saved else '',BLOCK_MASK_REQUIRE_REUSE='1' if args.require_mask_reuse else '0')
        with (out/'runtime.log').open('w') as log:
            code = run_probe(['godot4','--headless','--path',str(ROOT),'--audio-driver','Dummy','--accessibility','disabled','res://'+str(scene.relative_to(ROOT))],env,log)
    lines = (out/'runtime.log').read_text().splitlines()
    marker = 'OVERWORLD_BLOCKED_MASK_REGRESSION '
    reports = [json.loads(line[len(marker):]) for line in lines if line.startswith(marker)]
    report = reports[-1] if reports else {'ok':False,'errors':['missing report']}
    report.update(returncode=code,reference_revision=REFERENCE,reference_sha256=hashlib.sha256(original.encode()).hexdigest(),current_sha256=hashlib.sha256(current.encode()).hexdigest(),save_sha256=hashlib.sha256(saved).hexdigest() if saved else None,runtime_errors=[line for line in lines if line.startswith(('ERROR:','SCRIPT ERROR:')) or 'leaked' in line])
    report['ok'] = bool(report['ok']) and code==0 and not report['runtime_errors']
    (out/'report.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({k:v for k,v in report.items() if k!='rows'}))
    return 0 if report['ok'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
