#!/usr/bin/env python3
"""Run the unchanged whole-cohort probe inside an isolated official release."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys

import overworld_cutout_batch_regression as cutouts
import packaged_town_scene_layer_regression as packages
from lossless_texture_package_regression import members


def package_environment(environment, platform):
    result=dict(environment,TOWN_OVERLAY_RESOLUTION=environment['CUTOUT_RESOLUTION'])
    if platform=='windows':
        for key in ('CUTOUT_SAVE','CUTOUT_OUTPUT','CUTOUT_ASSETS_FILE'):
            result[key]=packages.windows_path(result[key])
    return result


def main():
    parser=argparse.ArgumentParser(add_help=False,allow_abbrev=False)
    parser.add_argument('--pack',type=Path,required=True)
    parser.add_argument('--platform',choices=['linux','windows'],required=True)
    parser.add_argument('--label',required=True)
    parser.add_argument('--baseline-manifest-commit',help='Explicit predecessor run only: require its exact Git manifest instead of the working manifest; all texture/runtime assertions remain unchanged.')
    args,_=parser.parse_known_args()
    payloads=members(args.pack)
    manifest='art/overworld/manifest.json'
    baseline_commit=None
    expected_manifest=json.loads((cutouts.ROOT/manifest).read_text())
    if args.baseline_manifest_commit:
        baseline_commit=subprocess.check_output(['git','rev-parse','--verify',args.baseline_manifest_commit+'^{commit}'],cwd=cutouts.ROOT,text=True).strip()
        subprocess.run(['git','merge-base','--is-ancestor',baseline_commit,'HEAD'],cwd=cutouts.ROOT,check=True)
        expected_manifest=json.loads(subprocess.check_output(['git','show',baseline_commit+':'+manifest],cwd=cutouts.ROOT))
    if json.loads(payloads[manifest])!=expected_manifest:
        parser.error('release must contain the exact '+('selected predecessor' if baseline_commit else 'current')+' Overworld art manifest')
    owner_paths=('scenes/overworld/OverworldMapView.gdc','scenes/overworld/OverworldShell.gdc',
                 'scripts/core/OverworldRules.gdc','scripts/autoload/SaveService.gdc')
    if any(path not in payloads for path in owner_paths):parser.error('compiled runtime/save owners missing')
    owners={path:hashlib.sha256(payloads[path]).hexdigest() for path in owner_paths}
    del payloads
    cutouts.probe_environment=lambda environment:package_environment(environment,args.platform)
    packages.layers=cutouts
    arguments=sys.argv
    try:
        # This wrapper-only baseline selector must not leak into the unchanged
        # source probe's strict argparse surface.
        if args.baseline_manifest_commit:
            sys.argv=[arg for i,arg in enumerate(arguments) if arg!='--baseline-manifest-commit' and (i==0 or arguments[i-1]!='--baseline-manifest-commit') and not arg.startswith('--baseline-manifest-commit=')]
        code=packages.main()
    finally:
        sys.argv=arguments
    path=cutouts.OUTPUT/args.label/'packaged-report.json'
    report=json.loads(path.read_text())
    report.update(overworld_manifest_equal=True,baseline_manifest_commit=baseline_commit,overworld_runtime_owner_sha256=owners,
                  driver='tests/overworld_cutout_batch_regression.py',
                  bootstrap='existing opt-in SHA-locked python_town_scene_probe Node flow')
    path.write_text(json.dumps(report,indent=2)+'\n')
    return code


if __name__=='__main__':raise SystemExit(main())
