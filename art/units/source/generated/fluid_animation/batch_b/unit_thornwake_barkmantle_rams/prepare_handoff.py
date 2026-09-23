from pathlib import Path
from PIL import Image
import hashlib,json
ROOT=Path(__file__).resolve().parents[7];D=Path(__file__).resolve().parent;REL=D.relative_to(ROOT).as_posix();uid=D.name
sheets={
'attack_v1':(.70,[[38,87,477,373],[550,107,981,372],[37,490,477,747],[550,473,1014,741],[37,836,542,1100],[551,834,992,1108],[39,1172,506,1474],[549,1181,991,1470]],[234,744,234,749,259,752,242,752]),
'hit_defend_v1':(.65,[[75,9,543,346],[677,13,1138,346],[72,365,558,674],[690,370,1154,675],[56,695,552,994],[685,716,1156,992],[55,1041,552,1302],[660,1021,1150,1304]],[271,877,283,891,275,900,275,884]),
'death_v1':(.80,[[84,133,440,390],[571,164,927,387],[70,550,461,771],[564,576,984,771],[57,905,491,1131],[555,959,985,1117],[48,1290,483,1450],[553,1296,985,1452]],[238,727,245,755,248,762,248,765]),
'cast_v1':(.68,[[44,75,476,372],[548,99,975,372],[44,447,471,721],[548,466,991,721],[44,813,495,1106],[550,777,985,1106],[44,1174,480,1475],[546,1173,977,1476]],[237,742,237,745,245,745,239,745])}
frames=[];clips={}
for name,(scale,rects,anchors) in sheets.items():
 w,h=Image.open(D/(name+'.png')).size
 for i,(l,t,r,b) in enumerate(rects):
  clip=('hit' if i<4 else 'defend') if name=='hit_defend_v1' else name.split('_')[0]
  clips.setdefault(clip,{'indices':[],'frame_msec':100 if clip=='attack' else 120,'loop':False,'static_frame':0})['indices'].append(len(frames))
  if clip=='attack':clips[clip]['contact_frame']=4
  frames.append({'name':f'{name}_{i:02d}','clip':clip,'source':f'{REL}/{name}.png','rects':[[max(0,l-2),max(0,t-2),min(w,r+2),min(h,b+2)]],'anchor':[anchors[i],b],'scale':scale})
clips['dead']={'indices':[clips['death']['indices'][-1]],'frame_msec':1000,'loop':False,'static_frame':0}
entry={'unit_id':uid,'reference_height':256,'source_facing':'right','alpha_noise_cutoff':8,'frames':frames,'clips':clips,'accepted_clips':[],'preserve_clips':['idle','move'],'source_scale_by_image':{f'{REL}/{n}.png':s for n,(s,_,__) in sheets.items()},'source_scale_reason':'Original generation sheets render the same anatomical body at different fixed resolutions. Uniform scale for all poses of each source is calibrated against the current approximately 200px high, 290px wide idle. Attack 0.70, reaction/guard 0.65, death 0.80 (smaller drawn body), support 0.68. No per-pose scale or deformation.','visual_review':{'status':'pending','notes':'New horn attack, recoil, brace, bow support and eight-pose grounded collapse. Current idle inspected: visible head/neck movement and modest foreleg adjustment retained pending coordinator motion review. Movement source rejected due to clipped outer horns and weak hind-leg progression; not included.'},'unfinished_clips':['move']}
(D/'handoff.json').write_text(json.dumps({'schema_version':1,'units':[entry]},indent=2)+'\n')
outs={'move_v1':'exec-11751aee-9e98-4625-961e-56e17b274755.png','attack_v1':'exec-0bb8ec15-ded4-4153-82b5-cee2891cbce8.png','hit_defend_v1':'exec-f0dbb131-7d6e-4bb8-95e6-f98965bec5e6.png','death_v1':'exec-06557b99-0150-4b6a-9f5d-f05feba9cb04.png','cast_v1':'exec-8d8e819b-b27a-4ae2-a4a3-258afb8856d1.png'}
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();ref=ROOT/'art/units/source/curated'/f'{uid}.png'
prov={'tool':'built-in image_gen','reference':ref.relative_to(ROOT).as_posix(),'reference_sha256':sha(ref),'outputs':[{'source':f'{REL}/{n}.png','source_sha256':sha(D/(n+'.png')),'prompt':f'{REL}/{n}.prompt.txt','prompt_sha256':sha(D/(n+'.prompt.txt')),'generated_output':'C:/Users/acorp/.codex/generated_images/01a0ccd0-015a-7981-ae58-ff4d5582854d/'+o,'status':'rejected_clipping_and_weak_gait' if n=='move_v1' else 'pending_visual_review'} for n,o in outs.items()]}
(D/'provenance.json').write_text(json.dumps(prov,indent=2)+'\n');print(uid,len(frames),'proposed poses; movement unfinished')
