from pathlib import Path
import hashlib,json
from PIL import Image
ROOT=Path(__file__).resolve().parents[7]
D=Path(__file__).resolve().parent
REL=D.relative_to(ROOT).as_posix()
uid=D.name
sheets={
'attack_v1':(.60,[[164,12,439,375],[626,13,914,373],[127,398,472,757],[589,401,1008,758],[86,791,610,1114],[624,780,979,1124],[166,1141,446,1506],[648,1138,924,1506]],[285,757,273,745,263,753,287,772]),
'hit_defend_v1':(.60,[[169,11,470,372],[631,31,958,371],[187,381,477,774],[674,381,957,775],[174,776,468,1146],[669,787,985,1149],[175,1154,496,1517],[677,1154,1005,1519]],[305,791,319,814,305,808,321,825]),
'death_v1':(.49,[[90,38,456,482],[568,131,999,482],[16,553,492,880],[528,600,1012,893],[14,962,502,1197],[528,985,1013,1199],[16,1293,502,1503],[520,1295,1018,1508]],[230,742,241,758,245,766,246,772]),
'ranged_v1':(.59,[[168,7,414,378],[624,14,963,379],[146,386,492,751],[611,394,975,753],[108,780,527,1131],[598,769,935,1131],[147,1147,460,1519],[652,1140,911,1519]],[280,745,270,735,250,738,264,751]),
'cast_v1':(.58,[[193,7,478,382],[609,7,892,382],[196,387,491,767],[610,390,905,767],[190,775,493,1151],[609,775,909,1151],[195,1159,495,1534],[609,1159,898,1534]],[312,727,315,729,313,728,317,731]),
}
frames=[];clips={}
for name,(scale,rects,anchors) in sheets.items():
 for i,rect in enumerate(rects):
  clip= ('hit' if i<4 else 'defend') if name=='hit_defend_v1' else name.split('_')[0]
  n=len(frames); clips.setdefault(clip,{'indices':[],'frame_msec':95 if clip in ('attack','ranged') else 110,'loop':False,'static_frame':0})['indices'].append(n)
  if clip in ('attack','ranged'):clips[clip]['contact_frame']=4
  l,t,r,b=rect
  frames.append({'name':f'{name}_{i:02d}','clip':clip,'source':f'{REL}/{name}.png','rects':[[max(0,l-2),max(0,t-2),min(1024,r+2),min(1536,b+2)]],'anchor':[anchors[i],b],'scale':scale})
clips['dead']={'indices':[clips['death']['indices'][-1]],'frame_msec':1000,'loop':False,'static_frame':0}
entry={'unit_id':uid,'reference_height':256,'source_facing':'right','alpha_noise_cutoff':8,'frames':frames,'clips':clips,'accepted_clips':[],'preserve_clips':['idle','move'],'visual_review':{'status':'pending','notes':'New attack, ranged, hit, defense, support and death proposed. Idle existing eight poses inspected and retained pending coordinator motion review. Existing move preserved only as compatibility, NOT quality-complete. Three gait attempts rejected for unchanged lead leg; no rejected movement is included.'},'unfinished_clips':['move']}
entry['source_scale_by_image']={f'{REL}/{name}.png':scale for name,(scale,_,__) in sheets.items()}
entry['source_scale_reason']='Different source sheets were generated at differing fixed character render sizes. Each entire source has one anatomical scale: attack and hit/defend 0.60, death 0.49 (larger standing reference), ranged 0.59, cast 0.58; calibrated to the existing approximately 218px standing silhouette at reference_height 256. No per-pose resizing or deformation.'
(D/'handoff.json').write_text(json.dumps({'schema_version':1,'units':[entry]},indent=2)+'\n')
outputs={'move_v1':'exec-6f57ce54-f5d8-4be6-b50f-76ef86a5c77b.png','attack_v1':'exec-0759d360-0fa7-453c-ae50-3b2203d1005f.png','hit_defend_v1':'exec-7e7b9875-d7b9-45ad-a114-df685bd9ab91.png','move_keys_v2':'exec-150fa3b6-74d4-4c60-8250-6cd613408021.png','move_opposite_v3':'exec-01baa2f1-b658-41c3-adf0-62245c4fe619.png','death_v1':'exec-6e26aee2-31c2-4ef8-9ed9-b422e34e6235.png','ranged_v1':'exec-e012872c-3256-4e21-9772-4949832fd9aa.png','cast_v1':'exec-93bd33e0-5bf9-46e9-a2cf-09055aab2f1e.png'}
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
ref=ROOT/'art/units/source/curated'/f'{uid}.png'
prov={'tool':'built-in image_gen','reference':ref.relative_to(ROOT).as_posix(),'reference_sha256':sha(ref),'outputs':[]}
for name,out in outputs.items():
 prov['outputs'].append({'source':f'{REL}/{name}.png','source_sha256':sha(D/(name+'.png')),'prompt':f'{REL}/{name}.prompt.txt','prompt_sha256':sha(D/(name+'.prompt.txt')),'generated_output':'C:/Users/acorp/.codex/generated_images/01a0ccd0-015a-7981-ae58-ff4d5582854d/'+out,'status':'rejected_same_leading_leg' if name.startswith('move') else 'pending_visual_review'})
(D/'provenance.json').write_text(json.dumps(prov,indent=2)+'\n')
print(f'{uid}: {len(frames)} original proposed frames, clips {list(clips)}, unresolved move')

