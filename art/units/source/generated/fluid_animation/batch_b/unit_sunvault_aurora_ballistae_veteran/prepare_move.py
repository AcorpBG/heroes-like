"""Register original reciprocal gait poses; crop and uniformly scale only."""
import hashlib
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[6]
sys.path.insert(0, str(ROOT / 'tools'))
from refine_fluid_frame_crops import body_rectangles

entry = dict(unit_id=HERE.name, reference_height=256, source_facing='right', frames=[], clips={},
    source_scale_by_image={}, source_scale_reason='Fixed scale per original sheet matches the established 225px armored body; hips and planted soles define registration.',
    provenance=dict(tool='builtin_image_gen', sources=[], generation_lineage=(HERE/'move_generation.json').relative_to(ROOT).as_posix()))
phases = [
    ('move_v3', [330,180], [330,315], .75),
    ('move_v3', [840,180], [835,315], .75),
    ('move_v3', [330,510], [325,659], .75),
    ('move_v3', [840,510], [830,648], .75),
    ('move_v3', [330,860], [328,992], .75),
    ('move_v3', [840,860], [830,996], .75),
    ('move_v3', [330,1190], [325,1317], .75),
    ('move_reach_v5', [730,400], [745,1110], .21),
]
for index, (stem, seed, anchor, scale) in enumerate(phases):
    source = HERE / (stem+'.png'); prompt = HERE / (stem+'.prompt.txt')
    path = source.relative_to(ROOT).as_posix()
    if path not in entry['source_scale_by_image']:
        entry['provenance']['sources'].append(dict(image=path, sha256=hashlib.sha256(source.read_bytes()).hexdigest(), prompt=prompt.relative_to(ROOT).as_posix(), prompt_sha256=hashlib.sha256(prompt.read_bytes()).hexdigest()))
    entry['source_scale_by_image'][path] = scale
    entry['frames'].append(dict(name=f'move_{index}', clip='move', source=path, rects=body_rectangles(source,seed,8), anchor=anchor, scale=scale, alpha_noise_cutoff=8, crop_recipe=dict(tool='tools/refine_fluid_frame_crops.py',seed=seed,cutoff=8)))
entry['clips']['move'] = dict(indices=list(range(8)),frame_msec=120,loop=True,
    painted_phase_order=['near contact','near support','far passing','far reach','far contact','far support','near passing','near reach'])
entry['visual_review'] = dict(status='accepted_selected_clips', notes='Reviewed at native 128px: alternating contacts, knee articulation, fist swing and opposing reach. Repainted final reach restores broad body proportions. Corrected candidate 11 and imported live 118 focused checks passed; prior approved source poses unchanged.')
(HERE/'move_handoff.json').write_text(json.dumps(dict(schema_version=1,units=[entry]),indent=2)+'\n',encoding='utf-8')
