"""Register eight original reciprocal walk poses without synthetic deformation."""
import hashlib
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[6]
sys.path.insert(0, str(ROOT / 'tools'))
from refine_fluid_frame_crops import body_rectangles

entry = dict(unit_id=HERE.name, reference_height=256, source_facing='right', frames=[], clips={},
    source_scale_by_image={}, source_scale_reason='Fixed scale per original source matches the established approximately 235px body. Hip centers and planted soles anchor the poses.',
    provenance=dict(tool='builtin_image_gen', sources=[], generation_lineage=(HERE/'move_generation.json').relative_to(ROOT).as_posix()))
phases = [
    ('move_v2', [330,180], [335,393], .60),
    ('move_v2', [820,180], [805,391], .60),
    ('move_v1', [300,1340], [295,1518], .64),
    ('move_near_half_v3', [380,220], [375,625], .38),
    ('move_support_v4', [550,320], [555,855], .28),
    ('move_support_v4', [1400,350], [1410,855], .28),
    ('move_near_half_v3', [380,850], [383,1246], .38),
    ('move_v2', [820,570], [805,773], .60),
]
for index, (stem, seed, anchor, scale) in enumerate(phases):
    source = HERE / (stem+'.png'); prompt = HERE / (stem+'.prompt.txt')
    path = source.relative_to(ROOT).as_posix()
    if path not in entry['source_scale_by_image']:
        entry['provenance']['sources'].append(dict(image=path, sha256=hashlib.sha256(source.read_bytes()).hexdigest(), prompt=prompt.relative_to(ROOT).as_posix(), prompt_sha256=hashlib.sha256(prompt.read_bytes()).hexdigest()))
    entry['source_scale_by_image'][path] = scale
    entry['frames'].append(dict(name=f'move_{index}', clip='move', source=path, rects=body_rectangles(source,seed,8), anchor=anchor, scale=scale, alpha_noise_cutoff=8, crop_recipe=dict(tool='tools/refine_fluid_frame_crops.py',seed=seed,cutoff=8)))
entry['clips']['move'] = dict(indices=list(range(8)),frame_msec=110,loop=True,
    painted_phase_order=['far contact','far support','near passing','near reach','near contact','near support','far passing','far reach'])
entry['visual_review'] = dict(status='accepted_selected_clips', notes='Native 128px review accepted eight original reciprocal poses, left-foot contact/support, opposite knee lifts, visible sword-arm swing and complete blade tips. Candidate 11 and imported live 120 focused checks passed; all prior approved action source recipes unchanged.')
(HERE/'move_handoff.json').write_text(json.dumps(dict(schema_version=1,units=[entry]),indent=2)+'\n',encoding='utf-8')
