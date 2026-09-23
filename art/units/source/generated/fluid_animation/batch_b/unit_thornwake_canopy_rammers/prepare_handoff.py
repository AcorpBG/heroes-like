from pathlib import Path
from PIL import Image
import hashlib,json
ROOT=Path(__file__).resolve().parents[7];D=Path(__file__).resolve().parent;REL=D.relative_to(ROOT).as_posix();uid=D.name
sheets={
'attack_v1':(.55,[[119,13,428,367],[654,22,980,367],[101,401,454,744],[633,395,1003,744],[87,779,510,1124],[655,780,979,1122],[133,1160,455,1512],[662,1157,974,1509]],[238,780,248,790,250,782,264,789]),
'hit_defend_v1':(.47,[[25,52,376,464],[455,77,744,463],[819,51,1135,461],[1209,63,1517,464],[55,534,366,960],[442,547,754,959],[819,553,1134,960],[1209,556,1517,960]],[208,610,962,1350,204,591,970,1359]),
'death_v1':(.47,[[100,28,483,435],[560,102,988,436],[29,490,498,832],[509,564,1018,835],[19,897,543,1148],[546,948,1015,1137],[25,1272,508,1458],[524,1279,1017,1461]],[255,733,248,736,256,768,253,760]),
'cast_v1':(.55,[[137,23,457,372],[592,23,912,372],[136,410,457,755],[593,417,917,755],[138,798,464,1139],[596,789,918,1139],[137,1168,463,1523],[591,1168,912,1523]],[265,722,265,722,266,723,266,722])}
frames=[];clips={}
for name,(scale,rects,anchors) in sheets.items():
 for i,(l,t,r,b) in enumerate(rects):
  clip=('hit' if i<4 else 'defend') if name=='hit_defend_v1' else name.split('_')[0]
  clips.setdefault(clip,{'indices':[],'frame_msec':100 if clip=='attack' else 115,'loop':False,'static_frame':0})['indices'].append(len(frames))
  if clip=='attack':clips[clip]['contact_frame']=4
  frames.append({'name':f'{name}_{i:02d}','clip':clip,'source':f'{REL}/{name}.png','rects':[[l,t,r,b]],'anchor':[anchors[i],b],'scale':scale})
# The painted second anticipation leans farther back; order windup before arm extension.
clips['attack']['indices'][1:3]=reversed(clips['attack']['indices'][1:3])
clips['dead']={'indices':[clips['death']['indices'][-1]],'frame_msec':1000,'loop':False,'static_frame':0}
entry={'unit_id':uid,'reference_height':256,'source_facing':'right','alpha_noise_cutoff':8,'frames':frames,'clips':clips,'accepted_clips':[],'preserve_clips':['idle','move'],'source_scale_by_image':{f'{REL}/{n}.png':s for n,(s,_,__) in sheets.items()},'source_scale_reason':'Fixed original-source scales calibrated to existing approximately 192px standing silhouette: attack/support .55, higher-resolution hit/defend and death .47. Every frame of each original sheet uses the same scale; no per-pose normalization.','visual_review':{'status':'pending','notes':'32 original action poses proposed. Existing eight-frame idle visually inspected: visible forearm/fist lift and return with steady feet, retained pending motion review. Movement v1 rejected because opposite leg lead/passing not convincingly shown, retained for provenance only. Attack source frames 2 and 3 ordered 3 then 2 for continuous anticipation-to-extension.'},'unfinished_clips':['move']}
(D/'handoff.json').write_text(json.dumps({'schema_version':1,'units':[entry]},indent=2)+'\n')
outs={'move_v1':'exec-64d8cfce-6eeb-4f7a-a29a-cfdfa60afff9.png','attack_v1':'exec-72db69af-af02-410f-9998-b822536ffd1c.png','hit_defend_v1':'exec-c3ce8480-4bcf-47f5-99ee-4ad0c09a01ab.png','death_v1':'exec-29839e8e-e560-4b50-992a-6b021fcc9e33.png','cast_v1':'exec-f4b4cf88-03de-45f7-a16f-f759dcca4200.png'}
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();ref=ROOT/'art/units/source/curated'/f'{uid}.png'
prov={'tool':'built-in image_gen','reference':ref.relative_to(ROOT).as_posix(),'reference_sha256':sha(ref),'outputs':[{'source':f'{REL}/{n}.png','source_sha256':sha(D/(n+'.png')),'prompt':f'{REL}/{n}.prompt.txt','prompt_sha256':sha(D/(n+'.prompt.txt')),'generated_output':'C:/Users/acorp/.codex/generated_images/01a0ccd0-015a-7981-ae58-ff4d5582854d/'+o,'status':'rejected_unclear_opposite_lead' if n=='move_v1' else 'pending_visual_review'} for n,o in outs.items()]}
(D/'provenance.json').write_text(json.dumps(prov,indent=2)+'\n');print(uid,len(frames),'proposed poses, move unfinished')
