"""Rebuild pending crop metadata; never paint or warp generated poses."""
import hashlib,json
from pathlib import Path
from PIL import Image
D=Path(__file__).resolve().parent
ROOT=next(p for p in D.parents if (p/'project.godot').exists())
REF='art/units/source/curated/unit_veilmourn_dreamwake_foganchor_colossi.png'
origins={
 'move_v1':'exec-66997f89-2068-46cf-9e73-1fb69effe2c9.png',
 'move_v2':'exec-54a4c984-74f2-4dcc-886a-2aa40ecdc2fb.png',
 'attack_v1':'exec-1a291fbe-793b-469d-85b1-7671147efc57.png',
 'reactions_v1':'exec-41b8fb82-54a7-46e8-812d-bf8563048b99.png',
 'death_v1':'exec-f5d1dbcd-b850-4ebd-bbbd-7305a7b1ef71.png',
 'cast_v1':'exec-d844685d-5f88-4d60-b6c3-1fda5386b809.png',
 'move_contacts_v1':'exec-275cf636-8536-4dd7-8d06-35b873f74f6d.png',
 'move_inbetweens_v1':'exec-4b6d168d-47b2-456e-8837-0225ba85fdcc.png'}
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
provenance=[]
for stem,original in origins.items():
 p=D/(stem+'.png'); prompt=D/(stem+'.prompt.txt')
 reference=D/'move_v1.png' if stem=='move_v2' else D/'move_contacts_v1.png' if stem=='move_inbetweens_v1' else ROOT/REF
 provenance.append(dict(source=p.relative_to(ROOT).as_posix(),sha256=sha(p),prompt=prompt.relative_to(ROOT).as_posix(),prompt_sha256=sha(prompt),prompt_encoding='utf-8 exact tool prompt bytes',reference=reference.relative_to(ROOT).as_posix(),reference_sha256=sha(reference),generation_output='C:/Users/acorp/.codex/generated_images/01a0ccd1-6d7e-7c70-9f33-f86f3332e28b/'+original,tool='image_gen.imagegen',status='rejected_same_leading_leg' if stem in ('move_v1','move_v2') else 'pending_visual_review'))
(D/'provenance.json').write_text(json.dumps(dict(schema_version=1,assets=provenance),indent=2)+'\n',encoding='utf-8')
u=dict(unit_id=D.name,reference_height=256,source_facing='right',frames=[],clips={},accepted_clips=[],preserve_clips=['idle'],visual_review=dict(status='pending',idle_review='Existing eight poses show a free-hand lift/return, wrist articulation, breathing and cloth follow-through; proposed retention pending coordinator review.',remaining='Move opposite contacts and inbetweens await continuity review; not included as accepted movement.'))
def add(clip,stem,rects,anchors,scale,msec=100,contact=None):
 start=len(u['frames'])
 for i,(r,a) in enumerate(zip(rects,anchors)):
  u['frames'].append(dict(name=clip+'_'+str(i),clip=clip,source=(D/(stem+'.png')).relative_to(ROOT).as_posix(),rects=r if isinstance(r[0],list) else [r],anchor=a,scale=scale,alpha_noise_cutoff=8))
 c=dict(indices=list(range(start,len(u['frames']))),frame_msec=msec,loop=False,static_frame=0)
 if contact is not None:c['contact_frame']=contact
 u['clips'][clip]=c
def grid(ys):return [[c*512,ys[r],(c+1)*512,ys[r+1]] for r in range(4) for c in range(2)]
attack=grid([0,390,780,1125,1536]);attack[4]=[[0,780,512,1125],[512,780,630,965]];attack[5]=[630,780,1024,1125]
add('attack','attack_v1',attack,[[305,375],[810,375],[310,765],[815,765],[290,1095],[800,1110],[305,1490],[805,1490]],.64,100,4)
reaction=grid([0,380,775,1155,1536])
add('hit','reactions_v1',reaction[:4],[[300,365],[805,365],[305,765],[805,765]],.62,105)
add('defend','reactions_v1',reaction[4:],[[300,1130],[805,1145],[305,1515],[805,1515]],.62,120)
add('death','death_v1',grid([0,515,950,1270,1536]),[[295,470],[800,470],[300,900],[800,920],[300,1240],[800,1230],[300,1510],[800,1510]],.48,130)
u['clips']['dead']=dict(indices=[len(u['frames'])-1],frame_msec=1000,loop=False,static_frame=0)
cast=grid([0,385,770,1155,1536]);cast[4]=[[0,770,512,1155],[375,750,430,770]]
add('cast','cast_v1',cast,[[305,374],[800,374],[305,760],[800,760],[305,1144],[800,1144],[305,1523],[800,1523]],.62,110,4)
move_start=len(u['frames'])
move_plan=[('move_contacts_v1',[0,0,887,887],[555,850],.27),('move_inbetweens_v1',[0,0,512,520],[305,510],.46),('move_inbetweens_v1',[0,520,512,1030],[305,1025],.46),('move_inbetweens_v1',[512,1030,1024,1536],[810,1525],.46),('move_contacts_v1',[887,0,1774,887],[1340,850],.27),('move_inbetweens_v1',[512,0,1024,520],[810,510],.46),('move_inbetweens_v1',[512,520,1024,1030],[810,1025],.46),('move_inbetweens_v1',[0,1030,512,1536],[305,1525],.46)]
for i,(stem,r,a,s) in enumerate(move_plan):
 u['frames'].append(dict(name='move_'+str(i),clip='move',source=(D/(stem+'.png')).relative_to(ROOT).as_posix(),rects=[r],anchor=a,scale=s,alpha_noise_cutoff=8))
u['clips']['move']=dict(indices=list(range(move_start,move_start+8)),frame_msec=110,loop=True,static_frame=0)
u['visual_review']['remaining']='Movement candidate uses opposite contacts and six distinct intermediates. Generated bottom row intermediates were reversed and correctly reordered by leading leg: near contact, left support, left passing, right reach, far contact, right support, right passing, left reach. Coordinator motion acceptance pending.'
u['source_scale_by_image']={f['source']:f['scale'] for f in u['frames']}
u['source_scale_reason']='Each generated master uses a different painted anatomical resolution despite equal canvas dimensions. Attack .64, reaction/support .62 and death .48 align the standing helmet-to-boot body volume to the existing 256-reference runtime figure. Death source has larger original body painting. Walk contact original body is approximately 780px at scale .27, inbetweens approximately 450px at scale .46. Every pose in each original master has the same fixed scale; no per-pose normalization or warping.'
(D/'handoff.json').write_text(json.dumps(dict(schema_version=1,units=[u]),indent=2)+'\n',encoding='utf-8')
print('Pending handoff:',len(u['frames']),'new poses; retained idle proposed; movement reordered by anatomical leading leg')
