"""Rebuild pending original-art handoff without painting or warping frames."""
import hashlib,json
from pathlib import Path
D=Path(__file__).resolve().parent
ROOT=next(p for p in D.parents if (p/'project.godot').exists())
REF='art/units/source/curated/'+D.name+'.png'
origins={'ranged_v1':'exec-f9c2af6c-4915-42b3-9188-eeea9f3723ab.png','attack_v1':'exec-4e7a3d34-a4e5-4ce7-8340-515397f82291.png','reactions_v1':'exec-58f936a1-0324-40db-a5f1-c13200d57b62.png','death_v1':'exec-c5e870d9-b172-4a12-9b2e-b38091d983b8.png','cast_v1':'exec-c6019327-5603-4f98-bf47-6cd1a2a8c0d0.png','move_contacts_v1':'exec-5b3e6313-f319-4489-aa31-e8fb12ab923a.png','move_opposite_v1':'exec-aaedd276-eeea-4b33-896f-639dc1579373.png','move_inbetweens_v1':'exec-f1548f4e-0746-4ec7-b9d8-ce5a21e7ab18.png','move_opposite_half_v1':'exec-126d62a9-f04d-4c8d-b003-10778778e04a.png'}
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
provenance=[]
for stem,original in origins.items():
 p=D/(stem+'.png');prompt=D/(stem+'.prompt.txt');prompt.write_bytes(prompt.read_bytes().rstrip(b'\r\n'))
 refs=[ROOT/REF]
 if stem=='move_contacts_v1':refs+=[D.parent/'unit_veilmourn_dreamwake_foganchor_colossi'/'move_contacts_v1.png']
 if stem=='move_inbetweens_v1':refs=[D/'move_contacts_v1.png',D/'move_opposite_v1.png']
 if stem=='move_opposite_half_v1':refs=[D/'move_opposite_v1.png']
 provenance.append(dict(source=p.relative_to(ROOT).as_posix(),sha256=sha(p),prompt=prompt.relative_to(ROOT).as_posix(),prompt_sha256=sha(prompt),prompt_encoding='utf-8 exact tool prompt bytes',references=[dict(path=r.relative_to(ROOT).as_posix(),sha256=sha(r)) for r in refs],generation_output='C:/Users/acorp/.codex/generated_images/01a0ccd1-6d7e-7c70-9f33-f86f3332e28b/'+original,tool='image_gen.imagegen',status='pending_visual_review' if not stem.startswith('move_') else 'not_accepted_gait_continuity'))
(D/'provenance.json').write_text(json.dumps(dict(schema_version=1,assets=provenance),indent=2)+'\n',encoding='utf-8')
u=dict(unit_id=D.name,reference_height=256,source_facing='right',frames=[],clips={},accepted_clips=[],preserve_clips=['idle'],visual_review=dict(status='pending',idle_review='Existing eight idle paintings raise and lower the mirror hand while cloth sways and shoulders breathe; proposed retention subject to coordinator review.',remaining='Movement sources have opposite contacts but incomplete coherent half-cycle inbetweens; excluded from handoff until fixed.'))
def add(clip,stem,rects,anchors,scale,msec=100,contact=None):
 start=len(u['frames'])
 for i,(r,a) in enumerate(zip(rects,anchors)):
  u['frames'].append(dict(name=clip+'_'+str(i),clip=clip,source=(D/(stem+'.png')).relative_to(ROOT).as_posix(),rects=r if isinstance(r[0],list) else [r],anchor=a,scale=scale,alpha_noise_cutoff=8))
 c=dict(indices=list(range(start,len(u['frames']))),frame_msec=msec,loop=False,static_frame=0)
 if contact is not None:c['contact_frame']=contact
 u['clips'][clip]=c
def grid(ys):return [[c*512,ys[r],(c+1)*512,ys[r+1]] for r in range(4) for c in range(2)]
attack=grid([0,400,785,1110,1536]);attack[2]=[[0,400,512,785],[60,375,190,400]];attack[4]=[0,785,590,1110];attack[5]=[590,785,1024,1145];attack[7]=[[512,1145,1024,1536],[660,1080,750,1145]]
add('attack','attack_v1',attack,[[290,395],[780,385],[270,770],[790,770],[245,1100],[780,1105],[275,1505],[800,1505]],.62,100,4)
ranged=grid([0,365,760,1130,1536]);ranged[4]=[0,760,590,1130];ranged[5]=[590,760,1024,1130]
add('ranged','ranged_v1',ranged,[[290,360],[795,360],[265,750],[780,750],[255,1120],[785,1120],[290,1515],[805,1515]],.66,100,4)
reactions=grid([0,390,785,1155,1536])
add('hit','reactions_v1',reactions[:4],[[280,380],[790,385],[290,775],[785,780]],.64,105)
add('defend','reactions_v1',reactions[4:],[[305,1145],[795,1150],[290,1515],[805,1520]],.64,115)
add('death','death_v1',grid([0,510,900,1230,1536]),[[300,485],[800,485],[280,850],[795,850],[285,1150],[800,1160],[285,1470],[800,1470]],.53,130)
u['clips']['dead']=dict(indices=[len(u['frames'])-1],frame_msec=1000,loop=False,static_frame=0)
add('cast','cast_v1',grid([0,380,775,1145,1536]),[[320,375],[760,375],[325,770],[775,770],[315,1135],[755,1135],[315,1520],[765,1520]],.64,110,4)
u['source_scale_by_image']={f['source']:f['scale'] for f in u['frames']}
u['source_scale_reason']='Fixed per-original source anatomical resolution normalization: attack .62, ranged .66, reactions/support .64, death .53. Generated standing body dimensions differ by original even when canvases match; scales align head-to-boot body height to existing 256-reference creature. No individual-pose scaling, rotation or warping.'
(D/'handoff.json').write_text(json.dumps(dict(schema_version=1,units=[u]),indent=2)+'\n',encoding='utf-8')
print('Pending Tideglass handoff:',len(u['frames']),'new action poses; idle preservation proposed; movement unfinished')

# Replay visually reviewed body ownership and anatomical anchor corrections.
import sys as _crop_sys
from pathlib import Path as _CropPath
_crop_dir = _CropPath(__file__).resolve().parent
_crop_root = next(p for p in _crop_dir.parents if (p / "project.godot").exists())
_crop_sys.path.insert(0, str(_crop_root / "tools"))
from refine_fluid_frame_crops import apply_recipe as _apply_crop_recipe
_apply_crop_recipe(_crop_dir / "handoff.json", _crop_dir / "crop_refinements.json")
