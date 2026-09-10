#!/usr/bin/env python3
"""Run the real native-map test via the existing SHA-locked release bootstrap."""
import argparse
from contextlib import nullcontext
import json
import shutil

import generated_neutral_map_regression as neutral
import packaged_town_scene_layer_regression as packages
from lossless_texture_package_regression import members
from wine_prefix_cleanup import managed_prefixes

def main():
    parser=argparse.ArgumentParser(add_help=False)
    parser.add_argument('--pack',type=packages.Path,required=True)
    parser.add_argument('--platform',choices=['linux','windows'],required=True)
    parser.add_argument('--wine-prefix',type=packages.Path)
    args,_=parser.parse_known_args()
    payloads=members(args.pack)
    for path in ('content/generated_neutral_encounter_profiles.json','art/overworld/manifest.json'):
        if json.loads(payloads[path])!=json.loads((neutral.ROOT/path).read_text()):
            parser.error('package must contain current '+path)
    for path in ('scripts/persistence/GeneratedNeutralEncounterRules.gdc','scripts/persistence/NativeRandomMapPackageSessionBridge.gdc','scenes/overworld/OverworldMapView.gdc'):
        if path not in payloads: parser.error('missing compiled '+path)
    del payloads
    def environment(env):
        result=dict(env)
        if args.platform=='windows': result['NEUTRAL_OUT']=packages.windows_path(result['NEUTRAL_OUT'])
        return result
    neutral.probe_environment=environment
    # Exported maps are already isolated under the disposable Wine/XDG user
    # directory. They never write the editor's res://maps files.
    neutral.preserve_generated_map_files=lambda size:nullcontext()
    packages.layers=neutral
    # Our shared probe already skips captures under a headless DisplayServer.
    # Keep its gameplay/assertion code byte-identical on both platforms.
    packages.headless_script=lambda script:(script,[])
    if args.platform == 'linux':
        return packages.main()
    if args.wine_prefix is None or args.wine_prefix.exists() or args.wine_prefix.is_symlink():
        parser.error('Windows requires a new nonexistent task-owned --wine-prefix')
    prefix = args.wine_prefix.resolve()
    with managed_prefixes((prefix,), prefix.parent, shutil.which('wineserver') or '') as receipt:
        code = packages.main()
    return code if receipt['ok'] else 1

if __name__=='__main__': raise SystemExit(main())
