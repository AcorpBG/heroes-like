#!/usr/bin/env python3
"""Observe unchanged native/adopted maps; never adjust placement or retry seeds."""
from pathlib import Path
from collections import Counter, deque
import json
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tests'))
import battle_readability_regression as runner
import rmg_town_supply_removal_regression as boundary

OUTPUT = ROOT / '.artifacts/rmg-guard-space-audit-20260918'
# Reuse real package persistence/provenance and immutable-source assertions.
SCRIPT = boundary.SCRIPT.split('func run() -> void:')[0] + r'''
func write_json(name: String, value: Variant) -> void:
	var file := FileAccess.open(out.path_join(name), FileAccess.WRITE)
	check(file != null, "cannot write " + name)
	if file != null: file.store_string(JSON.stringify(value))
func spatial(session) -> Dictionary:
	var size := OverworldRules.derive_map_size(session)
	var blocked := []
	var actions := {}
	for bucket in ["towns", "resource_nodes", "artifact_nodes", "encounters"]:
		for row in session.overworld.get(bucket, []):
			for tile in row.get("package_visit_tiles", [row.get("visit_tile", row)]):
				actions["%d,%d" % [tile.x,tile.y]] = true
	var squares := []
	var largest := {"x":0,"y":0,"side":0}
	for y in range(size.y):
		var line := []
		for x in range(size.x):
			var wall := OverworldRules.tile_is_blocked(session,x,y,0)
			if wall: blocked.append([x,y])
			var side := 0
			if not wall and not actions.has("%d,%d" % [x,y]):
				side = 1
				if x>0 and y>0: side += mini(int(line[x-1]),mini(int(squares[y-1][x]),int(squares[y-1][x-1])))
			line.append(side)
			if side>int(largest.side):largest={"x":x-side+1,"y":y-side+1,"side":side}
		squares.append(line)
	return {"blocked":blocked,"largest_open_action_free_square":largest}
func capture(view, name: String, tile: Vector2i) -> void:
	view.focus_on_tile(tile)
	for frame in range(4): await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		check(get_viewport().get_texture().get_image().save_png(out.path_join(name+".png")) == OK,"capture " + name)
func reproduce_bypass(session, label: String) -> Dictionary:
	var paths := {
		"medium-10":[[9,58],[8,59],[9,60]],
		"large-11":[[48,23],[47,22],[46,21],[47,20],[48,19],[49,18],[50,18],[51,18],[52,19],[53,20],[52,21],[52,22],[51,23]],
		"large-1":[[30,37],[30,38],[30,39]],
	}
	var before := JSON.stringify(session.to_dict())
	var isolated = Store.new_session_data()
	isolated.from_dict(session.to_dict().duplicate(true))
	var path := []
	for tile in paths[label]:path.append(Vector2i(tile[0],tile[1]))
	# Isolated positioning fixture, not a played journey from the starting town.
	OverworldRules._set_active_hero_position(isolated,path[0],0)
	for tile in path:
		check(not OverworldRules.tile_is_blocked(isolated,tile.x,tile.y,0),label+": bypass tile unexpectedly blocked")
		check(OverworldRules.guard_engagement_encounter_at_tile(isolated,tile.x,tile.y,0).is_empty(),label+": bypass enters guard control")
	var moved: Dictionary = OverworldRules.try_move_along_route(isolated,path)
	check(bool(moved.get("ok",false)),label+": production route rejected diagnosed bypass")
	check(OverworldRules.hero_position(isolated)==path[-1],label+": bypass did not finish")
	check(isolated.game_state=="overworld",label+": bypass triggered battle")
	check(JSON.stringify(session.to_dict())==before,label+": diagnostic mutated original session")
	return {"path":paths[label],"movement_ok":moved.get("ok",false),"final_position":isolated.overworld.hero_position,"game_state":isolated.game_state,"isolated_start_relocation":true}
func run() -> void:
	out = OS.get_environment("BATTLE_READABILITY_OUT")
	SettingsService.set_presentation_mode("windowed")
	SettingsService.set_presentation_resolution("1920x1080")
	get_window().size=Vector2i(1920,1080)
	var service = ClassDB.instantiate("MapPackageService")
	var configs := [["medium","10"],["large","11"],["large","1"]]
	for index in range(configs.size()):
		var row: Array = configs[index]
		var label := "%s-%s" % [row[0],row[1]]
		print("AUDIT_START " + label)
		var config := Select.build_random_map_player_config(row[1],"","",2,"land",false,"homm3_"+row[0],Select.RANDOM_MAP_TEMPLATE_SELECTION_MODE_CATALOG_AUTO,"faction_embercourt","")
		# Historical known-bug cases used the prior menu's weak native setup.
		config["monster_strength"] = "weak"
		var generated: Dictionary = service.generate_random_map(config)
		check(bool(generated.get("ok",false)), label+": generation failed " + String(generated.get("error_code","")))
		if not generated.get("ok",false): continue
		var adoption: Dictionary = service.convert_generated_payload(generated,{"feature_gate":"guard_space_audit","session_save_version":Store.SAVE_VERSION})
		check(bool(adoption.get("ok",false)),label+": adoption failed")
		if not adoption.get("ok",false):continue
		var session = persisted(service,adoption,generated,config,index)
		check(session != null,label+": disk startup failed")
		if session == null:continue
		verify(session,adoption,label)
		var repeated = Bridge.build_session_from_adoption(adoption)
		check(normalized(session.overworld.resource_nodes)==normalized(repeated.overworld.resource_nodes),label+": resource adoption drift")
		check(normalized(session.overworld.encounters)==normalized(repeated.overworld.encounters),label+": guard adoption drift")
		var grid := spatial(session)
		var bypass := reproduce_bypass(session,label)
		write_json(label+"-state.json",{"config":config,"normalized_config":generated.get("normalized_config",{}),"native_payload_hash":generated.get("final_payload_fnv1a32",""),"native_payload_bytes":generated.get("final_payload_byte_count",0),"native_objects":Bridge._document_objects(adoption.map_document),"overworld":session.to_dict().overworld,"grid":grid,"bypass":bypass,"boundary":adoption.get("session_boundary_record",{})})
		SessionState.set_active_session(session)
		var shell = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
		add_child(shell)
		for frame in range(8):await get_tree().process_frame
		var view = shell.get_node("%Map")
		await capture(view,label+"-start",OverworldRules.hero_position(session))
		# Explicit inspection-only reveal, after recording the untouched map state.
		var size := OverworldRules.derive_map_size(session)
		var tiles := []
		for y in range(size.y):
			var line := []
			for x in range(size.x):line.append(true)
			tiles.append(line)
		session.overworld.fog={"explored_tiles":tiles,"visible_tiles":tiles.duplicate(true),"explored_count":size.x*size.y,"visible_count":size.x*size.y,"total_tiles":size.x*size.y}
		view.set_map_state(session,session.overworld.map,size,OverworldRules.hero_position(session))
		var square: Dictionary = grid.largest_open_action_free_square
		await capture(view,label+"-empty",Vector2i(square.x+square.side/2,square.y+square.side/2))
		var native_guard := {}
		var supplemental := {}
		for guard in session.overworld.encounters:
			if guard.has("generated_package_guard_policy") and supplemental.is_empty():supplemental=guard
			elif native_guard.is_empty():native_guard=guard
		if not supplemental.is_empty():await capture(view,label+"-supplemental",Vector2i(supplemental.x,supplemental.y))
		if not native_guard.is_empty():await capture(view,label+"-native-guard",Vector2i(native_guard.x,native_guard.y))
		var bypass_tile: Array = bypass.path[1]
		await capture(view,label+"-lost-blocker-bypass",Vector2i(bypass_tile[0],bypass_tile[1]))
		var scenery: Dictionary = view.validation_generated_object_visual_summary()
		write_json(label+"-scenery.json",scenery)
		cases.append({"case":label,"source_objects":adoption.map_document.get_object_count(),"guards":session.overworld.encounters.size(),"resources":session.overworld.resource_nodes.size(),"largest_open_action_free_square":square,"scenery":scenery.duplicate(true)})
		cases[-1].scenery.erase("body_entries")
		cases[-1].scenery.erase("resource_entries")
		cases[-1].scenery.erase("legacy_primary_marker_candidates")
		shell.queue_free()
		for frame in range(4):await get_tree().process_frame
		print("AUDIT_COMPLETE " + label)
	check(cases.size()==configs.size(),"not all audit cases completed")
	print("BATTLE_READABILITY_REPORT " + JSON.stringify({"ok":failures.is_empty(),"checks":checks,"failures":failures,"cases":cases,"scope":"diagnostic, not gameplay quality or parity acceptance"}))
	get_tree().quit(0 if failures.is_empty() else 1)
'''


def points(rows, key):
    return {(int(t['x']), int(t['y'])) for row in rows for t in row.get(key, [])
            if int(t.get('level', 0)) == 0}


def neighbors(point):
    x, y = point
    return [(x + dx, y + dy) for dy in (-1, 0, 1) for dx in (-1, 0, 1)
            if dx or dy]


def components(cells):
    """Native ground-only eight-way adjacency, no clears, battles or transit."""
    remaining = set(cells)
    labels = {}
    component = 0
    while remaining:
        start = min(remaining)
        remaining.remove(start)
        queue = deque([start])
        labels[start] = component
        while queue:
            for tile in neighbors(queue.popleft()):
                if tile in remaining:
                    remaining.remove(tile)
                    labels[tile] = component
                    queue.append(tile)
        component += 1
    return labels


def shortest_path(cells, start, end):
    if start not in cells or end not in cells:
        return []
    parents = {start: None}
    queue = deque([start])
    while queue:
        current = queue.popleft()
        if current == end:
            result = []
            while current is not None:
                result.append(current)
                current = parents[current]
            return result[::-1]
        for tile in neighbors(current):
            if tile in cells and tile not in parents:
                parents[tile] = current
                queue.append(tile)
    return []


def analyze(data):
    world = data['overworld']
    collections = ('towns', 'resource_nodes', 'artifact_nodes', 'encounters', 'map_objects')
    adopted = {r['placement_id'] for key in collections for r in world.get(key, [])}
    missing = [r for r in data['native_objects'] if r['placement_id'] not in adopted]
    blocked = {tuple(t) for t in data['grid']['blocked']}
    lost = points(missing, 'package_block_tiles')
    opened = lost - blocked
    native = [g for g in world['encounters'] if not g.get('generated_package_guard_policy')]
    supplements = [g for g in world['encounters'] if g.get('generated_package_guard_policy')]
    control = points(world['encounters'], 'package_guard_engagement_tiles')
    native_control = points(native, 'package_guard_engagement_tiles')
    actions = points([r for key in collections for r in world.get(key, [])], 'package_visit_tiles')
    size = world['map_size']
    walkable = {(x, y) for y in range(int(size['height'])) for x in range(int(size['width']))} - blocked - control - actions
    live_components = components(walkable)
    source_components = components(walkable - lost)
    bypasses = []
    for guard in native:
        gx, gy = int(guard['x']), int(guard['y'])
        ring = sorted((gx + dx, gy + dy) for dy in range(-2, 3) for dx in range(-2, 3)
                      if max(abs(dx), abs(dy)) == 2 and (gx + dx, gy + dy) in source_components)
        pairs = [(a, b) for n, a in enumerate(ring) for b in ring[n + 1:]
                 if source_components[a] != source_components[b] and live_components[a] == live_components[b]]
        if not pairs:
            continue
        a, b = min(pairs, key=lambda pair: (sum(abs(x-y) for x,y in zip(*pair)), pair))
        path = shortest_path(walkable, a, b)
        bypasses.append({'guard_id': guard['placement_id'], 'guard_xy': [gx, gy],
                         'path': path, 'opened_cells_used': sorted(set(path) & opened)})
    return {
        'source_objects': len(data['native_objects']), 'missing_objects': len(missing),
        'missing_type_counts': dict(sorted(Counter(r['h3m_type_id'] for r in missing).items())),
        'missing_block_cells': len(lost), 'source_block_cells_now_walkable': len(opened),
        'missing_object_examples': [{k: r.get(k) for k in ('placement_id', 'h3m_type_id', 'h3m_def_name', 'x', 'y', 'native_authored_pool_resolution_status')} for r in missing[:3]],
        'native_guards': len(native), 'supplemental_guards': len(supplements),
        'supplemental_guard_policies': dict(Counter(g['generated_package_guard_policy'] for g in supplements)),
        'native_guards_touching_lost_blocking': sum(bool(points([g], 'package_guard_engagement_tiles') & opened) for g in native),
        'supplemental_guards_inside_native_control': sum((int(g['x']), int(g['y'])) in native_control for g in supplements),
        'ground_components_live': len(set(live_components.values())),
        'ground_components_with_source_masks': len(set(source_components.values())),
        'bypass_examples': sorted(bypasses, key=lambda r: (len(r['path']), r['guard_id']))[:3],
        'guards_with_new_ground_bypass': len(bypasses),
        'scope': 'Ground-only diagnostic; all guard controls and action tiles closed; no battles, collections or portals. Source-mask restoration is analytical only, never a runtime edit.',
    }


if __name__ == '__main__':
    if len(sys.argv) == 3 and sys.argv[1] == '--analyze':
        directory = Path(sys.argv[2])
        result = {p.stem.removesuffix('-state'): analyze(json.loads(p.read_text()))
                  for p in sorted(directory.glob('*-state.json'))}
        if not result:
            raise SystemExit('No audit snapshots found')
        (directory / 'analysis.json').write_text(json.dumps(result, indent=2) + '\n')
        print(json.dumps(result, indent=2))
        raise SystemExit(0)
    runner.OUTPUT, runner.SCRIPT = OUTPUT, SCRIPT
    raise SystemExit(runner.main())
