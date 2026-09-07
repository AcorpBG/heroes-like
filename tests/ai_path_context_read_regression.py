#!/usr/bin/env python3
"""Exact old-owner path contexts and request-local fingerprint work counts."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile

from generated_town_order_profile import ROOT, OUTPUT, run_probe

REFERENCE = '65fb7fcb6ccd5f9bb017c185c82e161e7216ad87'
OWNER = 'scripts/core/EnemyAdventureRules.gd'
OVERWORLD = 'scripts/core/OverworldRules.gd'
MEASURED = ['_path_distance_surface_cache_key', '_path_distance_resource_fingerprint',
            '_path_distance_encounter_fingerprint', '_path_distance_hero_fingerprint',
            '_overworld_body_blocked_tiles', '_impassable_terrain_tiles',
            '_enemy_hero_sighting_sources', '_player_hero_snapshots_for_intercept',
            '_target_candidates_from_descriptors', '_native_navigation_surface',
            '_path_distance_surface_context']


def instrument(source, methods=MEASURED, terrain=True):
    # A complete independent script, not a subclass whose inherited static
    # calls could silently bypass the selected owner. Only wrappers count time.
    source = re.sub(r'^class_name [^\n]+\n', '', source, count=1)
    wrappers = '\nstatic var measured_reads := {}\n'
    for name in methods:
        matches = list(re.finditer(r'static func '+name+r'\((.*?)\) -> (\w+):\n', source, re.S))
        if len(matches) != 1:
            raise ValueError('review changed method header: '+name)
        match = matches[0]
        args = ', '.join(p.strip().split(':', 1)[0] for p in match[1].split(','))
        source = source[:match.start()]+source[match.start():].replace('static func '+name+'(', 'static func measured_original'+name+'(', 1)
        wrappers += match[0]+f'''\tvar started := Time.get_ticks_usec()
\tvar result: {match[2]} = measured_original{name}({args})
\tvar row: Dictionary = measured_reads.get("{name}", {{"count": 0, "usec": 0}})
\trow.count += 1
\trow.usec += Time.get_ticks_usec() - started
\tmeasured_reads["{name}"] = row
\treturn result
'''
    if not terrain:
        return source+wrappers
    anchor = 'OverworldRulesScript.terrain_id_is_passable(terrain_id)'
    if source.count(anchor) != 1:
        raise ValueError('review terrain passability call ownership')
    source = source.replace(anchor, 'measured_terrain_passable(terrain_id)')
    wrappers += '''
static func measured_terrain_passable(terrain_id: String) -> bool:
\tvar row: Dictionary = measured_reads.get("terrain_passability", {"count": 0})
\trow.count += 1
\tmeasured_reads["terrain_passability"] = row
\treturn OverworldRulesScript.terrain_id_is_passable(terrain_id)
'''
    return source+wrappers


SCRIPT = r'''
extends Node
var errors := []
var checks := 0
var rows := []
var original
var current
var require_once := false
func _ready() -> void:
	call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		errors.append(label)
func clear(owner) -> void:
	owner._path_distance_surface_cache.clear()
	owner._native_navigation_surface_cache.clear()
func compare(session, actor: String, observer: String, level: int, label: String, cold := false) -> Dictionary:
	if cold:
		clear(original)
		clear(current)
	var before: String = JSON.stringify(session.to_dict())
	for owner in [original,current]:
		owner.OverworldRulesScript.invalidate_spatial_lookup(session)
		owner.OverworldRulesScript._refresh_blocked_tile_index(session)
		owner.OverworldRulesScript.measured_reads.clear()
	original.measured_reads.clear()
	current.measured_reads.clear()
	var started := Time.get_ticks_usec()
	var old: Dictionary = original._path_distance_surface_context(session,actor,observer,level)
	var old_us := Time.get_ticks_usec()-started
	started = Time.get_ticks_usec()
	var now: Dictionary = current._path_distance_surface_context(session,actor,observer,level)
	var current_us := Time.get_ticks_usec()-started
	check(old == now,label+": every context/mask/link/cache field")
	check(before == JSON.stringify(session.to_dict()),label+": full session unchanged")
	check(original._path_distance_surface_cache.keys() == current._path_distance_surface_cache.keys(),label+": exact local cache keys/order")
	check(original._native_navigation_surface_cache.keys() == current._native_navigation_surface_cache.keys(),label+": exact navigation keys/order")
	var count := int(current.measured_reads.get("_path_distance_surface_cache_key",{}).get("count",0))
	check(count >= 1,label+": recomputes identity on every new request")
	if require_once:
		check(count == 1,label+": only one fingerprint per synchronous request")
		if cold and actor != "":
			check(int(current.OverworldRulesScript.measured_reads.get("_build_blocked_tile_index",{}).get("count",0)) <= current.LevelRules.level_count(session),label+": strict actor-excluded index built at most once per level")
	rows.append({"label":label,"original_usec":old_us,"current_usec":current_us,"original":original.measured_reads.duplicate(true),"current":current.measured_reads.duplicate(true),"original_occupancy":original.OverworldRulesScript.measured_reads.duplicate(true),"current_occupancy":current.OverworldRulesScript.measured_reads.duplicate(true)})
	# Exercise actual path-field mutation and exact selected distance/next step.
	var position: Dictionary = session.overworld.get("hero_position",{})
	var start := Vector2i(int(position.get("x",0)),int(position.get("y",0)))
	for goals in [[start],[start+Vector2i(1,0)],[Vector2i(1,1),Vector2i(2,2)]]:
		check(original._path_distance_with_context(old,start,goals) == current._path_distance_with_context(now,start,goals),label+": exact distance")
		check(original._path_plan_toward(session,start,goals,actor,observer,level) == current._path_plan_toward(session,start,goals,actor,observer,level),label+": exact next step")
	check(old == now,label+": exact populated path fields")
	check(before == JSON.stringify(session.to_dict()),label+": path queries preserve full session")
	return now
func basic(session, label: String) -> void:
	var configs: Array = EnemyTurnRules._enemy_faction_configs_for_session(session)
	var observer := String(configs[0].get("player_id",configs[0].get("faction_id",""))) if not configs.is_empty() else ""
	var actor := String(session.overworld.encounters[0].get("placement_id","")) if not session.overworld.get("encounters",[]).is_empty() else ""
	compare(session,actor,observer,-1,label+": cold",true)
	compare(session,actor,observer,-1,label+": warm")
	compare(session,"",observer,0,label+": different actor")
	compare(session,actor,"",0,label+": different observer")
	# Each mutation is deliberately in a detached fixture, never match evidence.
	session.day += 1
	compare(session,actor,observer,0,label+": day freshness")
	if not session.overworld.get("resource_nodes",[]).is_empty():
		var node: Dictionary = session.overworld.resource_nodes[0]
		node.collected = not bool(node.get("collected",false))
		compare(session,actor,observer,0,label+": collected-state freshness")
	if session.overworld.get("encounters",[]).size()>1:
		var encounter: Dictionary = session.overworld.encounters[1]
		encounter.x = int(encounter.get("x",0))+1
		compare(session,actor,observer,0,label+": moved army freshness")
		session.overworld.resolved_encounters.append(String(encounter.get("placement_id","")))
		compare(session,actor,observer,0,label+": resolved army freshness")
	if session.overworld.get("hero_position") is Dictionary:
		session.overworld.hero_position.x = int(session.overworld.hero_position.get("x",0))+1
		for hero in session.overworld.get("player_heroes",[]):
			if hero is Dictionary and hero.get("position") is Dictionary:
				hero.position.x = int(hero.position.get("x",0))+1
		compare(session,actor,observer,0,label+": moved player hero freshness")
	# Direct private entry points retain their independent fresh-key behavior.
	check(original._local_path_distance_surface_context(session,actor,observer) == current._local_path_distance_surface_context(session,actor,observer),label+": standalone local")
	check(original._native_navigation_surface(session,actor,observer) == current._native_navigation_surface(session,actor,observer),label+": standalone native")
func native_fixture() -> void:
	var session = ScenarioFactory.create_session("three-hearth-auxiliary-charter","normal",SessionState.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state(session)
	session.flags.native_random_map_package_session_adoption = true
	session.overworld.map_size = {"x":8,"y":8,"width":8,"height":8,"level_count":2}
	session.overworld.map = []
	for y in range(8):
		session.overworld.map.append(["grass","grass","grass","grass","grass","grass","grass","grass"])
	var codes := []
	codes.resize(64)
	codes.fill(0)
	session.overworld.terrain_layers = {"terrain_id_by_code":["grass"],"terrain":{"levels":[codes,codes.duplicate()]}}
	for name in ["encounters","towns","map_objects","artifact_nodes","player_heroes"]:
		session.overworld[name] = []
	# Two reciprocal original-runtime contracts in an explicitly synthetic test.
	var nodes := []
	for level in [0,1]:
		var entry := {"x":1,"y":1,"level":level}
		var exit := {"x":1,"y":1,"level":1-level}
		var id := "path_read_cave_%d" % level
		nodes.append({"placement_id":id,"x":1,"y":1,"level":level,"h3m_type_id":103,"package_visit_tiles":[entry],"native_transit":{"schema_version":1,"kind":"paired_cave","source_function":"0x4a6cf2","one_way":false,"source_placement_id":id,"target_placement_id":"path_read_cave_%d" % (1-level),"group_id":"path_read_pair","entry":entry,"exit":exit}})
	session.overworld.resource_nodes = nodes
	OverworldRules.invalidate_spatial_lookup(session)
	OverworldRules._refresh_blocked_tile_index(session)
	check(current.NativeTransit.validate(nodes).is_empty(),"two-level fixture has valid native contracts")
	var surface := compare(session,"","",0,"native two-level surface",true)
	check(bool(surface.get("native_navigation",{}).get("ok",false)),"valid native navigation remains available")
	check(surface.get("native_navigation",{}).get("links",[]).size()==2,"safe reciprocal passages preserved")
	var old_surface: Dictionary = original._path_distance_surface_context(session,"","",0)
	var old_plan: Dictionary = original._native_navigation_plan(old_surface,Vector2i(1,1),[Vector2i(1,1)],1)
	var current_plan: Dictionary = current._native_navigation_plan(surface,Vector2i(1,1),[Vector2i(1,1)],1)
	check(old_plan == current_plan and int(current_plan.get("goal_distance",9999))==1,"exact usable cross-level passage step")
	compare(session,"","",1,"native underground")
	compare(session,"","",1,"native underground warm")
	# Existing safety owners must continue rejecting a genuinely occupied door.
	session.overworld.encounters = [{"placement_id":"path_read_door_guard","x":1,"y":1,"level":1}]
	OverworldRules.invalidate_spatial_lookup(session)
	OverworldRules._refresh_blocked_tile_index(session)
	var occupied := compare(session,"","",0,"occupied native passage",true)
	check(occupied.get("native_navigation",{}).get("links",[]).is_empty(),"occupied door remains unsafe both directions")
	var actor_surface := compare(session,"path_read_door_guard","",1,"actor on native doorway",true)
	check(actor_surface.get("native_navigation",{}).get("links",[]).size()==2,"only moving actor is removed from doorway safety")
	var actor_row: Dictionary = rows[-1]
	if require_once:
		check(int(actor_row.original_occupancy.get("_build_blocked_tile_index",{}).get("count",0)) > int(actor_row.current_occupancy.get("_build_blocked_tile_index",{}).get("count",0)),"positive original duplicate strict-index construction reproduced")
	session.overworld.map_objects = [{"placement_id":"path_read_overlapping_rock","x":1,"y":1,"level":1,"blocking_body":true}]
	var overlap := compare(session,"path_read_door_guard","",1,"actor overlapping native doorway blocker",true)
	check(overlap.get("native_navigation",{}).get("links",[]).is_empty(),"actor removal never removes overlapping blocker")
	for owner in [original,current]:
		clear(owner)
	# Bad contracts still fail closed; fixture reload clears pre-existing caches.
	nodes[0].native_transit.schema_version = 9
	var invalid := compare(session,"","",1,"invalid native contract",true)
	check(invalid.get("native_navigation",{}).get("error","")=="invalid_native_navigation_contracts","invalid contract never becomes guessed local path")
func terrain_fixture() -> void:
	var session = ScenarioFactory.create_session("three-hearth-auxiliary-charter","normal",SessionState.LAUNCH_MODE_SKIRMISH)
	var ids := ["","missing_test_terrain","rock","water"," highland ","hills","ridge","badlands","wastes","cavern","underway","coast","shore"]
	for id in ContentService.get_content_ids(ContentService.BIOMES_PATH):
		for terrain_id in ContentService.get_biome(id).get("map_tile_ids",[]):
			if not String(terrain_id) in ids:
				ids.append(String(terrain_id))
	for round in range(2):
		var repeated := []
		for index in range(4):
			repeated.append_array(ids)
		session.overworld.map = [repeated, "malformed row", [], ids.duplicate()]
		var before: String = JSON.stringify(session.to_dict())
		original.measured_reads.clear()
		current.measured_reads.clear()
		check(original._impassable_terrain_tiles(session) == current._impassable_terrain_tiles(session),"all catalog/alias/unknown/malformed terrain exact blocked tiles")
		var old_count := int(original.measured_reads.get("terrain_passability",{}).get("count",0))
		var count := int(current.measured_reads.get("terrain_passability",{}).get("count",0))
		check(old_count == ids.size()*5,"exact original per-cell control")
		check(count > 0,"passability recomputed on every separate scan")
		if require_once:
			check(count == ids.size(),"one authoritative passability read per raw terrain id")
		check(before == JSON.stringify(session.to_dict()),"terrain scan preserves complete session")
		ids.reverse()
	check(original._impassable_terrain_tiles(null)==current._impassable_terrain_tiles(null),"null terrain read preserved")
func run() -> void:
	original = load(OS.get_environment("PATH_READ_ORIGINAL"))
	current = load(OS.get_environment("PATH_READ_CURRENT"))
	original.OverworldRulesScript = load(OS.get_environment("PATH_READ_OVERWORLD_ORIGINAL"))
	current.OverworldRulesScript = load(OS.get_environment("PATH_READ_OVERWORLD_CURRENT"))
	require_once = OS.get_environment("PATH_READ_REQUIRE_ONCE")=="1"
	for id in ["three-hearth-auxiliary-charter","bogbound-oath","three-banner-field-commission","rootway-graftmarch","ashen-clausemarch","false-channel-pursuit"]:
		var session = ScenarioFactory.create_session(id,"normal",SessionState.LAUNCH_MODE_SKIRMISH)
		OverworldRules.normalize_overworld_state(session)
		EnemyTurnRules.normalize_enemy_states(session)
		basic(session,id)
	var saved_path := OS.get_environment("PATH_READ_SAVE")
	if saved_path != "":
		var session = SessionState.restore_session(JSON.parse_string(FileAccess.get_file_as_string(saved_path)))
		basic(session,"actual generated day "+str(session.day))
	native_fixture()
	terrain_fixture()
	print("AI_PATH_CONTEXT_READ_REGRESSION "+JSON.stringify({"ok":errors.is_empty() and checks>300,"checks":checks,"errors":errors,"rows":rows}))
	get_tree().quit(0 if errors.is_empty() else 1)
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--label', required=True)
    parser.add_argument('--save', type=Path)
    parser.add_argument('--require-key-once', action='store_true')
    args = parser.parse_args()
    if not re.fullmatch('[a-z0-9_-]+', args.label):
        parser.error('label must be a fresh lowercase slug')
    out = OUTPUT/args.label
    out.mkdir(parents=True, exist_ok=False)
    original = subprocess.check_output(['git','show',f'{REFERENCE}:{OWNER}'],cwd=ROOT).decode()
    current = (ROOT/OWNER).read_text()
    old_overworld = subprocess.check_output(['git','show',f'{REFERENCE}:{OVERWORLD}'],cwd=ROOT).decode()
    current_overworld = (ROOT/OVERWORLD).read_text()
    saved = args.save.read_bytes() if args.save else None
    if saved:
        json.loads(saved)
        (out/'input_save.json').write_bytes(saved)
    with tempfile.TemporaryDirectory(prefix='path-reads-',dir=OUTPUT) as temp:
        work = Path(temp)
        for name,source in [('original',original),('current',current)]:
            (work/(name+'.gd')).write_text(instrument(source))
        for name,source in [('overworld_original',old_overworld),('overworld_current',current_overworld)]:
            (work/(name+'.gd')).write_text(instrument(source,methods=['_native_passage_endpoint_safety','_build_blocked_tile_index'],terrain=False))
        (work/'probe.gd').write_text(SCRIPT)
        scene = work/'probe.tscn'
        scene.write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://%s" id="1"]\n[node name="PathReads" type="Node"]\nscript = ExtResource("1")\n' % (work/'probe.gd').relative_to(ROOT))
        env = dict(os.environ,XDG_DATA_HOME=str(out/'data'),PATH_READ_ORIGINAL='res://'+str((work/'original.gd').relative_to(ROOT)),PATH_READ_CURRENT='res://'+str((work/'current.gd').relative_to(ROOT)),PATH_READ_SAVE=str(out/'input_save.json') if saved else '',PATH_READ_REQUIRE_ONCE='1' if args.require_key_once else '0')
        env.update(PATH_READ_OVERWORLD_ORIGINAL='res://'+str((work/'overworld_original.gd').relative_to(ROOT)),PATH_READ_OVERWORLD_CURRENT='res://'+str((work/'overworld_current.gd').relative_to(ROOT)))
        with (out/'runtime.log').open('w') as log:
            code = run_probe(['godot4','--headless','--path',str(ROOT),'--audio-driver','Dummy','--accessibility','disabled','res://'+str(scene.relative_to(ROOT))],env,log)
    lines = (out/'runtime.log').read_text().splitlines()
    marker = 'AI_PATH_CONTEXT_READ_REGRESSION '
    reports = [json.loads(line[len(marker):]) for line in lines if line.startswith(marker)]
    report = reports[-1] if reports else {'ok':False,'errors':['missing report']}
    report.update(returncode=code,reference_revision=REFERENCE,reference_sha256=hashlib.sha256(original.encode()).hexdigest(),current_sha256=hashlib.sha256(current.encode()).hexdigest(),save_sha256=hashlib.sha256(saved).hexdigest() if saved else None,runtime_errors=[line for line in lines if line.startswith(('ERROR:','SCRIPT ERROR:')) or 'leaked' in line])
    report.update(reference_overworld_sha256=hashlib.sha256(old_overworld.encode()).hexdigest(),current_overworld_sha256=hashlib.sha256(current_overworld.encode()).hexdigest())
    report['ok'] = bool(report['ok']) and code==0 and not report['runtime_errors']
    (out/'report.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({k:v for k,v in report.items() if k!='rows'}))
    return 0 if report['ok'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
