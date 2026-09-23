"""Pack reviewed original gait paintings without deforming approved creature art."""
import hashlib
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[6]
sys.path.insert(0, str(ROOT/'tools'))
from refine_fluid_frame_crops import body_rectangles

entry = dict(unit_id=HERE.name, reference_height=256, source_facing='right', frames=[], clips={},
    source_scale_by_image={}, source_scale_reason='Fixed scale per original source matches the established 233px body. Pelvic centers and soles set placement; no deformation or per-pose fitting.',
    provenance=dict(tool='builtin_image_gen',sources=[],generation_lineage=(HERE/'move_generation.json').relative_to(ROOT).as_posix()))
phases = [
    ('move_half_a_v2',[380,180],[375,471],.55),
    ('move_half_a_v2',[1130,180],[1130,471],.55),
    ('move_passing_v12',[500,230],[520,758],.32),
    ('move_near_reach_v8',[1120,300],[1120,853],.30),
    ('move_contacts_v4',[1120,300],[1120,870],.30),
    ('move_near_support_v10',[800,350],[800,1005],.235),
    ('move_passing_v11',[1400,230],[1430,771],.32),
    ('move_near_v7',[400,300],[407,856],.30),
]
for index,(stem,seed,anchor,scale) in enumerate(phases):
    source=HERE/(stem+'.png');prompt=HERE/(stem+'.prompt.txt')
    path=source.relative_to(ROOT).as_posix()
    if path not in entry['source_scale_by_image']:
        entry['provenance']['sources'].append(dict(image=path,sha256=hashlib.sha256(source.read_bytes()).hexdigest(),
            prompt=prompt.relative_to(ROOT).as_posix(),prompt_sha256=hashlib.sha256(prompt.read_bytes()).hexdigest()))
    entry['source_scale_by_image'][path]=scale
    entry['frames'].append(dict(name=f'move_{index}',clip='move',source=path,rects=body_rectangles(source,seed,8),
        anchor=anchor,scale=scale,alpha_noise_cutoff=8,crop_recipe=dict(tool='tools/refine_fluid_frame_crops.py',seed=seed,cutoff=8)))
entry['clips']['move']=dict(indices=list(range(8)),frame_msec=110,loop=True,
    painted_phase_order=['far contact','far support','near passing','near reach','near contact','near support','far passing','far reach'])
entry['visual_review']=dict(status='accepted_selected_clips',notes='Native 128px review accepted opposing contacts and knee lifts, support/reach phases, intact three-pod two-hand weapon and consistent body scale. Corrected candidate 11 and imported live 134 focused checks passed.')
(HERE/'move_handoff.json').write_text(json.dumps(dict(schema_version=1,units=[entry]),indent=2)+'\n',encoding='utf-8')
