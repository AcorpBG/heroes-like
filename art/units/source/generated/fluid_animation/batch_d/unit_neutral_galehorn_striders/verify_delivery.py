"""Verify original RGB preservation, guide lineage and published Galehorn pixels.

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

UID = 'unit_neutral_galehorn_striders'

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

def published(baseline_dir, handoff_path=None):
    before = read(baseline_dir/'baseline_manifest.json')['items']
    after = read(p.ROOT/'content/unit_animation_manifest.json')['items']
    assert [r for r in before if r['unit_id'] != UID] == [r for r in after if r['unit_id'] != UID]
    old = next(r for r in before if r['unit_id'] == UID)
    new = next(r for r in after if r['unit_id'] == UID)
    old_sheet = Image.open(resolve(old['pose_sheet'])).convert('RGBA')
    new_sheet = Image.open(resolve(new['pose_sheet'])).convert('RGBA')
    assert max(new_sheet.size) <= 4096
    entry = read(handoff_path or p.SOURCE_DIR/'handoff.json')['units'][0]
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
    from pack_overworld_creature_idle import extract
    expected_strip, expected_map = extract(new)
    actual_strip = Image.open(resolve(new_map[UID]['path'])).convert('RGBA')
    assert expected_strip.size == actual_strip.size
    assert expected_strip.tobytes() == actual_strip.tobytes()
    for key,value in expected_map.items():
        assert new_map[UID][key] == value, key
    assert p.sha(resolve(new_map[UID]['path'])) == new_map[UID]['sha256']
    assert len(clip_indices(new['pose_clips']['idle'],new['pose_columns'])) >= 8
    print('Published source frames verified:', selected)
    print('New four-leg idle/map exact source pixels; other 231 catalog rows preserved')
    print('Atlas:', new_sheet.size, 'RGBA bytes:', new_sheet.width*new_sheet.height*4)

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--baseline-dir', type=Path)
    parser.add_argument('--handoff', type=Path, help='Check a reviewed correction candidate in addition to existing source clips')
    args = parser.parse_args()
    originals()
    if args.baseline_dir:
        published(args.baseline_dir,args.handoff)
