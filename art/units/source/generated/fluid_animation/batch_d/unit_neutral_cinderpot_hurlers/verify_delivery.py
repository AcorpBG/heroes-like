"""Verify original RGB preservation, guide lineage and published Cinderpot pixels.

Visual acceptance is separate; these checks establish source integrity and
preservation of unrelated catalog entries after publication.
"""
import argparse
import hashlib
import json
from pathlib import Path
import av
from PIL import Image
import produce as p
from integrate_fluid_creature_animation import old_pose, source_pose, clip_indices, resolve

UID = 'unit_neutral_cinderpot_hurlers'

def read(path):
    return json.loads(Path(path).read_bytes())

def same_pose(a, b):
    assert a[1] == b[1], (a[1], b[1])
    assert a[0].size == b[0].size
    assert a[0].tobytes() == b[0].tobytes()

def originals():
    count = 0
    for take in sorted(p.SOURCE_DIR.glob('*_h3_v*')):
        if not (take/'original.json').exists():
            continue
        record = read(take/'original.json')
        assert p.sha(take/'original_lossless.mkv') == record['sha256']
        with av.open(str(take/'original_lossless.mkv')) as container:
            hashes = [hashlib.sha256(f.to_image().convert('RGB').tobytes()).hexdigest() for f in container.decode(video=0)]
        assert hashes == record['decoded_rgb_sha256']
        count += len(hashes)
        for guide in read(take/'reference.json')['guides']:
            assert p.sha(take/guide['input_file']) == guide['input_sha256']
            assert p.sha(p.ROOT/guide['source_frame']['source']) == guide['source_sha256']
    print('Original RGB frames verified:', count)

def published(baseline_dir):
    before = read(baseline_dir/'baseline_manifest.json')['items']
    after = read(p.ROOT/'content/unit_animation_manifest.json')['items']
    assert [r for r in before if r['unit_id'] != UID] == [r for r in after if r['unit_id'] != UID]
    old = next(r for r in before if r['unit_id'] == UID)
    new = next(r for r in after if r['unit_id'] == UID)
    old_sheet = Image.open(resolve(old['pose_sheet'])).convert('RGBA')
    new_sheet = Image.open(resolve(new['pose_sheet'])).convert('RGBA')
    assert max(new_sheet.size) <= 4096
    oi = clip_indices(old['pose_clips']['idle'], old['pose_columns'])
    ni = clip_indices(new['pose_clips']['idle'], new['pose_columns'])
    assert len(oi) == len(ni) == 8
    for a,b in zip(oi,ni):
        same_pose(old_pose(old_sheet,old,a),old_pose(new_sheet,new,b))
    for key in ['frame_msec','loop','static_frame']:
        assert old['pose_clips']['idle'][key] == new['pose_clips']['idle'][key]
    entry = read(p.SOURCE_DIR/'handoff.json')['units'][0]
    selected = 0
    for name,spec in entry['clips'].items():
        live = clip_indices(new['pose_clips'][name], new['pose_columns'])
        assert len(live) == len(spec['indices'])
        for index,packed in zip(spec['indices'],live):
            same_pose(source_pose(entry['frames'][index],0),old_pose(new_sheet,new,packed))
            selected += 1
    assert new['pose_clips']['dead']['indices'] == [new['pose_clips']['death']['indices'][-1]]
    for record in entry['provenance'].values():
        assert p.sha(p.ROOT/record['path']) == record['sha256']
    old_map = read(baseline_dir/'baseline_map.json')['units']
    new_map = read(p.ROOT/'art/overworld/creature_idle.json')['units']
    assert {k:v for k,v in old_map.items() if k!=UID} == {k:v for k,v in new_map.items() if k!=UID}
    a = Image.open(baseline_dir/'baseline_map_idle.png').convert('RGBA')
    b = Image.open(resolve(new_map[UID]['path'])).convert('RGBA')
    assert a.size == b.size and a.tobytes() == b.tobytes()
    for key in ['frame_size','frames','frame_msec','static_frame','ground_anchor','painted_extent']:
        assert old_map[UID].get(key) == new_map[UID].get(key), key
    print('Published source frames verified:', selected)
    print('Eight idle poses, map pixels/timing and other 231 catalog rows preserved')
    print('Atlas:', new_sheet.size, 'RGBA bytes:', new_sheet.width*new_sheet.height*4)

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--baseline-dir', type=Path)
    args = parser.parse_args()
    originals()
    if args.baseline_dir:
        published(args.baseline_dir)
