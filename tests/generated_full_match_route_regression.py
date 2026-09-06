#!/usr/bin/env python3
"""Exercise the match driver's real animated battle/report handoff, not a match."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import tempfile

from generated_full_match_quality import ROOT, OUTPUT, SCRIPT as MATCH_SCRIPT
from generated_town_order_profile import run_probe

CASES = r'''
var probe_errors := []
var observations := []
func check(ok: bool, message: String) -> void:
	if not ok:
		probe_errors.append(message)
func open_fixture() -> void:
	session=SessionState.set_active_session(ScenarioFactory.create_session("river-pass","normal",SessionState.LAUNCH_MODE_SKIRMISH))
	OverworldRules.normalize_overworld_state(session)
	var encounter: Dictionary=session.overworld.encounters.filter(func(e):return e.placement_id=="river_pass_hollow_mire")[0]
	session.battle=BattleRules.create_battle_payload(session,encounter)
	session.game_state="battle"
	session.battle.retreat_allowed=true
	AppRouter.go_to_battle()
	await settle()
func run_match() -> void:
	get_tree().current_scene=null
	out=OS.get_environment("HEROES_FULL_MATCH_OUTPUT")
	action_file=FileAccess.open(out.path_join("actions.jsonl"),FileAccess.WRITE)
	SettingsService.set_presentation_mode("windowed")
	SettingsService.set_presentation_resolution("1280x720")
	await open_fixture()
	var scene=get_tree().current_scene
	var request: Dictionary=scene.validation_request_withdrawal("retreat")
	var result: Dictionary=scene.validation_confirm_withdrawal()
	check(request.get("ok",false) and result.get("ok",false),"real withdrawal fixture could not commit")
	check(scene._battle_exit_handoff_in_progress,"fixture did not exercise the asynchronous exit animation")
	var before: Dictionary=JSON.parse_string(JSON.stringify(session.to_dict()))
	await resolve_routes()
	observations.append({"case":"animated_exit","driver_failures":failures.duplicate(),"counts":counts.duplicate(),"scene":scene_path()})
	check(failures.is_empty(),"driver treated a pending animation as another battle: "+str(failures))
	check(int(counts.get("battle",0))==0 and int(counts.get("battle_report",0))==1,"driver repeated Quick Resolve or skipped the casualty report")
	check(scene_path().ends_with("OverworldShell.tscn"),"animated handoff did not reach the actual Overworld")
	check(BattleRules.pending_battle_report(session).is_empty(),"casualty report was not acknowledged")
	var after: Dictionary=JSON.parse_string(JSON.stringify(session.to_dict()))
	check(after.overworld.army==before.overworld.army and after.overworld.resources==before.overworld.resources,"handoff changed resolved troops or resources: "+JSON.stringify({"before_army":before.overworld.army,"after_army":after.overworld.army,"before_resources":before.overworld.resources,"after_resources":after.overworld.resources}))
	# A genuine active battle must still execute the shipped confirmation flow.
	failures.clear();counts.clear()
	await open_fixture()
	await resolve_routes()
	observations.append({"case":"ordinary_quick_resolve","driver_failures":failures.duplicate(),"counts":counts.duplicate(),"scene":scene_path()})
	check(failures.is_empty() and int(counts.get("battle",0))==1 and int(counts.get("battle_report",0))==1,"ordinary Quick Resolve/report flow regressed")
	# Do not turn an actual unavailable action into an accepted handoff.
	failures.clear();counts.clear()
	await open_fixture()
	session.battle={}
	await resolve_routes()
	check("shipped Quick Resolve failed" in failures,"genuine unavailable battle no longer fails driver validation")
	observations.append({"case":"unavailable_control","expected_driver_failures":failures.duplicate()})
	print("GENERATED_MATCH_ROUTE_REGRESSION "+JSON.stringify({"ok":probe_errors.is_empty(),"failures":probe_errors,"observations":observations}))
	get_tree().quit(0 if probe_errors.is_empty() else 1)
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--label', required=True)
    args = parser.parse_args()
    if not args.label or any(c not in 'abcdefghijklmnopqrstuvwxyz0123456789_-' for c in args.label):
        parser.error('label must be a fresh lowercase slug')
    out = OUTPUT / args.label
    out.mkdir(parents=True, exist_ok=False)
    script_text = MATCH_SCRIPT[:MATCH_SCRIPT.index('func run_match()')] + CASES
    with tempfile.TemporaryDirectory(prefix='match-route-', dir=OUTPUT) as temporary:
        work = Path(temporary)
        script = work / 'probe.gd'
        script.write_text(script_text)
        scene = work / 'probe.tscn'
        scene.write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://%s" id="1"]\n[node name="MatchRoutes" type="Node"]\nscript = ExtResource("1")\n' % script.relative_to(ROOT))
        command = ['dbus-run-session', '--', 'xvfb-run', '-a', 'godot4', '--path', str(ROOT), '--audio-driver', 'Dummy', '--accessibility', 'disabled', '--resolution', '1280x720', 'res://' + str(scene.relative_to(ROOT))]
        env = dict(os.environ, XDG_DATA_HOME=str(out / 'data'), HEROES_FULL_MATCH_OUTPUT=str(out))
        with (out / 'runtime.log').open('w') as log:
            code = run_probe(command, env, log)
    lines = (out / 'runtime.log').read_text().splitlines()
    marker = 'GENERATED_MATCH_ROUTE_REGRESSION '
    reports = [json.loads(line[len(marker):]) for line in lines if line.startswith(marker)]
    report = reports[-1] if reports else {'ok': False, 'failures': ['missing report']}
    report.update(returncode=code, driver_sha256=hashlib.sha256(MATCH_SCRIPT.encode()).hexdigest(), runtime_errors=[s for s in lines if s.startswith(('ERROR:', 'SCRIPT ERROR:')) or 'leaked' in s])
    report['ok'] = bool(report['ok']) and code == 0 and not report['runtime_errors']
    (out / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report))
    return 0 if report['ok'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
