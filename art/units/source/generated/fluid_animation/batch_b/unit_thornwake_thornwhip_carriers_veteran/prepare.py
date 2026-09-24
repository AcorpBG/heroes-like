"""Pack Vinebraid Lashkeeper paintings; original-pixel extraction only."""
import hashlib
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = next(p for p in HERE.parents if (p / 'project.godot').is_file())
sys.dont_write_bytecode = True
sys.path.insert(0, str(ROOT / 'tools'))
from refine_fluid_frame_crops import body_rectangles

entry = dict(unit_id=HERE.name, reference_height=256, source_facing='right', frames=[], clips={}, source_scale_by_image={},
    source_scale_reason='One fixed anatomical scale per original master matches the inherited approximately 232px standing body at 256px reference height. Kneeling and corpse frames keep standing-sheet scale. Foot or body-contact anchors exclude foreground whip coils.',
    provenance=dict(tool='builtin_image_gen', sources=[], reference=(HERE/'identity_reference.png').relative_to(ROOT).as_posix(), generation_lineage=(HERE/'generation.json').relative_to(ROOT).as_posix()))

def add(clip, stem, seeds, anchors, scale, extras=None):
    source = HERE/(stem+'.png')
    prompt = HERE/(stem+'.prompt.txt')
    path = source.relative_to(ROOT).as_posix()
    if path not in entry['source_scale_by_image']:
        entry['provenance']['sources'].append(dict(image=path, sha256=hashlib.sha256(source.read_bytes()).hexdigest(), prompt=prompt.relative_to(ROOT).as_posix(), prompt_sha256=hashlib.sha256(prompt.read_bytes()).hexdigest()))
    entry['source_scale_by_image'][path] = scale
    for n, (seed, anchor) in enumerate(zip(seeds, anchors)):
        rects = body_rectangles(source, seed, 8)
        extra = (extras or {}).get(n, [])
        for point in extra:
            rects.extend(body_rectangles(source, point, 8))
        rects = [list(r) for r in sorted(set(tuple(r) for r in rects))]
        index = len(entry['frames'])
        spec = entry['clips'].setdefault(clip, dict(indices=[], frame_msec=110, loop=clip in ('idle','move')))
        entry['frames'].append(dict(name=f'{clip}_{len(spec["indices"])}', clip=clip, source=path, rects=rects, anchor=anchor, scale=scale, alpha_noise_cutoff=8,
            crop_recipe=dict(tool='tools/refine_fluid_frame_crops.py', seed=seed, cutoff=8, additional_seeds=extra, reason='Original connected painted pixels; anatomical foot/body ground anchor.')))
        spec['indices'].append(index)

add('idle','idle_v1',[(280,180),(770,180),(280,560),(770,560),(280,940),(770,940),(280,1320),(770,1320)],
    [(280,379),(770,378),(280,761),(770,761),(280,1146),(770,1146),(280,1528),(770,1528)], .632)
add('move','move_near_v1',[(350,220),(1010,220),(350,820),(1010,820)],
    [(355,565),(1010,565),(355,1168),(1010,1168)], .424)
add('move','move_far_v1',[(320,250),(980,250),(340,870),(980,870)],
    [(330,605),(985,605),(350,1230),(985,1230)], .395)
add('attack','attack_v1',[(270,170),(730,170)], [(250,370),(730,376)], .655)
# Original attack cells2/3 swap the whip grip. Retain original correctly held
# windup corrections and the original contact, follow-through and recovery.
add('attack','attack_windup_v1',[(830,300),(285,925)], [(825,681),(280,1270)], .412)
add('attack','attack_v1',[(220,930),(740,930),(260,1290),(770,1290)],
    [(220,1124),(740,1124),(260,1492),(770,1495)], .655)
add('hit','reactions_v1',[(275,180),(270,550),(275,940),(275,1320)],
    [(280,389),(280,770),(280,1148),(280,1523)], .620)
add('defend','reactions_v1',[(775,180),(775,560),(775,940),(775,1320)],
    [(775,389),(775,770),(775,1148),(775,1523)], .620)
add('cast','cast_v1',[(280,180),(775,180),(280,560)], [(280,372),(775,372),(280,758)], .650)
# Original support cells3/4 raise the weapon arm but leave the whip floating.
# The replacement keeps the far grip low and raises the empty near hand.
add('cast','cast_peak_v1',[(455,370),(1325,370)], [(455,847),(1325,847)], .281)
add('cast','cast_v1',[(775,940),(280,1320),(775,1320)], [(775,1138),(280,1523),(775,1523)], .650)
add('death','death_v1',[(320,175),(1090,220),(325,490),(1110,520),(320,725),(1080,735),(320,925),(1090,935)],
    [(325,373),(1090,373),(325,620),(1110,626),(335,804),(1080,807),(335,986),(1080,992)], .640,
    extras={2:[(535,596)],3:[(1345,596)],4:[(618,777)],5:[(1410,783)],6:[(615,976)],7:[(1410,981)]})
for name, spec in entry['clips'].items():
    spec.update(static_frame=0, frame_msec={'idle':155,'move':110,'attack':115,'hit':115,'defend':130,'cast':130,'death':145}[name])
entry['clips']['attack']['contact_frame'] = 4
entry['clips']['attack']['frame_durations_msec'] = [90,110,110,85,100,120,130,130]
entry['clips']['cast']['contact_frame'] = 4
entry['clips']['cast']['frame_durations_msec'] = [110,120,130,130,180,140,130,130]
entry['clips']['defend']['static_frame'] = 3
entry['clips']['death']['static_frame'] = 7
entry['visual_review'] = dict(status='accepted_selected_clips', notes='Reviewed original paintings and ordered Windows Godot phases at actual 128px reference height. Forty-eight distinct poses across seven actions: visible two-hand coil idle; reciprocal near/far walk with foreground thigh rooted below side pouch and far thigh under tabard; far-handed whip anticipation, contact and recovery; four recoils; four held guards; empty near-hand physical support; eight-stage collapse ending grounded with released whip retained. Attack cells2/3 and support cells3/4 are excluded for grip/hand errors and replaced by original corrected drawings. Initial move_v1 is rejected for repeated leading leg. One fixed scale per original master, body-ground registration independent of whip extents, no duplicate/ping-pong/reflection/warping. Near walk opaque edges are contained; far master has only a small antialiased cape-tip boundary (left maximum alpha141, right19), no missing opaque limb or weapon. Focused candidate passed116 assertions. Source and timed phase inspection support this acceptance; continuous playback, Linux execution and a manual playtest are not claimed.')
(HERE/'handoff.json').write_text(json.dumps(dict(schema_version=1,units=[entry]),indent=2)+'\n',encoding='utf-8')
for name, clip in entry['clips'].items():
    print(name, [(min(r[0] for r in f['rects']), min(r[1] for r in f['rects']), max(r[2] for r in f['rects']), max(r[3] for r in f['rects'])) for f in [entry['frames'][i] for i in clip['indices']]])
print('Prepared',len(entry['frames']),'paintings across',len(entry['clips']),'actions')
