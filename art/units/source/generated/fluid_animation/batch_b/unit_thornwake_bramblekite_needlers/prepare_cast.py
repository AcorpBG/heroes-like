"""Register the broad near-arm invocation at the established creature scale."""
import hashlib
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[6]
source = HERE / 'cast_v3.png'
prompt = HERE / 'cast_v3.prompt.txt'
path = source.relative_to(ROOT).as_posix()
rects = [[0, 0, 390, 493], [390, 0, 782, 493], [782, 0, 1167, 493], [1167, 0, 1536, 493],
         [0, 493, 410, 1024], [410, 493, 786, 1024], [786, 493, 1167, 1024], [1167, 493, 1536, 1024]]
anchors = [[225,492], [610,492], [995,492], [1380,492],
           [232,1003], [615,1003], [997,1003], [1380,1003]]
entry = dict(unit_id=HERE.name, reference_height=256, source_facing='right', frames=[],
             source_scale_by_image={path: .44},
             source_scale_reason='One fixed .44 source scale keeps the crown-to-toe anatomy near the retained 194px body; raised arm height is not normalized.',
             clips=dict(cast=dict(indices=list(range(8)), frame_msec=115, contact_frame=4, loop=False)),
             visual_review=dict(status='pending', notes='Broad near-arm release, raise, leaf invocation and regrip; native review required.'),
             provenance=dict(tool='builtin_image_gen', sources=[dict(
                 image=path, sha256=hashlib.sha256(source.read_bytes()).hexdigest(),
                 prompt=prompt.relative_to(ROOT).as_posix(), prompt_sha256=hashlib.sha256(prompt.read_bytes()).hexdigest(),
                 reference='art/units/source/curated/' + HERE.name + '.png',
                 generation_output='C:/Users/acorp/.codex/generated_images/01a0965d-a98e-7560-8e9d-802269b3760b/exec-edd81bce-6db4-4074-9828-37832767dcb1.png')]))
for i, (rect, anchor) in enumerate(zip(rects, anchors)):
    entry['frames'].append(dict(name=f'cast_{i}', clip='cast', source=path,
                               rects=[rect], anchor=anchor, scale=.44, alpha_noise_cutoff=8))
(HERE / 'cast_handoff.json').write_text(json.dumps(dict(schema_version=1, units=[entry]), indent=2) + '\n', encoding='utf-8')
