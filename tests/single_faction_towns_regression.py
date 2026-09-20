"""Bounded six-template catalog, legacy save and town-construction checks."""
import argparse
import json
from pathlib import Path

from unified_mines_regression import ROOT, run_probe


def inspect_content():
    read = lambda name: json.loads((ROOT / 'content' / (name + '.json')).read_text(encoding='utf-8'))
    towns = read('towns')
    rows = towns['items']
    aliases = towns['legacy_aliases']
    index = {t['id']: t for t in rows}
    buildings = {b['id']: b for b in read('buildings')['items']}
    assert len(rows) == len({t['faction_id'] for t in rows}) == 6
    assert len(aliases) == 26 and not set(aliases) & set(index)
    assert set(aliases.values()) <= set(index)
    for faction in read('factions')['items']:
        assert faction['town_ids'] == [faction['seed_town_id']]
        assert index[faction['seed_town_id']]['faction_id'] == faction['id']
    for town in rows:
        reachable = set(town['starting_building_ids'])
        remaining = set(town['buildable_building_ids'])
        while remaining:
            next_ids = set()
            for bid in remaining:
                building = buildings[bid]
                requires = set(building.get('requires', []))
                if building.get('upgrade_from'):
                    requires.add(building['upgrade_from'])
                if requires <= reachable and building.get('faction_id', town['faction_id']) == town['faction_id']:
                    next_ids.add(bid)
            assert next_ids, (town['id'], sorted(remaining))
            remaining -= next_ids
            reachable |= next_ids
    for building in buildings.values():
        contract = building.get('artifact_reward_contract', {})
        assert set(contract.get('allowed_town_ids', [])) <= set(index)
        assert not contract.get('excluded_town_ids')
    catalog = (ROOT / 'docs/wiki/catalog.js').read_text(encoding='utf-8')
    catalog = json.loads(catalog.split('window.WIKI_CATALOG = ', 1)[1].removesuffix(';\n'))
    wiki_towns = {e['id'] for e in catalog['entries'] if e['category'] == 'towns'}
    assert wiki_towns == set(index)
    print('Content: six templates, 26 aliases, all construction prerequisites reachable, six wiki towns.')


SCRIPT = r'''extends Node
const Factory = preload("res://scripts/core/ScenarioFactory.gd")
const Rules = preload("res://scripts/core/OverworldRules.gd")
const Towns = preload("res://scripts/core/TownRules.gd")
const Scenario = preload("res://scripts/core/ScenarioRules.gd")
const Scripts = preload("res://scripts/core/ScenarioScriptRules.gd")
const Store = preload("res://scripts/core/SessionStateStore.gd")
const Bridge = preload("res://scripts/persistence/NativeRandomMapPackageSessionBridge.gd")
var checks:=0
var failures:=[]
class Document extends RefCounted:
	var objects: Array=[]
	func get_object_count(): return objects.size()
	func get_object_by_index(index): return objects[index].duplicate(true)
func check(ok: bool, message: String):
	checks+=1
	if not ok: failures.append(message)
func fixture(town_id: String):
	var session=Factory.create_session("river-pass","normal",SessionState.LAUNCH_MODE_SKIRMISH)
	session.overworld.encounters=[]
	session.overworld.resource_nodes=[]
	session.overworld.map_objects=[]
	session.overworld.artifact_nodes=[]
	session.overworld.towns=[{"placement_id":"legacy_settlement","town_id":town_id,"x":3,"y":3,"owner":"player","built_buildings":ContentService.get_town(town_id).starting_building_ids.duplicate(true),"available_recruits":{"unit_river_guard":17},"garrison":[{"unit_id":"unit_river_guard","count":9}],"artifact_reward_claimed_by_player_id":"player_1","last_build_day":0}]
	Rules._set_active_hero_position(session,Vector2i(3,3),0)
	for id in session.overworld.resources: session.overworld.resources[id]=99999
	Rules.invalidate_spatial_lookup(session)
	Rules.normalize_overworld_state(session)
	return session
func _ready(): call_deferred("run")
func run():
	var raw:Dictionary=ContentService.load_json(ContentService.TOWNS_PATH)
	check(ContentService.get_content_ids(ContentService.TOWNS_PATH).size()==6,"editor catalog still exposes retired templates")
	check(ContentService.get_town("unknown_town").is_empty(),"unknown ID silently resolves")
	for old_id in raw.legacy_aliases:
		var target:String=raw.legacy_aliases[old_id]
		check(is_same(ContentService.get_town(old_id),ContentService.get_town(target)),"legacy lookup differs from canonical "+old_id)
		var session=fixture(old_id)
		var before:Dictionary=session.overworld.towns[0].duplicate(true)
		var saved=Store.SessionData.new()
		saved.from_dict(session.to_dict())
		Rules.normalize_overworld_state(saved)
		var town:Dictionary=saved.overworld.towns[0]
		check(town==before,"save migration changed placed state "+old_id)
		check(Scenario._find_town(saved,{"town_id":old_id}).get("placement_id","")=="legacy_settlement" and Scripts._find_town_result(saved,"",old_id).get("index",-1)==0,"legacy objective/script target lost "+old_id)
	for template in raw.items:
		var session=fixture(template.id)
		var town:Dictionary=session.overworld.towns[0]
		var result:Dictionary=Rules.build_in_active_town(session,"building_market_square")
		check(result.get("ok",false),"canonical town cannot build market "+template.id+": "+str(result))
		check(not Rules.build_in_active_town(session,"building_market_square").ok,"daily/duplicate build restriction lost")
		# Same tree and services for legacy IDs and canonical towns of this faction.
		for old_id in raw.legacy_aliases:
			if raw.legacy_aliases[old_id]!=template.id: continue
			var legacy:=town.duplicate(true)
			legacy.town_id=old_id
			check(Rules.get_town_build_options(town)==Rules.get_town_build_options(legacy),"legacy construction list differs "+old_id)
			legacy.built_buildings=template.starting_building_ids+template.buildable_building_ids
			var canonical:=legacy.duplicate(true)
			canonical.town_id=template.id
			check(Towns._town_artifact_service_actions(session,legacy)==Towns._town_artifact_service_actions(session,canonical),"artifact services differ for legacy town "+old_id)
	var document=Document.new()
	for token in Bridge.H3M_TOWN_TYPE_PROJECT_IDENTITY:
		document.objects.append({"kind":"town","h3maped_faction_id":token,"town_id":Bridge.H3M_TOWN_TYPE_PROJECT_IDENTITY[token].town_id,"placement_id":"source_"+token,"x":7,"y":9,"level":1,"owner":"enemy","owner_slot":2,"player_slot":2,"team_id":"team_2","package_body_tiles":[{"x":7,"y":9,"level":1}],"package_block_tiles":[{"x":7,"y":9,"level":1}],"package_visit_tiles":[{"x":8,"y":9,"level":1}],"visit_tile":{"x":8,"y":9,"level":1}})
	var original:Array=document.objects.duplicate(true)
	var adapted:Array=Bridge._town_states_from_document(document)
	check(document.objects==original,"project-town adoption mutated source records")
	for i in range(adapted.size()):
		var town:Dictionary=adapted[i]
		check(town.town_id==ContentService.canonical_town_id(original[i].town_id),"native adoption produced retired runtime template")
		var intact:=true
		for key in ["placement_id","x","y","level","owner","owner_slot","player_slot","team_id","package_body_tiles","package_block_tiles","package_visit_tiles","visit_tile"]:
			intact=intact and town.get(key)==original[i][key]
		check(intact and town.source_package_town_id==original[i].town_id,"native placement/ownership/source provenance changed")
	ContentService.clear_cache()
	check(ContentService.get_content_ids(ContentService.TOWNS_PATH).size()==6 and ContentService.get_town("town_highwater_keep").id=="town_riverwatch","aliases fail after content reload")
	print("SINGLE_FACTION_TOWNS_REPORT "+JSON.stringify({"checks":checks,"failures":failures}))
	get_tree().quit(0 if failures.is_empty() else 1)
'''


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    inspect_content()
    raise SystemExit(run_probe(SCRIPT, args.godot, args.output, 'SINGLE_FACTION_TOWNS_REPORT'))
