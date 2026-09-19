#!/usr/bin/env python3
"""Append an inspected idle recipe, preserving every pre-existing action pixel.

This registers candidate artwork; visual acceptance remains a separate review.
The retained previous recipe makes subsequent adjustments idempotent.
"""
import argparse
import copy
import hashlib
import json
import os
from pathlib import Path
import tempfile

from PIL import Image

from pack_unit_pose_art import pack
from pack_overworld_creature_idle import extract

ROOT = Path(__file__).resolve().parents[1]


def write_json(path, data, compact=False):
    path.write_text(json.dumps(data, indent=None if compact else 2,
                               separators=(',', ':') if compact else None) + '\n', encoding='utf-8')


def integrate(candidate_path, frame_msec, generation_path):
    candidate_path = candidate_path.resolve()
    spec = json.loads(candidate_path.read_text())
    uid = spec['unit_id']
    if len(spec['frames']) != 8 or not 80 <= frame_msec <= 500:
        raise ValueError('Expected eight reviewed poses and a deliberate cadence')
    source_dir = ROOT / 'art/animation/source/poses' / uid
    recipe_path = source_dir / 'packing.json'
    original_recipe = recipe_path.read_bytes()
    previous_path = candidate_path.with_name(candidate_path.stem + '-previous.json')
    if not previous_path.exists():
        previous = json.loads(recipe_path.read_text())
        for frame in previous['frames']:
            frame['source'] = Path(source_dir / frame['source']).resolve().relative_to(ROOT).as_posix()
        write_json(previous_path, previous)
    previous = json.loads(previous_path.read_text())
    recipe = copy.deepcopy(previous)
    for frame in recipe['frames']:
        frame['source'] = Path(os.path.relpath(ROOT / frame['source'], source_dir)).as_posix()
    if any(spec[k] != previous[k] for k in ('frame_size', 'columns', 'ground_margin')):
        raise ValueError('Candidate must preserve the existing atlas coordinate system')
    first_index = len(recipe['frames'])
    for frame in copy.deepcopy(spec['frames']):
        frame['source'] = (candidate_path.parent / frame['source']).relative_to(source_dir).as_posix()
        recipe['frames'].append(frame)
    recipe['status'] = 'candidate_requires_playback_review'
    manifest_path = ROOT / 'content/unit_animation_manifest.json'
    manifest = json.loads(manifest_path.read_text())
    row = next(r for r in manifest['items'] if r['unit_id'] == uid)
    output = ROOT / row['pose_sheet'].removeprefix('res://')
    with Image.open(output) as image:
        old_pixels = image.copy()
    old_hash = hashlib.sha256(output.read_bytes()).hexdigest()
    # Recipe lives beside its relative sources; candidate atlas is temporary.
    with tempfile.TemporaryDirectory(prefix='idle-pack-') as temp:
        staged = Path(temp) / 'atlas.png'
        write_json(recipe_path, recipe)
        try:
            result = pack(recipe_path, staged)
            with Image.open(staged) as image:
                w, h = recipe['frame_size']
                for i in range(first_index):
                    box = (i % recipe['columns'] * w, i // recipe['columns'] * h,
                           (i % recipe['columns'] + 1) * w, (i // recipe['columns'] + 1) * h)
                    if image.crop(box).tobytes() != old_pixels.crop(box).tobytes():
                        raise ValueError(f'Existing pose pixels changed: {uid} frame {i}')
            output.write_bytes(staged.read_bytes())
        except Exception:
            recipe_path.write_bytes(original_recipe)
            raise
    row['pose_clips']['idle'] = {'frames': 8, 'indices': list(range(first_index, first_index + 8)),
                                'loop': True, 'frame_msec': frame_msec, 'static_frame': 0}
    row['pose_review_status'] = 'candidate_idle_articulation_20260919'
    write_json(manifest_path, manifest, compact=True)
    provenance_path = source_dir / 'provenance.json'
    provenance = json.loads(provenance_path.read_text())
    provenance['packing'] = {'tool': 'tools/pack_unit_pose_art.py', 'recipe': 'packing.json',
                             'runtime': output.relative_to(ROOT).as_posix(), 'runtime_sha256': result['sha256']}
    provenance['idle_articulation'] = {
        'generation': generation_path.resolve().relative_to(source_dir).as_posix(),
        'recipe': candidate_path.relative_to(source_dir).as_posix(),
        'previous_atlas_sha256': provenance.get('idle_articulation', {}).get('previous_atlas_sha256', old_hash),
        'preserved_frames': first_index, 'status': 'candidate_requires_playback_review'}
    write_json(provenance_path, provenance)
    strip, entry = extract(row)
    strip_path = ROOT / entry['path'].removeprefix('res://')
    strip.save(strip_path, optimize=True)
    entry['sha256'] = hashlib.sha256(strip_path.read_bytes()).hexdigest()
    map_path = ROOT / 'art/overworld/creature_idle.json'
    map_manifest = json.loads(map_path.read_text())
    map_manifest['units'][uid] = entry
    write_json(map_path, map_manifest)
    return {'unit_id': uid, 'new_poses': 8, 'preserved_frames': first_index, 'atlas_sha256': result['sha256']}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('recipe', type=Path)
    parser.add_argument('--generation', type=Path, required=True)
    parser.add_argument('--frame-msec', type=int, default=240)
    args = parser.parse_args()
    print(json.dumps(integrate(args.recipe, args.frame_msec, args.generation)))
