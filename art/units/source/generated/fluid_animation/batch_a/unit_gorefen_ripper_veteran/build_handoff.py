"""Rebuild original-only animated source handoff and exact provenance."""
from pathlib import Path
import hashlib,json
from source_components import silhouettes
HERE=Path(__file__).resolve().parent
ROOT=next(p for p in HERE.parents if (p/'project.godot').exists())
REL=HERE.relative_to(ROOT).as_posix();UNIT=HERE.name
GEN='C:/Users/acorp/.codex/generated_images/01a0cccd-1b0c-78f0-9cfc-fea721badb97/'
reference=f'art/animation/source/poses/{UNIT}/{UNIT}_idle-alpha.png'
outputs={
 'idle_v1':'exec-8358d527-f0ec-4e23-9772-e9f224ebe815.png',
 'move_v1':'exec-85738874-eecf-45be-b432-dc14558f0f19.png',
 'attack_v1':'exec-20ae6587-542f-443a-8d58-0896378a9983.png',
 'reactions_v1':'exec-ffbdcde3-71b6-4641-9521-da4c01672764.png',
 'reactions_v2':'exec-273d3e97-fe34-40f3-a631-3ea9b8979382.png',
 'death_v1':'exec-823d06fb-5b93-4f6a-8413-121e4371fc11.png',
 'cast_v1':'exec-c9d928d2-617d-4182-b794-645718d81a80.png',
}
entries=[]
for stem,output in outputs.items():
 pp=HERE/(stem+'.prompt.txt');pp.write_bytes(pp.read_text(encoding='utf-8').rstrip('\r\n').encode('utf-8'))
 entries.append(dict(source=REL+'/'+stem+'.png',source_sha256=hashlib.sha256((HERE/(stem+'.png')).read_bytes()).hexdigest(),generation_output=GEN+output,prompt=REL+'/'+pp.name,prompt_sha256=hashlib.sha256(pp.read_bytes()).hexdigest(),references=[REL+'/reactions_v1.png' if stem=='reactions_v2' else reference],status='rejected: touching silhouettes' if stem=='reactions_v1' else 'candidate; coordinator acceptance pending'))
(HERE/'provenance.json').write_text(json.dumps(dict(schema_version=1,tool='image_gen.imagegen built-in',unit_id=UNIT,sources=entries),indent=2)+'\n',encoding='utf-8')
frames=[];clips={};isolated={}
def add(clip,source,scale,order=None,msec=110,contact=None):
 if source not in isolated:isolated[source]=silhouettes(HERE/source)
 parts,runs=isolated[source];order=order if order is not None else range(8);indices=[]
 for n,i in enumerate(order):
  p=parts[i];l,t,r,b=p['bounds']
  # Ground level follows actual hindfoot contact, not an invisible regular grid.
  anchor=[(270 if i%2==0 else 790) if source!='reactions_v1.png' else (490 if i%2==0 else 1110),b]
  indices.append(len(frames));frames.append(dict(name=f'{clip}_{n:02d}',clip=clip,source=REL+'/'+source,rects=runs[i],anchor=anchor,scale=scale))
 clips[clip]=dict(indices=indices,frame_msec=msec,loop=clip in ('idle','move'),static_frame=0)
 if contact is not None:clips[clip]['contact_frame']=contact
add('idle','idle_v1.png',0.72,order=[0,2,1,3,4,5,6,7],msec=140)
add('move','move_v1.png',0.72,msec=100)
add('attack','attack_v1.png',0.72,msec=100,contact=4)
add('hit','reactions_v2.png',0.82,order=[0,1,2,3],msec=110)
add('defend','reactions_v2.png',0.82,order=[4,5,6,7],msec=120)
add('cast','cast_v1.png',0.72,msec=120,contact=3)
add('death','death_v1.png',0.72,msec=140)
clips['dead']=dict(indices=[clips['death']['indices'][-1]],frame_msec=1000,loop=False,static_frame=0)
unit=dict(unit_id=UNIT,reference_height=256,source_facing='right',alpha_noise_cutoff=8,frames=frames,clips=clips,accepted_clips=[],preserve_clips=[],source_scale_by_image={f['source']:f['scale'] for f in frames},source_scale_reason='All originals depict matching skull/torso volume and about480px full neutral length; fixed0.72 produces about345px anatomy width near legacy footprint, with intended crouch/raise/collapse changing height. No per-pose sizing. Components are isolated using original source scan rectangles; no painted pixels are synthesized.',visual_review=dict(status='pending',notes='All original frames reviewed for identity, limb gestures and one-event sequence. Actual runtime leg alternation, contact timing, grounding and scale still require coordinator acceptance. Support is a physical claw-to-chest nod, not invented magic.'))
unit['source_scale_reason']+=' Spaced reactions_v2 redraw has smaller approximately420px neutral anatomy, so it uses one fixed0.82 across all eight poses to match the others.'
(HERE/'handoff.json').write_text(json.dumps(dict(schema_version=1,units=[unit]),indent=2)+'\n',encoding='utf-8')
print(f'{UNIT}: {len(frames)} original frames; {len(clips)} clips pending review')
