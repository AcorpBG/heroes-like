"""Register original idle and gait paintings with body/ground anchors."""
import hashlib
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[6]
sys.path.insert(0, str(ROOT / 'tools'))
from refine_fluid_frame_crops import body_rectangles

entry = dict(unit_id=HERE.name, reference_height=256, source_facing='right', frames=[], clips={},
    source_scale_by_image={}, source_scale_reason='Fixed scale per original image matches the established approximately 220px body. Pelvis centers and soles provide registration without deforming paintings.',
    provenance=dict(tool='builtin_image_gen', sources=[], generation_lineage=(HERE/'remaining_generation.json').relative_to(ROOT).as_posix()))
idle_seeds = [(270,160),(770,160),(270,550),(770,550),(270,930),(770,930),(270,1320),(770,1320)]
idle_anchors = [(270,387),(770,388),(270,771),(770,771),(270,1154),(770,1154),(270,1530),(770,1530)]
idle = [('idle_v1',list(idle_seeds[i]),list(idle_anchors[i]),.58) for i in [0,2,1,3,4,5,6,7]]
move = [
    ('move_v2',[300,160],[300,378],.60),
    ('move_v2',[770,160],[770,378],.60),
    ('move_v2',[300,550],[300,762],.60),
    ('move_v2',[770,550],[770,756],.60),
    ('move_near_v3',[300,240],[300,671],.33),
    ('move_near_v3',[780,240],[775,671],.33),
    ('move_near_v3',[300,950],[300,1424],.33),
    ('move_near_v3',[780,970],[780,1424],.33),
]
attack_seeds = [(270,160),(740,160),(270,550),(740,550),(270,940),(740,940),(270,1270),(740,1270)]
attack_grounds = [378,378,750,750,1125,1125,1505,1505]
attack = [('attack_v3',list(seed),[256 if i%2==0 else 768,attack_grounds[i]],.60) for i,seed in enumerate(attack_seeds)]
for clip, phases, msec in [('idle',idle,140),('move',move,110),('attack',attack,100)]:
    indices=[]
    for number,(stem,seed,anchor,scale) in enumerate(phases):
        source=HERE/(stem+'.png');prompt=HERE/(stem+'.prompt.txt');path=source.relative_to(ROOT).as_posix()
        if path not in entry['source_scale_by_image']:
            entry['provenance']['sources'].append(dict(image=path,sha256=hashlib.sha256(source.read_bytes()).hexdigest(),prompt=prompt.relative_to(ROOT).as_posix(),prompt_sha256=hashlib.sha256(prompt.read_bytes()).hexdigest()))
        entry['source_scale_by_image'][path]=scale
        indices.append(len(entry['frames']))
        entry['frames'].append(dict(name=f'{clip}_{number}',clip=clip,source=path,rects=body_rectangles(source,seed,8),anchor=anchor,scale=scale,alpha_noise_cutoff=8,crop_recipe=dict(tool='tools/refine_fluid_frame_crops.py',seed=seed,cutoff=8)))
    entry['clips'][clip]=dict(indices=indices,frame_msec=msec,loop=clip != 'attack')
# The held prism is intentionally detached from the hand in several paintings.
prism_seeds = [(365,85),(849,109),(250,451),(930,463),(459,823),(891,830),(367,1226),(878,1224)]
for index,seed in zip(entry['clips']['attack']['indices'],prism_seeds):
    frame=entry['frames'][index]
    frame['rects']=[list(r) for r in sorted(set(tuple(r) for r in frame['rects']+body_rectangles(HERE/'attack_v3.png',seed,8)))]
    frame['crop_recipe']['additional_seed']=seed
entry['clips']['attack']['static_frame']=0
entry['clips']['attack']['contact_frame']=4
entry['clips']['move']['painted_phase_order']=['far contact','far support','near passing','near reach','near contact','near support','far passing','far reach']
entry['visual_review']=dict(status='accepted',notes='Reviewed original paintings and actual 128px candidate render: eight idle poses articulate the free hand toward the prism and recover; eight gait phases alternate foot contacts with visible knee/arm movement. Fixed source scale and pelvis/sole registration preserve the prism hand, tablets and costume; raised passing poses retain natural body rise. Attack connected-body crops exclude adjacent-row hair fragments and restore recovery crowns; sole registration removes floating contact poses.')
(HERE/'remaining_handoff.json').write_text(json.dumps(dict(schema_version=1,units=[entry]),indent=2)+'\n',encoding='utf-8')
