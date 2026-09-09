#!/usr/bin/env python3
"""Run the unchanged whole-cohort probe inside an isolated official release."""
import argparse
import hashlib
import json
from pathlib import Path

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
    args,_=parser.parse_known_args()
    payloads=members(args.pack)
    manifest='art/overworld/manifest.json'
    if json.loads(payloads[manifest])!=json.loads((cutouts.ROOT/manifest).read_text()):
        parser.error('release must contain the exact current Overworld art manifest')
    owner_paths=('scenes/overworld/OverworldMapView.gdc','scenes/overworld/OverworldShell.gdc',
                 'scripts/core/OverworldRules.gdc','scripts/autoload/SaveService.gdc')
    if any(path not in payloads for path in owner_paths):parser.error('compiled runtime/save owners missing')
    owners={path:hashlib.sha256(payloads[path]).hexdigest() for path in owner_paths}
    del payloads
    cutouts.probe_environment=lambda environment:package_environment(environment,args.platform)
    packages.layers=cutouts
    code=packages.main()
    path=cutouts.OUTPUT/args.label/'packaged-report.json'
    report=json.loads(path.read_text())
    report.update(overworld_manifest_equal=True,overworld_runtime_owner_sha256=owners,
                  driver='tests/overworld_cutout_batch_regression.py',
                  bootstrap='existing opt-in SHA-locked python_town_scene_probe Node flow')
    path.write_text(json.dumps(report,indent=2)+'\n')
    return code


if __name__=='__main__':raise SystemExit(main())
