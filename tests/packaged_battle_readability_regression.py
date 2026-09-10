#!/usr/bin/env python3
"""Same battle assertions via the existing SHA-locked isolated-release probe."""
import argparse
import hashlib
import json
import shutil

import battle_readability_regression as battle
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
    paths=('scripts/core/BattleActionPlayback.gdc','scripts/core/BattleRules.gdc','scenes/battle/BattleShell.gdc','scenes/battle/BattleBoardView.gdc')
    owners={path:hashlib.sha256(payloads[path]).hexdigest() for path in paths}
    del payloads
    def environment(env):
        result=dict(env)
        if args.platform=='windows': result['BATTLE_READABILITY_OUT']=packages.windows_path(result['BATTLE_READABILITY_OUT'])
        return result
    battle.probe_environment=environment
    packages.layers=battle
    packages.headless_script=lambda script:(script,[])
    if args.platform=='windows':
        if args.wine_prefix is None or args.wine_prefix.exists() or args.wine_prefix.is_symlink():
            parser.error('requires a new task-owned Wine prefix')
        prefix=args.wine_prefix.resolve()
        with managed_prefixes((prefix,),prefix.parent,shutil.which('wineserver') or '') as receipt:
            code=packages.main()
        if not receipt['ok']: code=1
    else: code=packages.main()
    report=battle.OUTPUT/args.label/'packaged-battle-owners.json'
    report.write_text(json.dumps({'ok':code==0,'compiled_battle_owner_sha256':owners},indent=2)+'\n')
    return code

if __name__=='__main__': raise SystemExit(main())
