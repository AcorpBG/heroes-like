"""Register Firstlight Colossus original mechanical actions and reciprocal gait."""
import hashlib
import json
import sys
from pathlib import Path

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[6]
sys.path.insert(0,str(ROOT/'tools'))
from refine_fluid_frame_crops import body_rectangles

entry=dict(unit_id=HERE.name,reference_height=256,source_facing='right',frames=[],clips={},source_scale_by_image={},
    source_scale_reason='One fixed anatomical scale per original source matches the existing approximately 224px halo-to-sole body. Pelvis and planted soles provide registration; no per-pose resizing or deformation.',
    provenance=dict(tool='builtin_image_gen',sources=[],reference=(HERE/'identity_reference.png').relative_to(ROOT).as_posix(),generation_lineage=(HERE/'generation.json').relative_to(ROOT).as_posix()))

def add(clip,stem,seeds,centers,scale,floors=None,extras=None):
    source=HERE/(stem+'.png');prompt=HERE/(stem+'.prompt.txt');path=source.relative_to(ROOT).as_posix()
    if path not in entry['source_scale_by_image']:
        entry['provenance']['sources'].append(dict(image=path,sha256=hashlib.sha256(source.read_bytes()).hexdigest(),prompt=prompt.relative_to(ROOT).as_posix(),prompt_sha256=hashlib.sha256(prompt.read_bytes()).hexdigest()))
    entry['source_scale_by_image'][path]=scale
    for n,(seed,cx) in enumerate(zip(seeds,centers)):
        rects=body_rectangles(source,seed,8)
        extra=(extras or {}).get(n,[])
        for point in extra:rects.extend(body_rectangles(source,point,8))
        rects=[list(r) for r in sorted(set(tuple(r) for r in rects))]
        floor=(floors or [None]*len(seeds))[n]
        if floor is None:floor=max(r[3] for r in rects)
        index=len(entry['frames'])
        entry['frames'].append(dict(name=f'{clip}_{index}',clip=clip,source=path,rects=rects,anchor=[cx,floor],scale=scale,alpha_noise_cutoff=8,crop_recipe=dict(tool='tools/refine_fluid_frame_crops.py',seed=seed,cutoff=8,additional_seeds=extra)))
        entry['clips'].setdefault(clip,dict(indices=[],frame_msec=110,loop=clip in ('idle','move')))['indices'].append(index)


add('idle','idle_v1',[(290,165),(755,165),(290,540),(770,540),(290,915),(755,915),(290,1290),(750,1290)],[290,755,290,770,290,755,290,750],.612)
# Start from the complete idle ready pose: attack-master pose1 clips the halo.
add('attack','idle_v1',[(290,165)],[290],.612)
add('attack','attack_v1',[(770,170),(315,560),(780,560)],[770,315,780],.623)
# Original contact over-rotates to a rear view. Corrected front-three-quarter punch.
add('attack','corrections_v1',[(1740,345)],[1740],.332)
add('attack','attack_v1',[(780,920)],[780],.623)
# Finish the retraction in the matching ready stance instead of the oversized
# recovery paintings in the first attack master. No duplicate inside this clip.
add('attack','idle_v1',[(290,1290),(750,1290)],[290,750],.612)
entry['clips']['attack'].update(frame_msec=125,contact_frame=4,static_frame=0)
add('ranged','ranged_v2',[(200,255),(585,255),(975,255),(1360,255),(220,760),(595,760),(990,760),(1360,760)],[200,585,975,1360,220,595,990,1360],.502)
entry['clips']['ranged'].update(frame_msec=125,contact_frame=4,static_frame=0)
add('hit','reactions_v1',[(310,160),(755,160),(330,560),(780,560)],[310,755,330,780],.630)
add('defend','reactions_v1',[(310,950),(770,950),(310,1340),(770,1340)],[310,770,310,770],.630)
add('cast','cast_v1',[(290,170),(790,170),(300,550),(790,550),(300,930),(785,930),(295,1320),(790,1320)],[290,790,300,790,300,785,295,790],.640)
add('death','death_v1',[(285,210),(800,270),(290,660),(800,730),(270,1080),(760,1130),(240,1430),(760,1430)],[285,800,290,800,280,760,270,790],.508)
# The first walk master mixed leading legs; select by painted anatomy.
# Corrected far contact/support -> near passing/reach/contact/support -> far passing/reach.
add('move','move_far_corrections_v1',[(1050,300)],[1050],.354)
add('move','corrections_v1',[(375,300),(1010,300)],[375,1010],.332)
add('move','move_far_v1',[(1010,855),(380,260),(1010,260),(380,855)],[1010,380,1010,380],.420)
add('move','move_far_corrections_v1',[(360,300)],[360],.354)
entry['clips']['idle'].update(frame_msec=155)
entry['clips']['cast'].update(frame_msec=130,contact_frame=4)
entry['clips']['defend'].update(frame_msec=125,static_frame=3)
entry['clips']['death'].update(frame_msec=150)
entry['clips']['move'].update(frame_msec=125,painted_phase_order=['far contact','far support','near passing','near heel reach','near contact','near support','far passing','far heel reach'])
entry['visual_review']=dict(status='accepted',notes='Original paintings and actual Godot 128px phases reviewed for ivory/gold construct identity, complete four-lens halo, visible fingers/elbows and fixed body scale. Melee contact uses corrected front-three-quarter punch; oversized recovery poses and clipped first halo were rejected in favor of matching ready transitions. Ranged v2 replaces the first master after native review exposed charge-pose scale jumps; it contains no traveling beam so runtime owns the projectile. Walk phases selected by actual blue near-thigh anatomy, including corrected far support and near passing. Dedicated crossed-arm crouch, open-hand optical support, hit recovery and eight-step intact power-down/corpse reviewed. Imported battle/map checks follow publication.')
(HERE/'handoff.json').write_bytes((json.dumps(dict(schema_version=1,units=[entry]),indent=2)+'\n').encode())
print({c:len(s['indices']) for c,s in entry['clips'].items()})
