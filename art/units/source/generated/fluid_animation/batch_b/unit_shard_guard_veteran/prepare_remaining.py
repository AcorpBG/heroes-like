"""Register original articulated idle and reciprocal march paintings."""
import hashlib
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[6]
sys.path.insert(0, str(ROOT / 'tools'))
from refine_fluid_frame_crops import body_rectangles

entry = dict(unit_id=HERE.name, reference_height=256, source_facing='right', frames=[], clips={},
    source_scale_by_image={}, source_scale_reason='Fixed scale per original master matches the established approximately 210px armored figure. Hip centers and soles define ground registration.',
    provenance=dict(tool='builtin_image_gen', sources=[], generation_lineage=(HERE/'remaining_generation.json').relative_to(ROOT).as_posix()))
idle = [('idle_v3',[x,y],[ax,ground],.56) for x,y,ax,ground in [
    (270,180,270,375),(740,180,735,375),(270,570,270,760),(740,570,740,760),
    (270,950,270,1135),(740,950,735,1135),(270,1340,270,1514),(740,1340,735,1514)]]
move = [
    ('move_v2',[200,200],[205,441],.60),
    ('move_v2',[580,200],[585,441],.60),
    ('move_v2',[960,200],[965,441],.60),
    ('move_v2',[1340,200],[1345,442],.60),
    ('move_far_v3',[340,250],[370,573],.37),
    ('move_support_v5',[550,220],[555,499],.43),
    ('move_support_v5',[550,730],[555,1000],.43),
    ('move_support_v5',[550,1220],[550,1484],.43),
]
for clip, phases, msec in [('idle',idle,135),('move',move,115)]:
    indices = []
    for number, (stem, seed, anchor, scale) in enumerate(phases):
        source = HERE / (stem+'.png'); prompt = HERE / (stem+'.prompt.txt')
        path = source.relative_to(ROOT).as_posix()
        if path not in entry['source_scale_by_image']:
            entry['provenance']['sources'].append(dict(image=path, sha256=hashlib.sha256(source.read_bytes()).hexdigest(), prompt=prompt.relative_to(ROOT).as_posix(), prompt_sha256=hashlib.sha256(prompt.read_bytes()).hexdigest()))
        entry['source_scale_by_image'][path] = scale
        indices.append(len(entry['frames']))
        entry['frames'].append(dict(name=f'{clip}_{number}', clip=clip, source=path, rects=body_rectangles(source,seed,8), anchor=anchor, scale=scale, alpha_noise_cutoff=8, crop_recipe=dict(tool='tools/refine_fluid_frame_crops.py',seed=seed,cutoff=8)))
    entry['clips'][clip] = dict(indices=indices,frame_msec=msec,loop=True)
entry['clips']['move']['painted_phase_order'] = ['near contact','near support','far passing','far reach','far contact','far support','near passing','near reach']
entry['visual_review'] = dict(status='accepted_selected_clips', notes='Native 128px and map idle review accepted visible glaive-arm lift/shield adjustment and reciprocal march with opposing support legs, knee lift and heel reach. Candidate 21 and imported live 118 focused checks passed; previous approved action recipes unchanged.')
(HERE/'remaining_handoff.json').write_text(json.dumps(dict(schema_version=1,units=[entry]),indent=2)+'\n',encoding='utf-8')
