"""Register selected original gait paintings without synthetic animation frames."""
import hashlib
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[6]
sys.path.insert(0, str(ROOT / 'tools'))
from refine_fluid_frame_crops import body_rectangles

entry = dict(unit_id=HERE.name, reference_height=256, source_facing='right', frames=[], clips={},
    source_scale_by_image={}, source_scale_reason='Fixed source-specific scale matches the established approximately 235px mast-to-ground height; hip centers and planted soles define anchors.',
    provenance=dict(tool='builtin_image_gen', sources=[], generation_lineage=(HERE/'move_generation.json').relative_to(ROOT).as_posix()))
phases = [
    ('move_near_v4', [420,180], [430,518], .46),
    ('move_near_v4', [1180,180], [1180,511], .46),
    ('move_near_v4', [410,700], [425,1015], .46),
    ('move_contacts_v1', [1360,350], [1370,854], .28),
    ('move_left_support_v7', [510,350], [515,848], .28),
    ('move_left_support_v7', [1380,350], [1380,854], .28),
    ('move_near_v4', [1180,700], [1180,1005], .46),
    ('move_inbetweens_v2', [900,1080], [901,1265], .55),
]
for index, (stem, seed, anchor, scale) in enumerate(phases):
    source = HERE / (stem+'.png'); prompt = HERE / (stem+'.prompt.txt')
    path = source.relative_to(ROOT).as_posix()
    if path not in entry['source_scale_by_image']:
        entry['provenance']['sources'].append(dict(image=path, sha256=hashlib.sha256(source.read_bytes()).hexdigest(), prompt=prompt.relative_to(ROOT).as_posix(), prompt_sha256=hashlib.sha256(prompt.read_bytes()).hexdigest()))
    entry['source_scale_by_image'][path] = scale
    entry['frames'].append(dict(name=f'move_{index}', clip='move', source=path, rects=body_rectangles(source,seed,8), anchor=anchor, scale=scale, alpha_noise_cutoff=8, crop_recipe=dict(tool='tools/refine_fluid_frame_crops.py',seed=seed,cutoff=8)))
entry['clips']['move'] = dict(indices=list(range(8)),frame_msec=115,loop=True,
    painted_phase_order=['far contact','far support','near passing','near reach','near contact','near support','far passing','far reach'])
entry['visual_review'] = dict(status='accepted_selected_clips', notes='Native 128px review accepted reciprocal contacts, near-leg support, opposite knee lifts, retained two-hand spear grip and complete mast/cloth/weapon silhouettes. Candidate 11 and imported live 120 focused checks passed. Prior approved action source recipes are unchanged.')
(HERE/'move_handoff.json').write_text(json.dumps(dict(schema_version=1,units=[entry]),indent=2)+'\n',encoding='utf-8')
