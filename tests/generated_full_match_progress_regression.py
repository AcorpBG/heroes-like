#!/usr/bin/env python3
"""Real claim mutations must count as driver progress on already explored tiles.

These are isolated rule/driver controls, not accepted match actions. Python owns
the disposable probe and keeps its XDG saves in temporary storage, not the repo.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import tempfile

from generated_full_match_quality import ROOT, OUTPUT, SCRIPT as MATCH_SCRIPT
from generated_town_order_profile import run_probe

MARKER = 'GENERATED_FULL_MATCH_PROGRESS_REPORT '
CASES = r'''
var checks := 0
var probe_failures := []
var observations := []
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: probe_failures.append(message)
func state() -> Dictionary:
	return JSON.parse_string(JSON.stringify(session.to_dict()))
func fixture(site_id: String = "site_waystone_cache") -> void:
	session = ScenarioFactory.create_session("stonewake-watch", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state(session)
	# Explicit isolated fixture. No accepted match, generated package, save,
	# opponent or action history is edited by these rule controls.
	session.day = 40
	last_progress_day = 38
	var pos := OverworldRules.hero_position(session)
	session.overworld.resource_nodes = [{"placement_id":"progress_shared", "site_id":site_id, "x":pos.x, "y":pos.y, "collected":false}]
	session.overworld.artifact_nodes = []
	session.overworld.encounters = []
	session.overworld.resolved_encounters = []
func claim_resource() -> Dictionary:
	return OverworldRules._collect_resource_node_result(session, {"index":0, "node":session.overworld.resource_nodes[0]}, false)
func observe(before: Dictionary, expected: bool, label: String, routed: bool = false) -> void:
	var previous_day := last_progress_day
	var unchanged := state()
	record_target_progress(before, routed)
	check(last_progress_day == (session.day if expected else previous_day), label)
	check(state() == unchanged, label + " observation changed gameplay")
	observations.append({"case":label,"expected_progress":expected,"previous_progress_day":previous_day,"actual_progress_day":last_progress_day})
func run_match() -> void:
	get_tree().current_scene = null
	fixture()
	var unchanged := state()
	var before := target_progress_state()
	check(state() == unchanged, "progress snapshot changed gameplay")
	var result := claim_resource()
	check(bool(result.get("ok",false)) and session.overworld.resource_nodes[0].get("collected",false), "real Waystone Cache claim failed")
	check(target_progress_state().explored == before.explored and target_progress_state().resolved == before.resolved, "cache fixture accidentally advanced old progress criteria")
	observe(before, true, "new cache claim on explored terrain")
	before = target_progress_state()
	last_progress_day = session.day - 1
	result = claim_resource()
	check(not bool(result.get("ok",true)), "already claimed cache unexpectedly paid again")
	observe(before, false, "rejected repeated cache claim")
	# Same content, different placement: identity, not inventory uniqueness.
	session.overworld.resource_nodes[0] = session.overworld.resource_nodes[0].duplicate(true)
	session.overworld.resource_nodes[0].placement_id = "second_cache"
	session.overworld.resource_nodes[0].collected = false
	session.overworld.resource_nodes[0].erase("collected_by_faction_id")
	result = claim_resource()
	check(bool(result.get("ok",false)), "second cache control failed")
	observe(before, true, "different placement despite equal claimed count")

	fixture("site_ridge_quarry")
	session.overworld.resource_nodes[0].collected = true
	session.overworld.resource_nodes[0].collected_by_faction_id = "faction_mireclaw"
	before = target_progress_state()
	result = claim_resource()
	check(bool(result.get("ok",false)) and session.overworld.resource_nodes[0].collected_by_faction_id == "player", "real enemy quarry reclaim failed")
	observe(before, true, "enemy-held persistent mine reclaimed")
	before = target_progress_state()
	last_progress_day = session.day - 1
	result = claim_resource()
	check(not bool(result.get("ok",true)), "already owned quarry unexpectedly reclaimed")
	observe(before, false, "unchanged owned mine visit")
	# Recurring service bookkeeping/income is not a new claimed identity.
	session.day += 1
	session.overworld.resource_nodes[0].collected_day = session.day
	session.overworld.resources.gold += 100
	session.overworld.movement.current = 0
	observe(before, false, "repeat visit day income and movement alone")

	fixture()
	result = claim_resource()
	check(bool(result.get("ok",false)), "shared-id resource control failed")
	var pos := OverworldRules.hero_position(session)
	session.overworld.artifact_nodes = [{"placement_id":"progress_shared","artifact_id":"artifact_trailsinger_boots","x":pos.x,"y":pos.y,"collected":false}]
	before = target_progress_state()
	result = OverworldRules._collect_artifact_node_result(session, {"index":0,"node":session.overworld.artifact_nodes[0]}, false)
	check(bool(result.get("ok",false)) and session.overworld.artifact_nodes[0].get("collected",false), "real artifact claim failed")
	check(target_progress_state().explored == before.explored and target_progress_state().resolved == before.resolved, "artifact fixture accidentally advanced old progress criteria")
	observe(before, true, "artifact and resource identities are category scoped")
	before = target_progress_state()
	last_progress_day = session.day - 1
	result = OverworldRules._collect_artifact_node_result(session, {"index":0,"node":session.overworld.artifact_nodes[0]}, false)
	check(not bool(result.get("ok",true)), "already claimed artifact unexpectedly paid again")
	observe(before, false, "rejected repeated artifact claim")
	# Another physical cache with the same artifact still gets consumed normally.
	session.overworld.artifact_nodes[0] = session.overworld.artifact_nodes[0].duplicate(true)
	session.overworld.artifact_nodes[0].placement_id = "duplicate_artifact_cache"
	session.overworld.artifact_nodes[0].collected = false
	session.overworld.artifact_nodes[0].erase("collected_by_faction_id")
	result = OverworldRules._collect_artifact_node_result(session, {"index":0,"node":session.overworld.artifact_nodes[0]}, false)
	check(bool(result.get("ok",false)), "duplicate inventory artifact cache control failed")
	observe(before, true, "new cache for an already owned artifact")

	fixture()
	before = target_progress_state()
	session.overworld.resource_nodes[0].collected = true
	session.overworld.resource_nodes[0].collected_by_faction_id = "faction_mireclaw"
	observe(before, false, "enemy claim is not player progress")
	session.overworld.resource_nodes[0].collected_by_faction_id = "player"
	session.overworld.resource_nodes[0].collected = false
	observe(before, false, "owner without completed claim")
	session.overworld.resource_nodes[0].collected = true
	session.overworld.resource_nodes[0].placement_id = ""
	observe(before, false, "missing placement identity")
	session.overworld.resource_nodes.clear()
	observe(before, false, "removed unclaimed object")
	before = target_progress_state()
	session.overworld.fog.explored_count = int(before.explored) + 1
	observe(before, true, "existing exploration progress")
	before = target_progress_state()
	last_progress_day = session.day - 1
	session.overworld.resolved_encounters.append("isolated_resolved_control")
	observe(before, true, "existing resolved battle progress")
	before = target_progress_state()
	last_progress_day = session.day - 1
	observe(before, true, "existing routed encounter progress", true)
	before = target_progress_state()
	last_progress_day = session.day - 15
	observe(before, false, "genuine no-progress horizon remains expired")
	check(session.day - last_progress_day > 14, "genuine stall no longer exceeds unchanged horizon")
	print("GENERATED_FULL_MATCH_PROGRESS_REPORT " + JSON.stringify({"ok":probe_failures.is_empty(),"checks":checks,"failures":probe_failures,"observations":observations,"scope":"isolated real claim rules and actual driver progress condition; not a full match"}))
	get_tree().quit(0 if probe_failures.is_empty() else 1)
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--label', required=True)
    args = parser.parse_args()
    if not args.label or any(c not in 'abcdefghijklmnopqrstuvwxyz0123456789_-' for c in args.label):
        parser.error('label must be a fresh lowercase slug')
    out = OUTPUT / args.label
    out.mkdir(parents=True, exist_ok=False)
    # Keep all driver methods, including its real progress condition; only the
    # match launcher is replaced by the explicit isolated rule cases above.
    script = MATCH_SCRIPT.replace('func run_match() -> void:', 'func unused_full_match() -> void:', 1) + CASES
    with tempfile.TemporaryDirectory(prefix='match-progress-', dir=OUTPUT) as temporary, tempfile.TemporaryDirectory(prefix='heroes-progress-data-') as data:
        work = Path(temporary)
        (work/'probe.gd').write_text(script)
        scene = work/'probe.tscn'
        scene.write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://%s" id="1"]\n[node name="ProgressProbe" type="Node"]\nscript = ExtResource("1")\n' % (work/'probe.gd').relative_to(ROOT))
        env = dict(os.environ, XDG_DATA_HOME=data)
        with (out/'runtime.log').open('w') as log:
            returncode = run_probe(['godot4','--headless','--path',str(ROOT),'--audio-driver','Dummy','--accessibility','disabled','res://'+str(scene.relative_to(ROOT))],env,log)
    lines = (out/'runtime.log').read_text().splitlines()
    reports = [json.loads(line[len(MARKER):]) for line in lines if line.startswith(MARKER)]
    report = reports[-1] if reports else {'ok':False,'failures':['missing report']}
    errors = [line for line in lines if line.startswith(('ERROR:','SCRIPT ERROR:')) or 'leaked' in line]
    report.update(returncode=returncode,runtime_errors=errors,driver_sha256=hashlib.sha256(MATCH_SCRIPT.encode()).hexdigest())
    report['ok'] = bool(report['ok']) and returncode == 0 and not errors
    (out/'report.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(report))
    return 0 if report['ok'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
