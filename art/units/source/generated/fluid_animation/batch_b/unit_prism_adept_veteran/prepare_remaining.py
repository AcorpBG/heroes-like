"""Register original movement/ranged paintings by anatomy, excluding flying projectiles."""
import hashlib
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[6]
sys.path.insert(0, str(ROOT/'tools'))
from refine_fluid_frame_crops import body_rectangles

entry = dict(unit_id=HERE.name, reference_height=256, source_facing='right', frames=[], clips={},
             source_scale_by_image={}, source_scale_reason='Fixed scale per original master; horizontal pelvis and sole anchors avoid bounding-box shifts from scarf/bow. No repainting, warping or per-pose scale fitting.',
             provenance=dict(tool='builtin_image_gen', sources=[]))
def add(stem, clip, scale, seeds, anchors):
    source = HERE/(stem+'.png')
    prompt = HERE/(stem+'.prompt.txt')
    path = source.relative_to(ROOT).as_posix()
    entry['source_scale_by_image'][path] = scale
    entry['provenance']['sources'].append(dict(image=path, sha256=hashlib.sha256(source.read_bytes()).hexdigest(),
        prompt=prompt.relative_to(ROOT).as_posix(), prompt_sha256=hashlib.sha256(prompt.read_bytes()).hexdigest(),
        original_generation=(HERE/(stem+'.generation.json')).relative_to(ROOT).as_posix()))
    for seed, anchor in zip(seeds, anchors):
        index=len(entry['frames'])
        entry['frames'].append(dict(name=f'{clip}_{index}', clip=clip, source=path,
            rects=body_rectangles(source,seed,8), anchor=anchor, scale=scale, alpha_noise_cutoff=8,
            crop_recipe=dict(tool='tools/refine_fluid_frame_crops.py',seed=seed,cutoff=8)))
        entry['clips'].setdefault(clip,dict(indices=[],frame_msec=110,loop=clip=='move'))['indices'].append(index)

add('ranged_v1','ranged',.48,
    [[200,250],[580,250],[965,250],[1360,250],[170,760],[570,760],[970,760],[1360,760]],
    [[201,503],[581,503],[977,503],[1366,503],[176,996],[581,996],[968,996],[1355,996]])
entry['clips']['ranged'].update(contact_frame=4,frame_msec=95)
add('move_v3','move',.55,
    [[290,130],[785,130],[290,510],[785,510],[290,900],[785,900],[290,1290],[785,1290]],
    [[290,381],[782,381],[296,762],[785,762],[294,1138],[786,1138],[296,1521],[790,1521]])
entry['visual_review']=dict(status='accepted_selected_clips',notes='Native-scale review accepted original movement v3 and ranged v1 body-only crops: articulated gait, nock/draw/release/recovery, runtime-owned arrow flight. Candidate 27 and live 134 focused checks passed.')
(HERE/'remaining_handoff.json').write_text(json.dumps(dict(schema_version=1,units=[entry]),indent=2)+'\n',encoding='utf-8')
