"""Original source crop/registration recipe; no procedural animation pixels."""
from pathlib import Path
import hashlib,json
from PIL import Image
from source_components import silhouettes
HERE=Path(__file__).resolve().parent
ROOT=next(p for p in HERE.parents if (p/'project.godot').exists())
REL=HERE.relative_to(ROOT).as_posix(); UNIT=HERE.name
GEN='C:/Users/acorp/.codex/generated_images/01a0cccd-1b0c-78f0-9cfc-fea721badb97/'
reference=f'art/animation/source/poses/{UNIT}/{UNIT}_idle-alpha.png'
outputs={
 'idle_v1_rejected':('exec-b27d3ce1-95e1-4580-9461-0011c1aa54f4.png','idle_v1',reference,'rejected: edge clipping'),
 'idle_v2':('exec-4cec29ec-6270-4e56-9838-7442c4a5b77a.png','idle_v2',REL+'/idle_v1_rejected.png','candidate'),
 'move_v1_rejected':('exec-3424b556-7ada-4679-adc3-595817442b7c.png','move_v1',reference,'rejected: edge clipping'),
 'move_v2':('exec-a761a9e5-e457-42aa-b56b-3b953bfa393a.png','move_v2',REL+'/move_v1_rejected.png','candidate'),
 'attack_v1_rejected':('exec-b8976f82-e53a-41a9-8ee5-4bce373c8b9e.png','attack_v1',REL+'/idle_v2.png','rejected: overlap/edge clipping'),
 'attack_v2':('exec-1addf91d-3237-484a-b3a3-4785fb8ed216.png','attack_v2',REL+'/attack_v1_rejected.png','candidate'),
 'reactions_v1':('exec-a22a1e59-1f65-4be3-b630-5644d060163b.png','reactions_v1',reference,'candidate'),
 'death_v1':('exec-1bf2666d-37af-438e-83f7-7e1d8214cd69.png','death_v1',reference,'candidate'),
 'cast_v1':('exec-9bd3cf39-0988-490e-b661-68a2eaf16d0c.png','cast_v1',reference,'rejected: touching silhouettes'),
 'cast_v2':('exec-a74765f1-bd34-48a1-8734-05b3bfc953fb.png','cast_v2',REL+'/cast_v1.png','candidate'),
}
entries=[]
for stem,(output,prompt,ref,status) in outputs.items():
 pp=HERE/(prompt+'.prompt.txt'); pp.write_bytes(pp.read_text(encoding='utf-8').rstrip('\r\n').encode('utf-8'))
 entries.append(dict(source=REL+'/'+stem+'.png',source_sha256=hashlib.sha256((HERE/(stem+'.png')).read_bytes()).hexdigest(),generation_output=GEN+output,prompt=REL+'/'+pp.name,prompt_sha256=hashlib.sha256(pp.read_bytes()).hexdigest(),references=[ref],status=status))
(HERE/'provenance.json').write_text(json.dumps(dict(schema_version=1,tool='image_gen.imagegen built-in',unit_id=UNIT,sources=entries),indent=2)+'\n',encoding='utf-8')
frames=[]; clips={}
isolated={}
def add(clip,source,xb,yb,scale,order=None,msec=110,contact=None):
 cols=len(xb)-1; count=cols*(len(yb)-1)
 order=order if order is not None else range(count)
 if source not in isolated:isolated[source]=silhouettes(HERE/source)
 parts,runs=isolated[source]
 indices=[]
 for n,i in enumerate(order):
  x=i%cols;y=i//cols; rect=[xb[x],yb[y],xb[x+1],yb[y+1]]
  bounds=parts[i]['bounds']
  # Belly contact is the source silhouette base. Registration is translation only.
  ground=bounds[3]
  anchor=[round((rect[0]+rect[2])/2),ground]
  indices.append(len(frames)); frames.append(dict(name=f'{clip}_{n:02d}',clip=clip,source=REL+'/'+source,rects=runs[i],anchor=anchor,scale=scale))
 clips[clip]=dict(indices=indices,frame_msec=msec,loop=clip in ('idle','move'),static_frame=0)
 if contact is not None:clips[clip]['contact_frame']=contact
add('idle','idle_v2.png',[0,443,887,1330,1774],[0,444,887],0.80,msec=140)
add('move','move_v2.png',[0,443,887,1330,1774],[0,444,887],0.80,msec=100)
add('attack','attack_v2.png',[0,540,1024],[0,384,768,1120,1536],0.80,msec=100,contact=4)
add('hit','reactions_v1.png',[0,548,1024],[0,450,790,1160,1536],0.60,order=[0,2,4,6],msec=110)
add('defend','reactions_v1.png',[0,548,1024],[0,450,790,1160,1536],0.60,order=[1,3,5,7],msec=120)
add('cast','cast_v2.png',[0,512,1024],[0,384,768,1152,1536],0.95,msec=130,contact=3)
add('death','death_v1.png',[0,768,1536],[0,356,612,820,1024],0.52,msec=140)
clips['dead']=dict(indices=[clips['death']['indices'][-1]],frame_msec=1000,loop=False,static_frame=0)
unit=dict(unit_id=UNIT,reference_height=256,source_facing='right',alpha_noise_cutoff=8,frames=frames,clips=clips,accepted_clips=[],preserve_clips=[],source_scale_by_image={f['source']:f['scale'] for f in frames},source_scale_reason='One fixed anatomical scale per original, using skull/collar/body dimensions against old 353x214 standing silhouette. 1774x887 sources and 1024x1536 attack depict smaller bodies (0.80); reactions have larger neck/skull (0.60); 1536x1024 death depicts about650px long bodies (0.52); corrected portrait cast uses smaller skull/body height (0.95). No per-pose resizing, collapsed poses retain anatomical scale. Runtime cross-clip comparison still pending.',visual_review=dict(status='pending',notes='Originals reviewed for anatomy and one-event motion; support sheet is corrected row-major bow. Exact original component scan rectangles prevent source-neighbor bleed. Reaction sheet uses left column hit and right column defense. Runtime timing/anchor/size acceptance remains coordinator-owned.'))
(HERE/'handoff.json').write_text(json.dumps(dict(schema_version=1,units=[unit]),indent=2)+'\n',encoding='utf-8')
print(f'{UNIT}: {len(frames)} original poses; {len(clips)} clips pending visual acceptance')
