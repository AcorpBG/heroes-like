"""Pending original-pose crop recipe; no raster repaint or pose warping."""
import hashlib,json,sys
from pathlib import Path
D=Path(__file__).resolve().parent;ROOT=next(p for p in D.parents if (p/'project.godot').exists())
REF='art/units/source/curated/'+D.name+'.png'
origins={'move_v1':'exec-52d11e33-22f3-4d73-8684-61462edada54.png','attack_v1':'exec-1b5d0ac1-7ed9-46a9-9252-18bf7241411e.png','reactions_v1':'exec-033c7d3f-eff8-4883-ba6c-0f95478c5477.png','death_v1':'exec-c6c77c55-160a-4a41-b13f-259d32ca42d9.png','cast_v1':'exec-39ad9c9b-cef4-48d0-ab19-859a9bd6d01b.png'}
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
provenance=[]
for stem,origin in origins.items():
 p=D/(stem+'.png');prompt=D/(stem+'.prompt.txt');prompt.write_bytes(prompt.read_bytes().rstrip(b'\r\n'))
 provenance.append(dict(source=p.relative_to(ROOT).as_posix(),sha256=sha(p),prompt=prompt.relative_to(ROOT).as_posix(),prompt_sha256=sha(prompt),prompt_encoding='utf-8 exact tool prompt bytes',reference=REF,reference_sha256=sha(ROOT/REF),generation_output='C:/Users/acorp/.codex/generated_images/01a0ccd1-6d7e-7c70-9f33-f86f3332e28b/'+origin,tool='image_gen.imagegen',status='pending_visual_review'))
(D/'provenance.json').write_text(json.dumps(dict(schema_version=1,assets=provenance),indent=2)+'\n',encoding='utf-8')
u=dict(unit_id=D.name,reference_height=256,source_facing='left',frames=[],clips={},accepted_clips=[],preserve_clips=['idle'],visual_review=dict(status='pending',idle_review='Existing eight idle frames retain breathing, fin/lure and subtle foreclaw articulation; coordinator acceptance required.',remaining='All new sequences pending game-scale motion review; no approval inferred from frame count.'))
def grid(xs,ys):return [[xs[c],ys[r],xs[c+1],ys[r+1]] for r in range(2) for c in range(4)]
def add(clip,stem,rects,anchors,msec=100,contact=None):
 start=len(u['frames'])
 for i,(r,a) in enumerate(zip(rects,anchors)):
  u['frames'].append(dict(name=clip+'_'+str(i),clip=clip,source=(D/(stem+'.png')).relative_to(ROOT).as_posix(),rects=[r],anchor=a,scale=.67,alpha_noise_cutoff=8))
 c=dict(indices=list(range(start,len(u['frames']))),frame_msec=msec,loop=clip=='move',static_frame=0)
 if contact is not None:c['contact_frame']=contact
 u['clips'][clip]=c
rects=grid([0,401,779,1149,1536],[0,550,1024])
add('move','move_v1',rects,[[205,474],[585,474],[965,474],[1345,474],[205,923],[585,923],[965,923],[1345,923]],110)
add('attack','attack_v1',grid([0,400,774,1146,1536],[0,535,1024]),[[205,470],[585,470],[965,475],[1345,475],[205,918],[585,918],[965,918],[1345,918]],100,4)
reaction=grid([0,411,771,1148,1536],[0,550,1024])
add('hit','reactions_v1',reaction[:4],[[210,484],[590,484],[970,484],[1350,484]],105)
add('defend','reactions_v1',reaction[4:],[[205,928],[585,928],[965,928],[1345,928]],115)
add('death','death_v1',grid([0,391,774,1148,1536],[0,600,1024]),[[200,500],[580,500],[960,500],[1340,500],[200,923],[580,923],[960,923],[1340,923]],130)
u['clips']['dead']=dict(indices=[len(u['frames'])-1],frame_msec=1000,loop=False,static_frame=0)
add('cast','cast_v1',grid([0,403,777,1144,1536],[0,550,1024]),[[205,450],[585,450],[965,450],[1345,450],[205,923],[585,923],[965,923],[1345,923]],110,4)
u['source_scale_by_image']={f['source']:f['scale'] for f in u['frames']}
u['source_scale_reason']='All originals use the same .67 fixed uniform scale, matching approximately 370px generated body width to approximately 250px existing pose body. Anatomical crouching/rearing/collapse is preserved; no per-frame normalizing or warping.'
# These four overlapping source cells were individually reviewed in Godot.
# Preserve the complete creature while excluding neighboring sprite fragments.
sys.path.insert(0,str(ROOT/'tools'))
from refine_fluid_frame_crops import refine_frame
for clip,number,seed in [('attack',4,[200,790]),('attack',5,[590,790]),('defend',0,[200,800]),('defend',1,[590,800])]:
 refine_frame(u,clip,number,seed)
(D/'handoff.json').write_text(json.dumps(dict(schema_version=1,units=[u]),indent=2)+'\n',encoding='utf-8')
print('Pending Fogbound handoff:',len(u['frames']),'new original poses; existing idle retention proposed')
