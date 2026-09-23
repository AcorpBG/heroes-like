"""Register explicitly reviewed source bodies, scales and anatomical anchors.

Recipes select original alpha-connected paintings; no image is redrawn, warped
or independently resized. Detached owned effects require explicit extra rects.
"""
import hashlib
import json
from pathlib import Path
from refine_fluid_frame_crops import body_rectangles

ROOT = Path(__file__).resolve().parents[1]


def register(directory, recipe):
    directory = Path(directory).resolve()
    uid = directory.name
    entry = dict(unit_id=uid, reference_height=256, source_facing='right', frames=[], clips={},
                 source_scale_by_image={}, source_scale_reason=recipe['scale_reason'],
                 visual_review=dict(status='pending', notes=recipe['review_notes']))
    provenance = []
    for sheet in recipe['sheets']:
        if not len(sheet['seeds']) == len(sheet['anchors']) == len(sheet['clips']):
            raise ValueError('Every selected painting needs one seed, anchor and clip')
        source = directory / (sheet['stem'] + '.png')
        prompt = directory / (sheet['stem'] + '.prompt.txt')
        path = source.relative_to(ROOT).as_posix()
        entry['source_scale_by_image'][path] = sheet['scale']
        provenance.append(dict(image=path, sha256=hashlib.sha256(source.read_bytes()).hexdigest(),
                               prompt=prompt.relative_to(ROOT).as_posix(),
                               prompt_sha256=hashlib.sha256(prompt.read_bytes()).hexdigest()))
        for n, (seed, anchor, clip) in enumerate(zip(sheet['seeds'], sheet['anchors'], sheet['clips'])):
            rects = body_rectangles(source, seed, 8)
            rects.extend(sheet.get('additional_rects', {}).get(str(n), []))
            floor = anchor[1] if anchor[1] is not None else max(r[3] for r in rects)
            index = len(entry['frames'])
            entry['frames'].append(dict(name=f"{sheet['stem']}_{n}", clip=clip, source=path,
                                       rects=rects, anchor=[anchor[0], floor], scale=sheet['scale'],
                                       alpha_noise_cutoff=8,
                                       crop_recipe=dict(tool='tools/refine_fluid_frame_crops.py', seed=seed, cutoff=8)))
            entry['clips'].setdefault(clip, dict(indices=[], frame_msec=110, loop=clip=='move'))['indices'].append(index)
    for clip, order in recipe.get('phase_order', {}).items():
        indices = entry['clips'][clip]['indices']
        if sorted(order) != list(range(len(indices))):
            raise ValueError('Phase order must use every original painting exactly once')
        entry['clips'][clip]['indices'] = [indices[n] for n in order]
    for clip, options in recipe.get('timing', {}).items():
        entry['clips'][clip].update(options)
    entry['provenance'] = dict(tool='builtin_image_gen', sources=provenance,
                               generation_lineage=(directory / recipe['generation_lineage']).relative_to(ROOT).as_posix(),
                               reference='art/units/source/curated/' + uid + '.png')
    packet = dict(schema_version=1, units=[entry])
    (directory/'handoff.json').write_text(json.dumps(packet, indent=2)+'\n', encoding='utf-8')
    print(uid, {name:len(spec['indices']) for name,spec in entry['clips'].items()})
    return packet
