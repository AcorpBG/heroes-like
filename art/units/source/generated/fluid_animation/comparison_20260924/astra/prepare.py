"""Rebuild the Astra Amberhook candidate from immutable original paintings.

Shared selections retain their original source recipes and generation lineage.
Only crop, registration, fixed sheet scale and authored ordering are applied.
"""
import copy
import hashlib
import json
import sys
from pathlib import Path
from PIL import Image

HERE = Path(__file__).resolve().parent
ROOT = next(p for p in HERE.parents if (p / 'project.godot').is_file())
UNIT_ID = 'unit_thornwake_seedcutters_veteran'
SHARED = ROOT / 'art/units/source/generated/fluid_animation/batch_b' / UNIT_ID
sys.dont_write_bytecode = True
sys.path.insert(0, str(ROOT / 'tools'))
from refine_fluid_frame_crops import body_rectangles

def read(p): return json.loads(p.read_text(encoding='utf-8-sig'))
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def rel(p): return p.relative_to(ROOT).as_posix()
def write(p, obj): p.write_text(json.dumps(obj, indent=2) + '\n', encoding='utf-8')

reference = read(SHARED / 'identity_reference.json')
assert sha(ROOT / reference['source']) == reference['source_sha256']
assert sha(SHARED / 'identity_reference.png') == reference['output_sha256']
with Image.open(ROOT / reference['source']) as im, Image.open(SHARED / 'identity_reference.png') as cropped:
    assert im.crop(reference['crop']).convert('RGBA').tobytes() == cropped.convert('RGBA').tobytes()
live = next(r for r in read(ROOT / 'content/unit_animation_manifest.json')['items'] if r['unit_id'] == UNIT_ID)
assert live['pose_reference_height'] == 256

base = read(SHARED / 'handoff.json')['units'][0]
entry = copy.deepcopy(base)
entry['unit_id'] = UNIT_ID
entry['frames'] = []
entry['clips'] = {}
entry['source_scale_by_image'] = {}
entry['accepted_clips'] = []

def preserve(clip):
    spec = copy.deepcopy(base['clips'][clip])
    spec['indices'] = []
    for old in base['clips'][clip]['indices']:
        f = copy.deepcopy(base['frames'][old])
        spec['indices'].append(len(entry['frames']))
        entry['frames'].append(f)
        entry['source_scale_by_image'][f['source']] = f['scale']
    entry['clips'][clip] = spec

def sheet(clip, stem, scale, anchors, seeds):
    path = HERE / (stem + '.png')
    entry['source_scale_by_image'][rel(path)] = scale
    spec = dict(indices=[], loop=clip in ('idle','move'), static_frame=0, frame_msec={'idle':155,'move':115,'cast':140}[clip])
    for i, (anchor, seed) in enumerate(zip(anchors, seeds)):
        rects = body_rectangles(path, seed, 8)
        if stem == 'near_half_v2' and i < 2:
            # Separate a faint-alpha bridge in the blank gutter between blades.
            left,right = (0,524) if i == 0 else (524,1024)
            rects=[[max(x0,left),y0,min(x1,right),y1] for x0,y0,x1,y1 in rects if max(x0,left)<min(x1,right)]
        if stem == 'far_half_v3' and i >= 2:
            left,right = (0,544) if i == 2 else (544,1024)
            rects=[[max(x0,left),y0,min(x1,right),y1] for x0,y0,x1,y1 in rects if max(x0,left)<min(x1,right)]
        bounds = [min(r[0] for r in rects), min(r[1] for r in rects), max(r[2] for r in rects), max(r[3] for r in rects)]
        assert bounds[0] > 0 and bounds[2] <= 1024, bounds
        spec['indices'].append(len(entry['frames']))
        entry['frames'].append(dict(name=f'{clip}_{i}', clip=clip, source=rel(path), rects=rects,
            anchor=anchor, scale=scale, alpha_noise_cutoff=8,
            crop_recipe=dict(tool='tools/refine_fluid_frame_crops.py', seed=seed, cutoff=8,
                             body_contact_floor=anchor[1], reason='Anatomical pelvis registration and planted boot contact; source pixels only.')))
        if stem == 'near_half_v2' and i < 2:
            entry['frames'][-1]['crop_recipe']['horizontal_clip']=[left,right]
            entry['frames'][-1]['crop_recipe']['reason']='Blank original gutter at x524 separates faint alpha bridge between complete adjacent blades.'
        if stem == 'far_half_v3':
            entry['frames'][-1]['crop_recipe']['edge_review']='Blade painted edge fully inside source; only faint alpha glow (maximum33) reaches right canvas edge.'
            if i >= 2:
                entry['frames'][-1]['crop_recipe']['horizontal_clip']=[left,right]
                entry['frames'][-1]['crop_recipe']['reason']='Original empty gutter at x544 separates faint bridge between both complete source figures.'
        print(clip, i, bounds, anchor)
    entry['clips'][clip] = spec

sheet('idle', 'idle_cycle_v1', .625,
      [(285,382),(760,382),(285,766),(760,766),(285,1148),(760,1148),(285,1530),(760,1530)],
      [(280,180),(750,180),(280,565),(750,565),(280,950),(750,950),(280,1340),(750,1340)])
sheet('move', 'near_half_v2', .33,
      [(265,732),(750,730),(270,1480),(760,1486)],
      [(270,240),(750,240),(270,980),(750,980)])
near_spec = copy.deepcopy(entry['clips']['move'])
sheet('move', 'far_half_v3', .37,
      [(290,662),(810,661),(300,1365),(815,1369)],
      [(280,240),(800,240),(280,950),(800,950)])
far_indices = entry['clips']['move']['indices']
for i,index in enumerate(far_indices): entry['frames'][index]['name']='move_'+str(i+4)
entry['clips']['move']['indices'] = near_spec['indices'] + far_indices
entry['clips']['move']['contact_frame'] = 2
for clip in ('attack','hit','defend'):
    preserve(clip)
sheet('cast', 'cast_cycle_v1', .65,
      [(290,366),(755,366),(290,752),(755,748),(290,1158),(755,1158),(290,1522),(755,1524)],
      [(280,180),(750,180),(280,550),(750,550),(280,950),(750,950),(280,1340),(750,1340)])
entry['clips']['cast']['contact_frame'] = 4
entry['clips']['cast']['frame_durations_msec'] = [110,140,140,140,180,140,140,150]
# Faint source-alpha bridge connects preceding-row boots to the raised hooks.
# Keep complete side blades and all of this pose below y780; exclude only the
# previous boots' central strip. Bounds verified in original source pixels.
peak = entry['frames'][entry['clips']['cast']['indices'][4]]
regions = [(0,780,512,1536),(0,0,205,780),(373,0,512,780)]
peak['rects'] = [[max(x0,a0),max(y0,b0),min(x1,a1),min(y1,b1)]
    for x0,y0,x1,y1 in peak['rects'] for a0,b0,a1,b1 in regions
    if max(x0,a0)<min(x1,a1) and max(y0,b0)<min(y1,b1)]
peak['crop_recipe']['reviewed_original_pixel_regions']=regions
peak['crop_recipe']['reason']='Exclude two preceding-row boots from raised-arm component, preserving both complete sickles and current body.'

# Grounded middle collapse: identical .30 sheet scale matches head/torso size,
# never normalize a kneeling pose to the height of a standing pose.
death_spec = dict(indices=[],loop=False,static_frame=8,frame_msec=150)
def old_death(i):
    f = copy.deepcopy(base['frames'][base['clips']['death']['indices'][i]])
    f['name'] = 'death_' + str(len(death_spec['indices']))
    death_spec['indices'].append(len(entry['frames'])); entry['frames'].append(f)
    entry['source_scale_by_image'][f['source']] = f['scale']
old_death(0); old_death(1)
death_path = HERE/'death_middle_v2.png'
for i,(seed,anchor,extras) in enumerate([
    ((300,330),(310,696),[]),
    ((945,395),(945,697),[(760,692)]),
    ((320,1000),(320,1198),[(140,1178),(485,1178)]),
    ((965,1050),(945,1165),[(770,1175),(1090,1185)]),
]):
    rects=body_rectangles(death_path,seed,8)
    for extra in extras: rects.extend(body_rectangles(death_path,extra,8))
    rects=[list(r) for r in sorted(set(tuple(r) for r in rects))]
    index=len(entry['frames']);death_spec['indices'].append(index)
    entry['frames'].append(dict(name='death_'+str(i+2),clip='death',source=rel(death_path),rects=rects,
        anchor=anchor,scale=.30,alpha_noise_cutoff=8,crop_recipe=dict(tool='tools/refine_fluid_frame_crops.py',seed=seed,
        additional_seeds=extras,cutoff=8,body_contact_floor=anchor[1],reason='Continuous release and forearm landing; body contact independent from loose weapons.')))
entry['source_scale_by_image'][rel(death_path)]=.30
old_death(5);old_death(6);old_death(7)
entry['clips']['death']=death_spec
# The shared row-3-right corpse has TWO separate ground blades at y1200,
# whereas its inherited second seed y1120 selected the forearm/body again.
# Select both original detached blade components explicitly.
landing = entry['frames'][death_spec['indices'][6]]
landing_seeds = [(620,1205),(900,1210)]
for seed in landing_seeds:
    landing['rects'].extend(body_rectangles(ROOT/landing['source'],seed,8))
landing['rects']=[list(r) for r in sorted(set(tuple(r) for r in landing['rects']))]
landing['crop_recipe']['additional_seeds'].extend(landing_seeds)
landing['crop_recipe']['reason']='Both released sickles selected from original row-3-right death pixels; inherited y1120 seed missed right ground blade.'

entry['provenance'].update(generation_lineage=rel(HERE / 'generation.json'),
    reused_generation_lineage=rel(SHARED / 'generation.json'),
    reused_handoff=dict(path=rel(SHARED / 'handoff.json'), sha256=sha(SHARED / 'handoff.json')))
entry['source_scale_reason'] = ('256 inherited reference height, approximately 232 painted anatomical pixels. '
    'New idle .625; walk near half .33 and far half .37 match about 232px anatomy and the same head size; no per-pose resizing. '
    'Support .65 uses standing anatomy excluding raised weapons; middle death .30 matches head/torso dimensions to shared death .50. '
    'No crouch/fall receives individual height normalization.')
entry['visual_review'] = dict(status='ready-for-parent-review', notes=(
    'Astra inspected all source sheets and ordered Windows Godot phase renders at 128px reference height and 64px map scale. '
    'New eight-pose idle retains low separate grips with expanding/relaxing elbow motion. Round1 replaces rejected movement: '
    'indices0-3 are near_half_v2 source cells0-3; indices4-7 are far_half_v3 source cells0-3. '
    'Near contact index2 has exposed thigh rooted below image-left pouch crossing IN FRONT of the distant thigh, '
    'displacing the tabard rearward. Far contact index6 has near thigh trailing left while the advance originates '
    'at image-right hip UNDER the central tabard. Both have separate reach, contact, load and passing poses. '
    'No reflection, reverse padding or warped articulation. '
    'Shared corrected attack, four hit and four held-guard paintings retained after source/native review. '
    'New eight-pose physical support raises and lowers both sickles; prior-row boots excluded through original-pixel regions. '
    'Nine-pose death preserves both weapons through sequential releases, palm/forearm landing and final grounded corpse; '
    'middle sheet has fixed .30 anatomical scale. Round1 fixes death index6 by extracting the second original dropped '
    'blade at source y1210 rather than inherited y1120 which selected body pixels. '
    'No within-clip duplicate paintings or cross-clip ready reuse in final selection. '
    'Focused native check passed 117 assertions including authored holds, contact timing, normal/fast/reduced motion, '
    'multihex gait duration and unchanged simulation state. Phase samples and ordering were inspected; continuous playback, '
    'live map shader playback, Linux execution and a manual playtest are not claimed. Independent parent acceptance pending.'))
calls = [
 ('near_key_v1', 'exec-9fd7a2af-2945-401c-9481-e68f5e2b0151.png', [SHARED/'identity_reference.png'], False),
 ('move_cycle_v1', 'exec-da4816ea-5217-4004-8b3c-7ed0eb65e7e5.png', [HERE/'near_key_v1.png',SHARED/'identity_reference.png'], False),
 ('idle_cycle_v1', 'exec-1d4cbd7e-7f8d-4480-877b-b5ab1c8126a8.png', [SHARED/'identity_reference.png'], True),
 ('cast_cycle_v1', 'exec-2fca02dd-31f8-4045-93ed-d98b0a036ab3.png', [SHARED/'identity_reference.png'], True),
 ('death_middle_v2', 'exec-81eab64d-79a4-4d10-8a61-335c5ab8b0fa.png', [SHARED/'identity_reference.png',SHARED/'death_middle_correction_v1.png'], True),
 ('near_contact_v2', 'exec-afdb1ac8-5985-4d64-9b86-ff1b8e027a62.png', [HERE/'near_key_v1.png'], False),
 ('near_half_v2', 'exec-e2393ab3-b706-409d-adc6-7792a49f3a29.png', [HERE/'near_contact_v2.png'], True),
 ('far_half_v2', 'exec-e63d8100-8865-4f72-8467-6ed19353aec7.png', [HERE/'near_half_v2.png',SHARED/'move_v1.png'], False),
 ('far_half_v3', 'exec-55541c1c-b2fd-477a-bf52-49e4a81fbe6e.png', [SHARED/'move_v1.png'], True),
]
generation = []
rejected = {'move_cycle_v1':'Parent rejected ambiguous repeated contact topology in first submission.',
            'far_half_v2':'Rejected: copied foreground-thigh topology instead of requested far half-cycle.'}
for stem, output, refs, selected in calls:
    image = HERE / (stem + '.png'); prompt = HERE / (stem + '.prompt.txt')
    generation.append(dict(image=rel(image),image_sha256=sha(image),prompt=rel(prompt),prompt_sha256=sha(prompt),
        tool='builtin_image_gen',tool_output_path='C:/Users/acorp/.codex/generated_images/01a0d214-8906-7660-aba1-2a03312802ba/'+output,
        references=[dict(path=rel(r),sha256=sha(r)) for r in refs],selected_for_candidate=selected,
        purpose=rejected.get(stem,'Anatomical near-leg reference, retained as source' if not selected else 'Selected original animation paintings'),
        rejected=stem in rejected))
write(HERE / 'generation.json', dict(schema_version=1, generations=generation,
    reused_generation_lineage=dict(path=rel(SHARED/'generation.json'),sha256=sha(SHARED/'generation.json'))))
write(HERE / 'handoff.json', dict(schema_version=1,units=[entry]))
attempt = read(HERE / 'attempt.json'); attempt['new_generation_calls'] = len(calls)
attempt['selected_masters'] = [r['image'] for r in generation if r['selected_for_candidate']]
attempt['reference_only_masters'] = [r['image'] for r in generation if not r['selected_for_candidate'] and not r['rejected']]
attempt['rejected_masters'] = [r['image'] for r in generation if r['rejected']]
write(HERE / 'attempt.json', attempt)
print('Prepared',len(entry['frames']),'frames:',{k:len(v['indices']) for k,v in entry['clips'].items()})
