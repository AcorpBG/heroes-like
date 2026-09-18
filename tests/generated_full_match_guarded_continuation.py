#!/usr/bin/env python3
"""Continue Large/11 through scouted guards and rival hosts with real orders.

This is an explicit validation objective, not an autonomous-player benchmark.
Only revealed cells enter planning. Intermediate interactions are clicked one
at a time; no position, fog, army, reward or resolved encounter is injected.
The ordinary full-match acceptance gate and exact resume history remain intact.
"""
import sys
from pathlib import Path

import generated_full_match_quality as match

GUARDS = ['native_h3maped_c6ffff4f_object_1869',
          'native_h3maped_c6ffff4f_object_1868']

GUIDANCE = r'''
const ContinuationAdventure = preload("res://scripts/core/EnemyAdventureRules.gd")

func known_guard_route(goals: Array) -> Array:
	var start := OverworldRules.hero_position(session)
	var size := OverworldRules.derive_map_size(session)
	var queue := [start]
	var previous := {start:start}
	var cursor := 0
	var finish := Vector2i(-1,-1)
	while cursor < queue.size():
		var here: Vector2i = queue[cursor]
		cursor += 1
		if here in goals:
			finish = here
			break
		for delta in Transit.NAVIGATION_DELTAS:
			var next: Vector2i = here + delta
			if previous.has(next) or next.x < 0 or next.y < 0 or next.x >= size.x or next.y >= size.y:
				continue
			if not OverworldRules.is_tile_visible(session,next.x,next.y) or OverworldRules.tile_step_cuts_blocked_corner(session,here,next):
				continue
			if OverworldRules.tile_is_blocked(session,next.x,next.y) and not OverworldRules.tile_has_route_interaction(session,next.x,next.y,-1,true):
				continue
			# A passage is an order, not an ordinary intermediate floor cell.
			if Transit.is_native(OverworldRules.resource_node_interaction_at_tile(session,next.x,next.y)):
				continue
			previous[next] = here
			queue.append(next)
	if finish.x < 0:
		return []
	var path := [finish]
	while path[0] != start:
		path.push_front(previous[path[0]])
	return path

func known_route_order(path: Array) -> Dictionary:
	var scene = get_tree().current_scene
	if path.is_empty():
		return {}
	var stop: Vector2i = path[-1]
	for point in path.slice(1):
		if OverworldRules.tile_has_route_interaction(session,point.x,point.y):
			stop = point
			break
	# Revalidate each actual click. Never use the potential interaction graph
	# as permission to cross an uncleared guard or unrevealed terrain.
	var live: Array = scene._build_path(OverworldRules.hero_position(session),stop)
	if live.is_empty() or not live.all(func(tile):return OverworldRules.is_tile_visible(session,tile.x,tile.y)):
		stop = path[1] if path.size() > 1 else path[0]
		live = scene._build_path(OverworldRules.hero_position(session),stop)
	if live.is_empty() or not live.all(func(tile):return OverworldRules.is_tile_visible(session,tile.x,tile.y)):
		return {}
	var defender := OverworldRules._engaging_encounter_at_tile(session,stop,Levels.hero_level(session))
	if not defender.is_empty():
		if not known(defender) or power(OverworldRules._encounter_army_payload(defender).get("stacks",[])) > player_power()*0.70:
			return {}
		return {"id":defender.placement_id,"kind":"encounter","tile":stop,"record":defender}
	var node := OverworldRules.resource_node_interaction_at_tile(session,stop.x,stop.y)
	if not node.is_empty():
		if not resource_claim_feasible(node):
			return {}
		return {"id":node.placement_id,"kind":"resource","tile":stop,"record":node}
	for town in scene._validation_targets("town"):
		var entry: Dictionary = town.get("visit_tile",town)
		if Vector2i(int(entry.x),int(entry.y)) == stop:
			if power(town.get("garrison",[])) > player_power()*0.70 and String(town.get("owner","")) != "player":
				return {}
			return {"id":town.placement_id,"kind":"town","tile":stop,"remote":false}
	return {"id":"guard_approach:%d:%d"%[stop.x,stop.y],"kind":"waypoint","tile":stop}

func choose_target() -> Dictionary:
	var management := owned_town_management_target()
	if not management.is_empty():
		return management
	for id in cfg.get("validation_known_guard_objectives", []):
		var rows: Array = session.overworld.encounters.filter(func(row):return String(row.get("placement_id","")) == id)
		if rows.size() != 1:
			failures.append("explicit guard objective is missing or duplicated: "+id)
			return {}
		if OverworldRules.is_encounter_resolved(session,rows[0]):
			continue # Only production battle aftermath can clear the objective.
		var target: Dictionary = rows[0]
		if not known(target) or power(OverworldRules._encounter_army_payload(target).get("stacks",[])) > player_power()*0.70:
			failures.append("explicit guard objective is not scouted and feasible: "+id)
			return {}
		var goals: Array = OverworldRules._guard_engagement_world_tiles(target).filter(func(tile):return OverworldRules.is_tile_visible(session,tile.x,tile.y))
		var path := known_guard_route(goals)
		if path.is_empty():
			failures.append("no revealed potential route to explicit guard: "+id)
			return {}
		var order := known_route_order(path)
		if order.is_empty():
			failures.append("explicit guard segment has no safe legal revealed click route")
		return order
	# A captured rival town does not remove its surviving field commanders.
	# Pursue only currently scouted, feasible hosts, re-reading their live
	# position each order. This is an explicit objective policy, not new AI.
	for target in get_tree().current_scene._validation_targets("encounter"):
		if not known(target) or not ContinuationAdventure.is_active_pressure_host(target,"",session.overworld.resolved_encounters):
			continue
		if power(OverworldRules._encounter_army_payload(target).get("stacks",[])) > player_power()*0.70:
			continue
		var goals: Array = OverworldRules._guard_engagement_world_tiles(target)
		if goals.is_empty():
			goals = [Vector2i(int(target.x),int(target.y))]
		var order := known_route_order(known_guard_route(goals))
		if not order.is_empty():
			return order
	return policy_choose_target()
'''


def compose_driver(script: str) -> str:
    signature = 'func choose_target() -> Dictionary:'
    if script.count(signature) != 1 or 'func policy_choose_target()' in script:
        raise ValueError('requires exactly one unmodified target-policy entrypoint')
    return script.replace(signature, GUIDANCE + '\nfunc policy_choose_target() -> Dictionary:', 1)


def main():
    if '--case' not in sys.argv or sys.argv[sys.argv.index('--case') + 1] != 'quality_large':
        raise SystemExit('known-guard fixture requires --case quality_large')
    if '--resume-run' not in sys.argv:
        raise SystemExit('requires an exact retained complete-match checkpoint')
    match.CASES['quality_large']['validation_known_guard_objectives'] = GUARDS
    match.CASES['quality_large']['validation_known_rival_host_priority'] = True
    match.SCRIPT = compose_driver(match.SCRIPT)
    # Reuse the existing supervised background launcher, but relaunch this
    # fixture entrypoint so its explicit directive/provenance cannot disappear.
    return match.main(background_entrypoint=Path(__file__).resolve())


if __name__ == '__main__':
    raise SystemExit(main())
