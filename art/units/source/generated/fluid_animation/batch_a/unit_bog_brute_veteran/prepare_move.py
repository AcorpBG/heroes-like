"""Register eight original reciprocal gait poses, retaining prior combat artwork."""
import hashlib
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[6]
sys.path.insert(0, str(ROOT / 'tools'))
from refine_fluid_frame_crops import body_rectangles

entry = dict(unit_id=HERE.name, reference_height=256, source_facing='right',
             frames=[], clips={}, source_scale_by_image={},
             source_scale_reason='One fixed scale per original master matches the approved 207px body. Pelvis and sole anchors preserve planted support; no pose deformation or per-frame resizing.',
             provenance=dict(tool='builtin_image_gen', sources=[], generation_lineage=(HERE/'move_generation.json').relative_to(ROOT).as_posix()))
# Contact, weight-bearing, passing knee and reaching foot for each leg.
phases = [
    ('move_contacts_v1', [480, 300], [480, 862], .26),
    ('move_far_v4', [280, 400], [285, 885], .30),
    ('move_far_v4', [780, 400], [783, 885], .30),
    ('move_reach_v7', [670, 400], [673, 1210], .18),
    ('move_contacts_v1', [1250, 300], [1250, 863], .26),
    ('move_near_v3', [280, 400], [279, 882], .30),
    ('move_near_v3', [780, 400], [770, 882], .30),
    ('move_near_v3', [1270, 400], [1268, 887], .30),
]
for index, (stem, seed, anchor, scale) in enumerate(phases):
    source = HERE / (stem + '.png')
    path = source.relative_to(ROOT).as_posix()
    if path not in entry['source_scale_by_image']:
        prompt = HERE / (stem + '.prompt.txt')
        entry['provenance']['sources'].append(dict(image=path,
            sha256=hashlib.sha256(source.read_bytes()).hexdigest(),
            prompt=prompt.relative_to(ROOT).as_posix(),
            prompt_sha256=hashlib.sha256(prompt.read_bytes()).hexdigest()))
    entry['source_scale_by_image'][path] = scale
    entry['frames'].append(dict(name=f'move_{index}', clip='move', source=path,
        rects=body_rectangles(source, seed, 8), anchor=anchor, scale=scale,
        alpha_noise_cutoff=8, crop_recipe=dict(tool='tools/refine_fluid_frame_crops.py', seed=seed, cutoff=8)))
entry['clips']['move'] = dict(indices=list(range(8)), frame_msec=115, loop=True,
    painted_phase_order=['shield-side contact', 'shield-side support', 'maul-side passing knee',
                         'maul-side reach', 'maul-side contact', 'maul-side support',
                         'shield-side passing knee', 'shield-side reach'])
entry['visual_review'] = dict(status='accepted_selected_clips', notes='Source and native 128px review accepted opposite support legs, maul clearance, grounded feet and matched armor palette. Candidate 11 and live 118 focused checks passed.')
(HERE/'move_handoff.json').write_text(json.dumps(dict(schema_version=1, units=[entry]), indent=2)+'\n', encoding='utf-8')
