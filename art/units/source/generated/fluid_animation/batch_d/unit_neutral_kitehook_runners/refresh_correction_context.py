"""Refresh only other catalog baseline rows and read-only correction provenance."""
import copy
import argparse
import datetime
import json
import urllib.request
from pathlib import Path
import produce as p

if __name__ == '__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--gpu-authorized',action='store_true');parser.add_argument('--baseline-only',action='store_true');args=parser.parse_args()
    uid='unit_neutral_kitehook_runners'
    baseline=p.ROOT/'.artifacts/kitehook_h3'
    old=json.loads((baseline/'baseline_manifest.json').read_bytes())
    live=json.loads((p.ROOT/'content/unit_animation_manifest.json').read_bytes())
    target=next(row for row in old['items'] if row['unit_id']==uid)
    updated=copy.deepcopy(live)
    updated['items']=[target if row['unit_id']==uid else row for row in live['items']]
    p.write(baseline/'baseline_manifest.json',updated)
    oldmap=json.loads((baseline/'baseline_map.json').read_bytes())
    livemap=json.loads((p.ROOT/'art/overworld/creature_idle.json').read_bytes())
    livemap['units'][uid]=oldmap['units'][uid]
    p.write(baseline/'baseline_map.json',livemap)
    if args.baseline_only:
        print('Refreshed only other current catalog/map entries; retained original target row and idle PNG; submitted generation profiles unchanged.')
        raise SystemExit(0)
    # Preserve the original target row, idle and original map PNG. This refresh
    # observes installed service state without submission, unload or decode.
    with urllib.request.urlopen(p.URL+'/system_stats',timeout=30) as response:
        stats=json.load(response)
    profile=json.loads((p.SOURCE_DIR/'runtime_profile.json').read_bytes())
    model_root=Path('H:/ai/minimax-h3/ComfyUI/models')
    sizes=[]
    for model in profile['model_manifest']['files']:
        installed=model_root/model['file'];actual=installed.stat().st_size
        assert actual==model['bytes'],str(installed)
        sizes.append({'path':str(installed),'bytes':actual})
    profile.update(unit_id=uid,checked_for_unit=uid,current_service=stats,
        observed_at_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),
        generation_authorization=('Coordinator GPU GO for this final finite move/hit correction pair; no later retries authorized.' if args.gpu_authorized else 'Prepared correction pair only; GPU dispatch awaits separate coordinator GO. Read-only system_stats observation while Flaremast owns GPU.'),
        installed_file_sizes=sizes,
        correction_scope=['move_h3_v2','hit_h3_v2'],
        correction_palette_note='Measured pure-green guides, original v1 retained; explicit opposing move contact and original both-grounded guide.')
    for take in profile['correction_scope']:
        p.write(p.SOURCE_DIR/take/'runtime_profile.json',profile)
    print('Refreshed other catalog/map baseline rows; retained original Kitehook target row and map idle PNG. Read-only service provenance saved for prepared pair.')
