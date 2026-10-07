#!/usr/bin/env python3
"""Count reads of selected GDScript static functions for diagnostic probes.

`instrument` rewrites a copy of a script so that each named static function is
wrapped with a call counter in `measured_reads`. Probes load the rewritten copy
from a temporary directory; the project script itself is never changed.
"""
import re

# Path-surface reads in EnemyAdventureRules (multi-level path surfaces and
# hero sightings).
MEASURED = ['_path_distance_surface_cache_key', '_path_distance_resource_fingerprint',
            '_path_distance_encounter_fingerprint', '_path_distance_hero_fingerprint',
            '_overworld_body_blocked_tiles', '_impassable_terrain_tiles',
            '_enemy_hero_sighting_sources', '_player_hero_snapshots_for_intercept',
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
