#!/usr/bin/env python3
"""Isolate the known Moonbite deadline with exact old/current Overworld owners."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

from generated_town_order_profile import ROOT, OUTPUT, run_probe
from town_logistics_read_scope_regression import OWNER, REFERENCE


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--label', required=True)
    parser.add_argument('--case', choices=['save_resume','development'], default='save_resume')
    args = parser.parse_args()
    if not args.label or any(c not in 'abcdefghijklmnopqrstuvwxyz0123456789_-' for c in args.label):
        parser.error('label must be a fresh lowercase slug')
    out = OUTPUT/args.label
    out.mkdir(parents=True, exist_ok=False)
    original = subprocess.check_output(['git','show',f'{REFERENCE}:{OWNER}'],cwd=ROOT)
    current = (ROOT/OWNER).read_bytes()
    fixture_name = 'town_development_save_resume_report' if args.case == 'save_resume' else 'town_development_runtime_balance_report'
    fixture = (ROOT/'tests'/f'{fixture_name}.gd').read_text()
    anchor = 'for town_id in ContentService.get_content_ids(ContentService.TOWNS_PATH):'
    if fixture.count(anchor) != 1:
        raise ValueError('review changed authoritative matrix selection')
    fixture = fixture.replace(anchor,'for town_id in ["town_moonbite_reedshrine"]:')
    reports, runs = {}, {}
    # Disposable plain projects, not git worktrees. Only script source is
    # copied; original imported art/native libraries remain shared and intact.
    # Substituting the actual owner at res://scripts/core/OverworldRules.gd
    # makes every static/autoload consumer use the old owner, not a partial
    # subclass whose nested calls would silently reach the new implementation.
    with tempfile.TemporaryDirectory(prefix='logistics-balance-',dir=OUTPUT) as temp:
        work = Path(temp)
        for label, owner in [('original',original),('current',current)]:
            project = work/label
            project.mkdir()
            for name in ['project.godot','.godot','art','bin','content','scenes','src']:
                (project/name).symlink_to(ROOT/name,target_is_directory=(ROOT/name).is_dir())
            shutil.copytree(ROOT/'scripts',project/'scripts')
            (project/OWNER).write_bytes(owner)
            (project/'probe.gd').write_text(fixture)
            (project/'probe.tscn').write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://probe.gd" id="1"]\n[node name="Balance" type="Node"]\nscript = ExtResource("1")\n')
            with (out/(label+'.log')).open('w') as log:
                code = run_probe(['godot4','--headless','--path',str(project),'--audio-driver','Dummy','--accessibility','disabled','res://probe.tscn'],dict(os.environ,XDG_DATA_HOME=str(out/(label+'_data'))),log)
            lines = (out/(label+'.log')).read_text().splitlines()
            marker = fixture_name.upper()+' '
            found = [json.loads(line[len(marker):]) for line in lines if line.startswith(marker)]
            reports[label] = found[-1] if found else {}
            runs[label] = {'returncode':code,'owner_sha256':hashlib.sha256(owner).hexdigest(),'runtime_errors':[line for line in lines if line.startswith(('ERROR:','SCRIPT ERROR:')) or 'leaked' in line]}
    expected = ['town_moonbite_reedshrine did not complete development after save/resume within 30 turns' if args.case == 'save_resume' else 'town_moonbite_reedshrine did not complete in 30 turns']
    result = reports['current']
    row = result.get('towns',{}).get('town_moonbite_reedshrine',{})
    equal = bool(result) and result == reports['original']
    preserved = all(row.get(k) for k in ['save_resume_ok','same_day_guard_after_restore','rare_resume_ok','resume_target_town']) if args.case == 'save_resume' else bool(row.get('recruitment_end_to_end_ok'))
    ok = equal and result.get('errors') == expected and preserved and all(run['returncode']==1 and not run['runtime_errors'] for run in runs.values())
    report = {'ok':bool(ok),'case':args.case,'exact_complete_report_parity':equal,'reference_revision':REFERENCE,'runs':runs,'reports':reports,'boundary':'Exact old/current runtime-owner control for one pre-existing 30-turn content-budget failure. The development gate still FAILS; successful equivalence is not balance approval and does not waive other domain failures. No gameplay/content/fixture assertions were changed.'}
    (out/'report.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({k:v for k,v in report.items() if k!='reports'}))
    return 0 if ok else 1


if __name__ == '__main__':
    raise SystemExit(main())
