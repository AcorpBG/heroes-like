#!/usr/bin/env python3
"""Package approved generated spell paintings; never draw replacement artwork.

Sources and complete prompts live beside briefs.json. Only alpha-bound cropping,
proportional Lanczos resizing and transparent padding are applied. --check is
read-only and verifies byte-exact reproducibility and authoritative cue coverage.
"""
import argparse
import hashlib
import io
import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'art/battle/source/generated/spell_variety'
RUNTIME = ROOT / 'art/battle/vfx'
MANIFEST = ROOT / 'content/battle_vfx_manifest.json'
PROFILES = {'empower', 'haste', 'protection', 'binding', 'clamp', 'fogbind', 'boundary'}
SCALE = {'empower': 2.35, 'haste': 2.15, 'protection': 2.55,
         'binding': 2.45, 'clamp': 2.45, 'fogbind': 2.50, 'boundary': 2.45}


def digest(data):
    return hashlib.sha256(data).hexdigest()


def runtime_bytes(path):
    with Image.open(path) as source:
        if source.mode != 'RGBA':
            raise ValueError(f'{path.name}: expected original RGBA alpha')
        alpha = source.getchannel('A')
        alpha_min, alpha_max = alpha.getextrema()
        if alpha_min != 0 or alpha_max < 128:
            raise ValueError(f'{path.name}: missing transparent background or visible artwork')
        bounds = alpha.getbbox()
        if not bounds:
            raise ValueError(f'{path.name}: empty source')
        painting = source.crop(bounds)
        painting.thumbnail((320, 320), Image.Resampling.LANCZOS)
        canvas = Image.new('RGBA', (384, 384), (0, 0, 0, 0))
        canvas.alpha_composite(painting, ((384 - painting.width) // 2, (384 - painting.height) // 2))
        buffer = io.BytesIO()
        canvas.save(buffer, format='PNG', optimize=True)
        return buffer.getvalue(), list(bounds), list(source.size)


def prepare(check=False):
    briefs = json.loads((SOURCE / 'briefs.json').read_text())
    if briefs.get('generation_mode') != 'built_in_image_gen':
        raise ValueError('Expected approved built-in original raster generation')
    origins = json.loads((SOURCE / 'origins.json').read_text())
    spells = {s['id']: s for s in json.loads((ROOT / 'content/spells.json').read_text())['items']}
    manifest = json.loads(MANIFEST.read_text())
    families = briefs['families']
    if len(families) != 21 or len({f['id'] for f in families}) != 21:
        raise ValueError('Expected the 21 owner-directed effect families')
    seen = set()
    source_hashes, runtime_hashes, items = set(), set(), []
    for family in families:
        identity, profile = family['id'], family['motion_profile']
        if profile not in PROFILES:
            raise ValueError(f'{identity}: unknown motion profile')
        source = SOURCE / f'{identity}_source.png'
        runtime = RUNTIME / f'family_{identity}.png'
        data, bounds, size = runtime_bytes(source)
        source_hash, runtime_hash = digest(source.read_bytes()), digest(data)
        if source_hash in source_hashes or runtime_hash in runtime_hashes:
            raise ValueError(f'{identity}: duplicate effect artwork')
        source_hashes.add(source_hash)
        runtime_hashes.add(runtime_hash)
        if check:
            if not runtime.is_file() or runtime.read_bytes() != data:
                raise ValueError(f'{identity}: runtime does not match retained source')
        else:
            runtime.write_bytes(data)
        for index, spell_id in enumerate(family['spell_ids']):
            spell = spells[spell_id]
            if spell_id in seen or spell['context'] != 'battle' or spell['school_id'] != family['school_id'] or spell['effect']['type'] != family['effect_type']:
                raise ValueError(f'{spell_id}: duplicate or semantically wrong family assignment')
            seen.add(spell_id)
            cue_id = 'vfx_' + spell_id
            cue = {
                'texture_path': 'res://' + runtime.relative_to(ROOT).as_posix(),
                'render_mode': 'spell_target', 'scale': SCALE[profile],
                'base_rotation_degrees': 0.0, 'spell_id': spell_id,
                'effect_family': identity, 'motion_profile': profile,
                'visual_variant': index % 3,
                'visual_strength': round(0.94 + min(int(spell['tier']), 5) * 0.025, 3),
            }
            if check:
                if manifest['spell_cues'].get(spell_id) != cue_id or manifest['cues'].get(cue_id) != cue:
                    raise ValueError(f'{spell_id}: incorrect live cue metadata')
            else:
                manifest['spell_cues'][spell_id] = cue_id
                manifest['cues'][cue_id] = cue
        items.append({**family, 'generation_original': origins[identity],
                      'source_path': 'res://' + source.relative_to(ROOT).as_posix(),
                      'runtime_path': 'res://' + runtime.relative_to(ROOT).as_posix(),
                      'source_dimensions': size, 'alpha_bounds': bounds,
                      'source_sha256': source_hash, 'runtime_sha256': runtime_hash})
    if len(seen) != 44:
        raise ValueError('The 44 former Command Ward spells must all be covered')
    expected = {s['id'] for s in spells.values() if s['context'] == 'battle'}
    if set(manifest['spell_cues']) != expected:
        raise ValueError('Every battle spell must have an explicit artwork mapping')
    provenance = {'schema': 'spell_variety_sources_v1', 'content_slice_id': briefs['slice_id'],
                  'generation_mode': briefs['generation_mode'], 'shared_final_prompt': briefs['shared_prompt'],
                  'runtime_derivation': 'Crop nonzero original alpha bounds, proportionally Lanczos-fit within 320x320 and center in a 384x384 RGBA transparent canvas; no recoloring, quantization or generated geometry.',
                  'items': items}
    provenance_path = SOURCE / 'manifest.json'
    if check:
        if json.loads(provenance_path.read_text()) != provenance:
            raise ValueError('Source provenance does not match the reproducible derivation')
    else:
        MANIFEST.write_text(json.dumps(manifest, indent=2) + '\n')
        provenance_path.write_text(json.dumps(provenance, indent=2) + '\n')
    return {'families': len(items), 'former_shared_spells': len(seen),
            'explicit_battle_spells': len(expected), 'check_only': check}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    print(json.dumps(prepare(args.check), sort_keys=True))


if __name__ == '__main__':
    main()
