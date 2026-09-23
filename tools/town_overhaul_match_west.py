#!/usr/bin/env python3
"""Portable full-match runner using production scene orders and Quick Resolve.

This extends the established generated-match player policy with observations;
it never grants resources, reveals fog, edits armies, or manufactures outcomes.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / '.artifacts/town_match_west_20260923'


def chronology(out: Path) -> dict:
    path = out / 'actions.jsonl'
    rows = [json.loads(line) for line in path.read_text(encoding='utf-8').splitlines()] if path.exists() else []
    builds, recruits, battles, commerce = [], [], [], []
    previous = {}
    capacity_errors = []
    for row in rows:
        kind, result, state = row['kind'], row['result'], row['state']
        resources = state.get('resources', {})
        event = dict(day=state['day'], action=result.get('id', ''), result=result,
                     resource_delta={key: value-previous.get(key, value) for key, value in resources.items()
                                     if value != previous.get(key, value)})
        if kind == 'town_build':
            builds.append(event)
        elif kind == 'town_recruit':
            recruits.append(event)
        elif kind == 'battle':
            resolved = result.get('confirmation', {}).get('result', {})
            battles.append(dict(day=state['day'], player_power_after=state['army_power'],
                encounter=result.get('request', {}).get('encounter_id'),
                outcome=resolved.get('state'), player_orders=resolved.get('player_orders'),
                message=resolved.get('terminal_result', {}).get('message')))
        if result.get('id', '').startswith(('town_buy:', 'town_sell:', 'market:', 'trade:', 'town_upgrade:')):
            commerce.append(event)
        capacity_errors.extend(state.get('army_capacity', {}).get('violations', []))
        previous = resources
    return dict(actions=len(rows), construction=builds, recruitment=recruits, battles=battles,
                commerce=commerce, capacity_violations=capacity_errors,
                limits=['Only reached tiers and actual transactions support balance conclusions.'])


def driver_script(economy: bool = False) -> str:
    from town_overhaul_match_east import script as economic_orders
    script = economic_orders(economy)
    if economy:
        script = commerce_policy(script)
    script = script.replace('"growth":OverworldRules.town_weekly_growth(town, session),',
        '"growth":OverworldRules.town_weekly_growth(town, session), "income":OverworldRules.town_income(town,session),')
    # Shared policy owns modal admission before End Turn for both runners.
    # Observe the same authoritative town state already used by scene actions.
    script = script.replace('"built": town.get("built_buildings", [])}',
        '"built": town.get("built_buildings", []), "available_recruits":town.get("available_recruits", {}), '
        '"shop_purchases":town.get("artifact_shop_purchases", {}), '
        '"garrison":town.get("garrison", [])}')
    # A buyer does not repeatedly buy/sell the same item in a single visit.
    script = script.replace('if lane != "specialty":\n\t\t\t\tused[selected] = true',
                            'used[selected] = true')
    if not economy:
        script = script.replace('if not bool(action.get("disabled",true)) and not used.has(String(action.id)):',
            'if String(action.id).begins_with("town_sell:"):\n'
            '\t\t\t\t\tcontinue # Retain earned equipment; surplus sale policy needs separate coverage.\n'
            '\t\t\t\tif not bool(action.get("disabled",true)) and not used.has(String(action.id)):')
    script = script.replace('var leave: Dictionary = scene.validation_leave_town()',
        'record("town_catalog",Time.get_ticks_usec(),town_catalog(scene))\n'
        '\tvar leave: Dictionary = scene.validation_leave_town()')
    # Fail before a write if the engine did not honor the isolated OS profile.
    script = script.replace('var action_path := out.path_join("actions.jsonl")',
        'var expected_profile := OS.get_environment("HEROES_MATCH_PROFILE").replace("\\\\", "/").to_lower()\n'
        '\tif not OS.get_user_data_dir().replace("\\\\", "/").to_lower().begins_with(expected_profile):\n'
        '\t\tpush_error("Match profile isolation failed: " + OS.get_user_data_dir())\n'
        '\t\tget_tree().quit(2)\n\t\treturn\n'
        '\tvar action_path := out.path_join("actions.jsonl")')
    return script


def commerce_policy(script: str) -> str:
    """Make a periodic, physically travelled shop visit an ordinary player goal."""
    script = script.replace('last_town_day[id] = session.day',
        'last_town_day[id] = session.day\n'
        '\tif TownEconomy.visiting_active_hero(session,town):\n'
        '\t\twaypoint_visits["commerce:"+id] = session.day')
    script = script.replace('var resupply := reinforcement_target()',
        'var merchant := commerce_visit_target()\n'
        '\tif not merchant.is_empty():\n\t\treturn merchant\n'
        '\tvar resupply := reinforcement_target()')
    script = script.replace('func reinforcement_target() -> Dictionary:', '''func commerce_visit_target() -> Dictionary:
	if int(counts.get("artifact_purchase",0)) >= 2 and int(counts.get("artifact_sale",0)) >= 1:
		return {}
	var scene = get_tree().current_scene
	var origin := OverworldRules.hero_position(session)
	var choices := []
	for town in scene._validation_targets("town"):
		var id := String(town.get("placement_id",""))
		if String(town.get("owner","")) != "player" or not known(town) or int(failed_targets.get(id,0)) >= session.day:
			continue
		if session.day-int(waypoint_visits.get("commerce:"+id,-7)) < 7:
			continue
		var has_exchange := false
		for building in town.get("built_buildings",[]):
			if bool(ContentService.get_building(String(building)).get("artifact_exchange",false)):
				has_exchange = true
		if not has_exchange:
			continue
		var entry: Dictionary = town.get("visit_tile",town)
		var tile := Vector2i(int(entry.x),int(entry.y))
		var path: Array = scene._build_path(origin,tile)
		if origin == tile or path.is_empty() or not path.all(func(point):return OverworldRules.is_tile_visible(session,point.x,point.y)):
			continue
		choices.append({"id":id,"kind":"town","tile":tile,"remote":false,"score":float(path.size())})
	choices.sort_custom(target_precedes)
	return choices[0] if not choices.is_empty() else {}

func reinforcement_target() -> Dictionary:''')
    assert 'var merchant := commerce_visit_target()' in script
    return script


def run(args: argparse.Namespace) -> int:
    out = args.output.resolve() / args.label
    out.mkdir(parents=True, exist_ok=False)
    work = out / 'driver'
    work.mkdir()
    profile = out / 'profile'
    profile.mkdir()
    script = driver_script(args.economy)
    (work / 'driver.gd').write_text(script, encoding='utf-8')
    scene = work / 'driver.tscn'
    scene.write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://%s" id="1"]\n[node name="TownFullMatch" type="Node"]\nscript = ExtResource("1")\n' % (work / 'driver.gd').relative_to(ROOT).as_posix(), encoding='utf-8')
    cfg = dict(seed=args.seed, size=args.size, players=2, faction='faction_'+args.faction,
               hero='', template_selection_mode='native_catalog_auto', monster_strength='normal',
               max_days=args.max_days, defend_until_day=args.defend_until_day,
               core_town_actions=args.core_town_actions)
    if args.resume:
        filename = 'slot2.json' if args.resume_checkpoint == 'mid_match' else 'autosave.json'
        saved_paths = list(args.resume.glob('profile/**/saves/'+filename))
        if len(saved_paths) != 1:
            raise ValueError('Exactly one isolated autosave required')
        saved = saved_paths[0].read_bytes()
        payload = json.loads(saved)
        digest = hashlib.sha256(saved).hexdigest()
        rows = [json.loads(line) for line in (args.resume/'actions.jsonl').read_text(encoding='utf-8').splitlines()]
        matches = [i for i, row in enumerate(rows)
                   if row['kind'] in ['end_turn', 'save_resume'] and row['result'].get('save_sha256') == digest]
        setup = next(row['result'] for row in rows if row['kind'] == 'setup')
        if any(setup.get(key) != cfg[key] for key in ['seed', 'size', 'players']):
            raise ValueError('Resume setup mismatch')
        human = [p for p in payload['overworld']['players'] if p.get('human')]
        if len(human) != 1 or human[0]['faction_id'] != cfg['faction']:
            raise ValueError('Resume faction mismatch')
        if not matches or payload['scenario_status'] != 'in_progress':
            raise ValueError('Autosave lacks exact nonterminal action boundary')
        rows = rows[:matches[-1]+1]
        counts = {}
        for row in rows:
            counts[row['kind']] = counts.get(row['kind'], 0)+1
            aid = row['result'].get('id', '')
            if row['result'].get('ok') and aid.startswith(('town_buy:', 'town_sell:')):
                counter = 'artifact_purchase' if aid.startswith('town_buy:') else 'artifact_sale'
                counts[counter] = counts.get(counter, 0)+1
        cfg['resume'] = dict(rows[-1]['driver_state'], counts=counts,
            checkpoint_labels=[r['result']['label'] for r in rows if r['kind']=='save_resume'],
            serial=rows[-1]['serial'], source=args.resume.name, save_sha256=digest)
        (out/'resume.json').write_bytes(saved)
        (out/'actions.jsonl').write_text(''.join(json.dumps(row)+'\n' for row in rows), encoding='utf-8')
    source = {str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest()
              for base, pattern in [('scripts','*.gd'),('scenes','*.gd'),('content','*.json')]
              for p in (ROOT/base).rglob(pattern)}
    (out/'provenance.json').write_text(json.dumps(dict(config=cfg, source=source,
        driver_sha256=hashlib.sha256(script.encode()).hexdigest()), indent=2), encoding='utf-8')
    env = dict(os.environ, APPDATA=str(profile), XDG_DATA_HOME=str(profile), XDG_CONFIG_HOME=str(profile),
        HEROES_MATCH_PROFILE=str(profile), HEROES_FULL_MATCH_OUTPUT=str(out), HEROES_FULL_MATCH_CONFIG=json.dumps(cfg),
        HEROES_FULL_MATCH_RESOLUTION='1280x720', HEROES_PROFILE_LOG='0')
    cmd = [args.godot, '--headless', '--path', str(ROOT), '--audio-driver', 'Dummy', '--accessibility', 'disabled',
           'res://'+scene.relative_to(ROOT).as_posix()]
    started = time.monotonic()
    with (out/'runtime.log').open('w', encoding='utf-8') as log:
        process = subprocess.Popen(cmd, cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT)
        print(json.dumps(dict(pid=process.pid, output=str(out), config=cfg)), flush=True)
        try:
            code = process.wait(timeout=args.timeout)
        except subprocess.TimeoutExpired:
            process.terminate()
            try:
                process.wait(timeout=15)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
            code = 124
    lines = (out/'runtime.log').read_text(encoding='utf-8', errors='replace').splitlines()
    reports = [json.loads(line.split('GENERATED_FULL_MATCH_REPORT ',1)[1]) for line in lines if line.startswith('GENERATED_FULL_MATCH_REPORT ')]
    report = reports[-1] if reports else dict(ok=False, failures=['No terminal engine report'])
    report.update(returncode=code, wall_seconds=time.monotonic()-started,
                  errors=[line for line in lines if line.startswith(('ERROR:','SCRIPT ERROR:'))])
    report['chronology'] = chronology(out)
    report['ok'] = bool(report['ok'] and code == 0 and not report['errors'])
    (out/'report.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
    print(json.dumps(dict(ok=report['ok'], returncode=code, final=report.get('final'),
        counts=report.get('counts'), failures=report.get('failures'), errors=report['errors'],
        report=str(out/'report.json'))), flush=True)
    return 0 if report['ok'] else 1


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--faction', required=True, choices=['embercourt','mireclaw','sunvault','thornwake','brasshollow','veilmourn'])
    p.add_argument('--label', required=True)
    p.add_argument('--seed', default='10')
    p.add_argument('--economy', action='store_true', help='Use shared eastern legal economic orders policy')
    p.add_argument('--core-town-actions', action='store_true', help='Execute the same paid TownRules actions without town presentation delays')
    p.add_argument('--defend-until-day', type=int, default=0, help='Develop through ordinary town orders before setting out')
    p.add_argument('--resume', type=Path, help='Continue exact completed End Turn autosave and its history')
    p.add_argument('--resume-checkpoint', choices=['autosave','mid_match'], default='autosave')
    p.add_argument('--size', default='homm3_small', choices=['homm3_small','homm3_medium','homm3_large'])
    p.add_argument('--max-days', type=int, default=100)
    p.add_argument('--timeout', type=int, default=3600)
    p.add_argument('--output', type=Path, default=OUTPUT)
    p.add_argument('--godot', default=os.environ.get('GODOT_BIN') or shutil.which('godot4') or shutil.which('godot') or str(ROOT.parent/'Godot_v4.6.2-stable_win64_console.exe'))
    args = p.parse_args()
    if any(c not in 'abcdefghijklmnopqrstuvwxyz0123456789_-' for c in args.label):
        p.error('label must be a fresh lowercase slug')
    return run(args)


if __name__ == '__main__':
    raise SystemExit(main())
