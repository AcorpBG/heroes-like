"""Rebuild this unit's source handoff; crop/metadata only, no pose synthesis."""
from pathlib import Path
import hashlib, json
from PIL import Image

HERE = Path(__file__).resolve().parent
ROOT = next(p for p in HERE.parents if (p / 'project.godot').exists())
REL = HERE.relative_to(ROOT).as_posix()
UNIT = HERE.name
GEN = 'C:/Users/acorp/.codex/generated_images/01a0cccd-1b0c-78f0-9cfc-fea721badb97/'
outputs = {
 'idle_v1': ('exec-de1a4608-fff8-42fa-ac9b-3d01401fe4a1.png', 'idle_v1', 'candidate'),
 'move_v1': ('exec-bcadf24e-042c-4715-882f-382bf8a3d56d.png', 'move_v1', 'rejected: weak alternating gait'),
 'attack_v1_rejected': ('exec-ce7f9c92-bcf8-4d3a-a0ad-d5b33c02e7dc.png', 'attack_v1', 'rejected: swapped and duplicate prism'),
 'attack_v2_rejected': ('exec-da7e195a-22c0-45d8-9829-19288113296e.png', 'attack_v2', 'rejected: swapped prism hand'),
 'attack_v3': ('exec-b619201c-c873-48ec-aad4-5b88d3a2ff22.png', 'attack_v3', 'candidate'),
 'reactions_v1': ('exec-4fe0bd21-982a-4e99-a403-94d1cc2f2a64.png', 'reactions_v1', 'top four hit candidate; bottom defense rejected hand change'),
 'death_v1': ('exec-c1062e4d-d68d-448d-b014-710e8a7ef997.png', 'death_v1', 'candidate'),
 'ranged_v1': ('exec-a7871372-8c08-4a96-9692-467c08343f73.png', 'ranged_v1', 'candidate'),
 'cast_v1_rejected': ('exec-64ef7a76-1191-4a02-8989-6cb4cd5b8034.png', 'cast_v1', 'rejected: last-column belt tablets clipped'),
 'cast_v2': ('exec-6ab38733-2a46-4927-b0a0-b509ca93d03e.png', 'cast_v2', 'candidate'),
 'defend_v2': ('exec-6c668178-ab15-4597-a01a-60e4ff3dad81.png', 'defend_v2', 'candidate'),
 'move_v2': ('exec-4b360fa2-bc61-478b-915f-bea5ee20290d.png', 'move_v2', 'candidate: motion review required'),
}
reference = f'art/animation/source/poses/{UNIT}/{UNIT}_idle-alpha.png'
entries = []
for stem, (output, prompt_stem, status) in outputs.items():
    pp = HERE / (prompt_stem + '.prompt.txt')
    # Tool requests contain precisely this UTF-8 string, without patch's final newline.
    prompt = pp.read_text(encoding='utf-8').rstrip('\r\n')
    pp.write_bytes(prompt.encode('utf-8'))
    refs = {'attack_v2': 'attack_v1_rejected.png', 'cast_v2': 'cast_v1_rejected.png', 'move_v2': 'move_v1.png'}
    ref = REL + '/' + refs[prompt_stem] if prompt_stem in refs else reference
    entries.append(dict(source=REL+'/'+stem+'.png', source_sha256=hashlib.sha256((HERE/(stem+'.png')).read_bytes()).hexdigest(), generation_output=GEN+output, prompt=REL+'/'+pp.name, prompt_sha256=hashlib.sha256(pp.read_bytes()).hexdigest(), references=[ref], status=status))
(HERE/'provenance.json').write_text(json.dumps(dict(schema_version=1, tool='image_gen.imagegen built-in', unit_id=UNIT, sources=entries),indent=2)+'\n',encoding='utf-8')
frames=[]
clips={}
def add(clip,source,rects,anchors,scale,order=None,msec=100,contact=None):
    indices=[]
    for n,i in enumerate(order if order is not None else range(len(rects))):
        indices.append(len(frames))
        frames.append(dict(name=f'{clip}_{n:02d}',clip=clip,source=REL+'/'+source,rects=[rects[i]],anchor=anchors[i],scale=scale))
    clips[clip]=dict(indices=indices,frame_msec=msec,loop=clip in ('idle','move'),static_frame=0)
    if contact is not None: clips[clip]['contact_frame']=contact
def grid(source,clip,scale,order=None,msec=100,contact=None,limit=8):
    im=Image.open(HERE/source)
    w,h=im.size; cw=w//2; ch=h//4
    rects=[[i%2*cw,i//2*ch,(i%2+1)*cw,(i//2+1)*ch] for i in range(limit)]
    anchors=[[i%2*cw+cw//2,i//2*ch+ch-12] for i in range(limit)]
    add(clip,source,rects,anchors,scale,order,msec,contact)
grid('idle_v1.png','idle',0.60,order=[0,2,1,3,4,5,6,7],msec=140)
grid('move_v2.png','move',0.60,msec=100)
grid('attack_v3.png','attack',0.60,msec=100,contact=4)
grid('ranged_v1.png','ranged',0.60,msec=100,contact=4)
grid('cast_v2.png','cast',0.63,order=[0,1,2,3,4,6,5,7],msec=120,contact=4)
grid('reactions_v1.png','hit',0.60,msec=110,limit=4)
rects=[[0,0,656,600],[656,0,1312,600],[0,600,656,1199],[656,600,1312,1199]]
anchors=[[396,591],[996,591],[396,1170],[996,1170]]
add('defend','defend_v2.png',rects,anchors,0.39,msec=120)
bounds=[0,530,950,1280,1536]
rects=[[i%2*512,bounds[i//2],(i%2+1)*512,bounds[i//2+1]] for i in range(8)]
grounds=[494,501,918,918,1245,1248,1501,1499]
anchors=[[i%2*512+256,grounds[i]] for i in range(8)]
add('death','death_v1.png',rects,anchors,0.47,msec=140)
clips['dead']=dict(indices=[clips['death']['indices'][-1]],frame_msec=1000,loop=False,static_frame=0)
unit=dict(unit_id=UNIT,reference_height=256,source_facing='right',alpha_noise_cutoff=8,frames=frames,clips=clips,accepted_clips=[],preserve_clips=[],visual_review=dict(status='pending',notes='Source paintings reviewed for identity. Runtime scale/motion acceptance remains coordinator-owned. Idle and cast poses reordered only to follow hand-height continuity; no painted frames duplicated. Walk near/far leg continuity and death 5-to-6 fall need real playback review.'))
unit['source_scale_by_image']={frame['source']:frame['scale'] for frame in frames}
unit['source_scale_reason']='Each original keeps one fixed anatomical scale. Most 1024x1536 eight-pose sheets depict standing bodies about370px tall (0.60); cast bodies are about350px (0.63); death source first standing body about470px (0.47); 1312x1199 four-pose defense bodies about570px (0.39). All target approximately220-225px standing anatomy at reference height256. Collapsed/recoiled poses are never individually enlarged. Coordinator runtime registration review pending.'
(HERE/'handoff.json').write_text(json.dumps(dict(schema_version=1,units=[unit]),indent=2)+'\n',encoding='utf-8')
print(f'{UNIT}: {len(frames)} original selected frames, {len(clips)} clips, pending visual acceptance')
