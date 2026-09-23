#!/usr/bin/env python3
"""Publish explicitly reviewed clips and refresh their battle/map artwork.

The original catalog row and atlas remain a rebuild baseline. Each later delivery
combines original reviewed source recipes, never repacks a previously resampled
atlas. Unreviewed clips keep their earlier artwork and are not marked complete.
"""
import argparse
import copy
import hashlib
import json
import shutil
from pathlib import Path

from integrate_fluid_creature_animation import ROOT, pack_unit, read, uri
from pack_overworld_creature_idle import extract


def write(path, value, compact=False):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=None if compact else 2,
                               separators=(',', ':') if compact else None) + '\n', encoding='utf-8')


def select_clips(entry, names):
    result = copy.deepcopy(entry)
    result['frames'], result['clips'] = [], {}
    for name in names:
        spec = copy.deepcopy(entry['clips'][name])
        frames = [copy.deepcopy(entry['frames'][i]) for i in spec['indices']]
        for frame in frames:
            frame.setdefault('alpha_noise_cutoff', entry.get('alpha_noise_cutoff', 0))
        start = len(result['frames'])
        result['frames'].extend(frames)
        spec['indices'] = list(range(start, start + len(frames)))
        result['clips'][name] = spec
    return result


def combine(previous, selected):
    if not previous:
        return selected
    if previous['source_facing'] != selected['source_facing']:
        raise ValueError('A unit must keep one authored source orientation across deliveries')
    kept = select_clips(previous, [name for name in previous['clips'] if name not in selected['clips']])
    result = copy.deepcopy(selected)
    offset = len(kept['frames'])
    for spec in result['clips'].values():
        spec['indices'] = [i + offset for i in spec['indices']]
    result['frames'] = kept['frames'] + result['frames']
    result['clips'] = dict(kept['clips'], **result['clips'])
    result['source_scale_by_image'] = {f['source']: f['scale'] for f in result['frames']}
    result['source_scale_reason'] = 'Reviewed source-resolution registration; one anatomical scale per original image.'
    return result


def publish(handoff, clips, note, preserved=()):
    catalog_path = ROOT / 'content/unit_animation_manifest.json'
    catalog = read(catalog_path)
    rows = {row['unit_id']: row for row in catalog['items']}
    idle_path = ROOT / 'art/overworld/creature_idle.json'
    idle = read(idle_path)
    entries = read(handoff)['units']
    # Fail before publishing if the requested selection is not explicit/valid.
    for entry in entries:
        if entry['unit_id'] not in rows or any(c not in entry['clips'] for c in clips):
            raise ValueError(f"Unknown unit or clip selection: {entry['unit_id']}")
    published = []
    for entry in entries:
        uid = entry['unit_id']
        source_dir = ROOT / 'art/animation/source/fluid' / uid
        source_dir.mkdir(parents=True, exist_ok=True)
        baseline_path = source_dir / 'baseline.json'
        baseline = read(baseline_path) if baseline_path.exists() else copy.deepcopy(rows[uid])
        baseline_atlas = source_dir / 'baseline.png'
        if not baseline_atlas.exists():
            shutil.copyfile(ROOT / baseline['pose_sheet'].removeprefix('res://'), baseline_atlas)
        baseline['pose_sheet'] = uri(baseline_atlas)
        reviewed_path = source_dir / 'reviewed_handoff.json'
        previous = read(reviewed_path)['units'][0] if reviewed_path.exists() else None
        combined = combine(previous, select_clips(entry, clips))
        retained = set((previous or {}).get('preserved_accepted_clips', [])) | set(preserved)
        retained.difference_update(combined['clips'])
        for name in retained:
            spec = baseline['pose_clips'].get(name, {})
            if name in baseline.get('pose_aliases', {}) or int(spec.get('frames', 0)) < 8:
                raise ValueError(f'{uid}/{name}: cannot approve a deficient or aliased legacy clip')
        combined['preserved_accepted_clips'] = sorted(retained)
        combined['accepted_clips'] = list(combined['clips']) + sorted(retained)
        combined['visual_review'] = {'status': 'accepted_selected_clips', 'notes': note}
        patch = pack_unit(combined, baseline, ROOT / 'art/animation/runtime/fluid')
        row = patch['animation']
        row['pose_provenance'] = uri(source_dir / 'provenance.json')
        row['pose_review_status'] = 'accepted_selected_fluid_clips'
        row['pose_accepted_clips'] = combined['accepted_clips']
        row.pop('pose_review_evidence', None)
        # The legacy sprite_sheet is a separate fallback layout; do not relabel it.
        strip, idle_entry = extract(row)
        strip_path = ROOT / idle_entry['path'].removeprefix('res://')
        strip.save(strip_path, optimize=True)
        idle_entry['sha256'] = hashlib.sha256(strip_path.read_bytes()).hexdigest()
        idle['units'][uid] = idle_entry
        write(baseline_path, baseline)
        write(reviewed_path, {'schema_version': 1, 'units': [combined]})
        write(source_dir / 'provenance.json', {
            'unit_id': uid, 'baseline': 'baseline.json', 'handoff': 'reviewed_handoff.json',
            'tool': 'tools/publish_fluid_creature_animation.py', 'sources': patch['sources'],
            'accepted_clips': combined['accepted_clips'], 'review': combined['visual_review'],
            'preserved_accepted_clips': sorted(retained),
            'baseline_atlas_sha256': hashlib.sha256(baseline_atlas.read_bytes()).hexdigest(),
            'atlas_sha256': patch['atlas_sha256'], 'texture_bytes_rgba': patch['texture_bytes_rgba']})
        rows[uid].clear()
        rows[uid].update(row)
        published.append({'unit_id': uid, 'clips': clips, 'texture_bytes_rgba': patch['texture_bytes_rgba']})
    write(catalog_path, catalog, compact=True)
    write(idle_path, idle)
    return published


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('handoff', type=Path)
    parser.add_argument('--clips', nargs='+', default=[], help='Only new clips visually reviewed by the coordinator')
    parser.add_argument('--preserve-reviewed', nargs='+', default=[], help='Qualifying existing clips explicitly visually reviewed')
    parser.add_argument('--review-note', required=True)
    args = parser.parse_args()
    if not args.clips and not args.preserve_reviewed:
        parser.error('Choose newly authored clips or visually reviewed existing clips')
    print(json.dumps(publish(args.handoff, args.clips, args.review_note, args.preserve_reviewed), indent=2))
