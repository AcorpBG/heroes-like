#!/usr/bin/env python3
"""Serial exact-revision End Turn controls with disposable RAM-backed userdata.

Uses the established actual-handler driver unchanged. Retains gzip full states,
source hashes, reports and rendered captures, not duplicate user-save trees.
"""
import argparse
import gzip
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

from generated_end_turn_profile import BODY, MATCH_SCRIPT
from generated_town_order_profile import ROOT, OUTPUT, run_probe, latency_summary

PRODUCTION_PATHS = ('scripts','scenes','src','bin','art','content','project.godot',
                    'icon.svg','icon.svg.import','export_presets.cfg')


def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT)


def production_dirty():
    return bool(git('diff','HEAD','--',*PRODUCTION_PATHS).strip()
                or git('ls-files','--others','--exclude-standard','--',*PRODUCTION_PATHS).strip())


def reference_files(reference):
    # Replace every changed runtime script/scene, never an arbitrary subset.
    # Native/content/art/config changes need a separately imported/built reference.
    changed = sorted(git('diff','--name-only',reference,'HEAD','--',*PRODUCTION_PATHS).decode().splitlines())
    if not changed or any(not name.startswith(('scripts/','scenes/')) or Path(name).suffix not in ('.gd','.tscn') for name in changed):
        raise ValueError('reference must differ only in runtime scripts/scenes; review native, content, art or configuration changes separately')
    for name in changed:
        if not (ROOT/name).is_file() or subprocess.run(['git','cat-file','-e',reference+':'+name],cwd=ROOT,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL).returncode!=0:
            raise ValueError('added/deleted runtime files require a separate reference project: '+name)
    if production_dirty():
        raise ValueError('production worktree must match HEAD for this exact-revision comparison')
    return changed


def run_case(destination, save, resolution, sources, reference):
    destination.mkdir()
    with tempfile.TemporaryDirectory(prefix='heroes-turn-pair-', dir='/dev/shm') as temporary:
        work = Path(temporary)
        project = work / 'project'
        project.mkdir()
        for name in ('project.godot', 'icon.svg', 'icon.svg.import', '.godot', 'art', 'bin', 'content', 'src'):
            (project/name).symlink_to(ROOT/name, target_is_directory=(ROOT/name).is_dir())
        shutil.copytree(ROOT/'scripts', project/'scripts')
        shutil.copytree(ROOT/'scenes', project/'scenes')
        for name, data in sources.items():
            (project/name).write_bytes(data)
        (project/'probe.gd').write_text(MATCH_SCRIPT[:MATCH_SCRIPT.index('func run_match()')]+BODY)
        (project/'probe.tscn').write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://probe.gd" id="1"]\n[node name="Turns" type="Node"]\nscript = ExtResource("1")\n')
        output = work/'result'
        output.mkdir()
        (output/'input_save.json').write_bytes(save)
        env = dict(os.environ, XDG_DATA_HOME=str(work/'data'), XDG_CACHE_HOME=str(work/'cache'), TURN_PROFILE_OUTPUT=str(output), TURN_PROFILE_RESOLUTION=resolution, HEROES_PROFILE_LOG='1', HEROES_STRATEGIC_AI_PROFILE='1')
        with (destination/'runtime.log').open('w') as log:
            code = run_probe(['dbus-run-session','--','xvfb-run','-a','-s','-screen 0 2200x1200x24','godot4','--path',str(project),'--audio-driver','Dummy','--accessibility','disabled','res://probe.tscn'], env, log)
        lines = (destination/'runtime.log').read_text().splitlines()
        marker = 'GENERATED_END_TURN_PROFILE '
        reports = [json.loads(line[len(marker):]) for line in lines if line.startswith(marker)]
        report = reports[-1] if len(reports)==1 else {'ok':False,'failures':['expected one driver report']}
        report.update(returncode=code, reference_revision=reference, source_sha256={name:hashlib.sha256(data).hexdigest() for name,data in sources.items()}, save_sha256=hashlib.sha256(save).hexdigest(), runtime_errors=[line for line in lines if line.startswith(('ERROR:','SCRIPT ERROR:')) or 'leaked' in line])
        report['latency'] = latency_summary(report.get('rows', []))
        report['states'] = {}
        for path in sorted(output.glob('state_*.json')):
            data = path.read_bytes()
            report['states'][path.name] = hashlib.sha256(data).hexdigest()
            (destination/(path.name+'.gz')).write_bytes(gzip.compress(data, mtime=0))
        for name in ('turn_before.png','turn_after.png'):
            if (output/name).exists():
                shutil.copy2(output/name, destination/name)
        report['captures_present'] = all((destination/name).is_file() for name in ('turn_before.png','turn_after.png'))
        report['ok'] = bool(report['ok']) and code==0 and not report['runtime_errors'] and len(report['states'])==4 and report['captures_present']
        (destination/'report.json').write_text(json.dumps(report,indent=2)+'\n')
        print(json.dumps({'case':destination.name,'ok':report['ok'],'latency':report['latency'],'runtime_errors':report['runtime_errors']}), flush=True)
        return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--label', required=True)
    parser.add_argument('--save', type=Path, required=True)
    parser.add_argument('--reference', required=True)
    parser.add_argument('--resolution', choices=('1280x720','1920x1080'), required=True)
    args = parser.parse_args()
    if not re.fullmatch('[a-z0-9_-]+',args.label) or not re.fullmatch('[0-9a-f]{40}',args.reference):
        parser.error('fresh lowercase label and exact 40-character reference commit required')
    try:
        changed = reference_files(args.reference)
    except ValueError as error:
        parser.error(str(error))
    save = args.save.read_bytes()
    json.loads(save)
    destination = OUTPUT/args.label
    destination.mkdir(exist_ok=False)
    current = {name:(ROOT/name).read_bytes() for name in changed}
    original = {name:git('show',args.reference+':'+name) for name in changed}
    head = git('rev-parse','HEAD').decode().strip()
    before = run_case(destination/'before',save,args.resolution,original,args.reference)
    if not before['ok']:
        return 1
    after = run_case(destination/'after',save,args.resolution,current,head)
    states = {}
    for name in before['states']:
        old = destination/'before'/(name+'.gz')
        new = destination/'after'/(name+'.gz')
        states[name] = new.is_file() and json.loads(gzip.decompress(old.read_bytes()))==json.loads(gzip.decompress(new.read_bytes()))
    ratio = after['latency'].get('total_ms',1)/max(1,before['latency'].get('total_ms',1))
    report = {'reference':args.reference,'head':head,'resolution':args.resolution,'before':before['latency'],'after':after['latency'],'states':states,'same_backend':before.get('backend')==after.get('backend'),'same_days':[(r['day_before'],r['day_after']) for r in before.get('rows',[])]==[(r['day_before'],r['day_after']) for r in after.get('rows',[])],'source_save_unchanged':args.save.read_bytes()==save,'production_unchanged':all((ROOT/name).read_bytes()==data for name,data in current.items()) and git('rev-parse','HEAD').decode().strip()==head and not production_dirty(),'usable_ratio':ratio,'maximum_usable_ratio':0.85,'performance_gate_passed':ratio<=0.85,'backend':after.get('backend')}
    report['functional_ok'] = before['ok'] and after['ok'] and len(states)==4 and all(states.values()) and report['same_backend'] and report['same_days'] and report['source_save_unchanged'] and report['production_unchanged']
    report['ok'] = report['functional_ok'] and report['performance_gate_passed']
    (destination/'comparison.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(report),flush=True)
    return 0 if report['ok'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
