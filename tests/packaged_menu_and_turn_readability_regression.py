#!/usr/bin/env python3
"""Run the same menu/turn probe through the SHA-locked release bootstrap."""
import argparse
import hashlib
import json
import shutil
import menu_and_turn_readability_regression as ui
import packaged_town_scene_layer_regression as packages
from lossless_texture_package_regression import members
from wine_prefix_cleanup import managed_prefixes

def main():
    parser=argparse.ArgumentParser(add_help=False)
    parser.add_argument('--platform',choices=['linux','windows'],required=True)
    parser.add_argument('--pack',type=packages.Path,required=True)
    parser.add_argument('--wine-prefix',type=packages.Path)
    parser.add_argument('--label',required=True)
    args,_=parser.parse_known_args()
    payloads=members(args.pack)
    paths=('scenes/menus/MainMenu.gdc','scenes/menus/MainMenuComposition.gdc',
           'scripts/core/OverworldTurnPlayback.gdc','scripts/core/EnemyAdventureRules.gdc',
           'scripts/core/EnemyTurnRules.gdc','scenes/overworld/OverworldTurnPresenter.gdc',
           'scenes/overworld/OverworldShell.gdc','scenes/overworld/OverworldMapView.gdc')
    owners={path:hashlib.sha256(payloads[path]).hexdigest() for path in paths}
    del payloads
    def environment(env):
        result=dict(env)
        if args.platform=='windows': result['BATTLE_READABILITY_OUT']=packages.windows_path(result['BATTLE_READABILITY_OUT'])
        return result
    ui.probe_environment=environment
    packages.layers=ui
    packages.headless_script=lambda script:(script,[])
    if args.platform=='windows':
        if args.wine_prefix is None or args.wine_prefix.exists() or args.wine_prefix.is_symlink():
            parser.error('requires a new task-owned Wine prefix')
        prefix=args.wine_prefix.resolve()
        with managed_prefixes((prefix,),prefix.parent,shutil.which('wineserver') or '') as receipt:
            code=packages.main()
        if not receipt['ok']: code=1
    else: code=packages.main()
    report=ui.OUTPUT/args.label/'packaged-ui-owners.json'
    report.write_text(json.dumps({'ok':code==0,'compiled_owner_sha256':owners},indent=2)+'\n')
    return code

if __name__=='__main__': raise SystemExit(main())
