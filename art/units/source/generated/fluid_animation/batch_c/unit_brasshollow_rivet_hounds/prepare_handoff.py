"""Rebuild handoff without painting or synthesizing poses."""
import json,hashlib
from pathlib import Path
from PIL import Image
import numpy as np
HERE=Path(__file__).resolve().parent
UNIT='unit_brasshollow_rivet_hounds'
BASE='art/units/source/generated/fluid_animation/batch_c/'+UNIT
OUTPUTS={'move_v1':'exec-7d29a5c7-18dc-4159-b4a9-5030301d5eb6.png',
'move_v2':'exec-c2b39c20-317f-4a49-9da9-a657aab1c3e8.png',
'attack_v1':'exec-ec9211ff-854f-429a-82f0-1ad0b6c7ace0.png',
'death_v1':'exec-bab9b6ac-4b7e-44ad-ba83-1e07adbe8ed6.png',
'cast_v1':'exec-13d8e90d-3bb3-4422-875c-740e7a377999.png',
'reactions_v1':'exec-fe338212-57bc-42e1-88f0-32fcd1c4bf78.png',
'idle_v1':'exec-6e32d19c-bc41-42b6-a08b-24fb3c46fa17.png'}
RECIPES={
 'idle':([0,410,775,1140,1536],525,.53,[272,775]),
 'move':([0,400,760,1120,1536],512,.57,[270,774]),
 'attack':([0,350,651,953,1287],634,.46,[326,945]),
 'cast':([0,405,766,1140,1536],535,.53,[270,773]),
 'reactions':([0,433,796,1147,1536],534,.53,[276,780]),
 'death':([0,460,850,1200,1536],512,.55,[273,777]),
}
frames=[];clip_indices={};lineage=[]
for key in ['idle','move','attack','cast','reactions','death']:
 source=key+('_v2' if key=='move' else '_v1');im=Image.open(HERE/(source+'.png'));a=np.array(im)[:,:,3]>8
 bands,split,scale,ax=RECIPES[key]
 for i in range(8):
  col=i%2;row=i//2;l=0 if col==0 else split;r=split if col==0 else im.width;t=bands[row];b=bands[row+1]
  clip=key if key!='reactions' else ('hit' if i<4 else 'defend')
  ys,xs=np.nonzero(a[t:b,l:r]);ground=t+int(ys.max())
  frames.append({'name':clip+'_'+str(len(clip_indices.get(clip,[]))),'clip':clip,'source':BASE+'/'+source+'.png','rects':[[l,t,r,b]],'anchor':[ax[col],ground],'scale':scale,'alpha_noise_cutoff':8})
  clip_indices.setdefault(clip,[]).append(len(frames)-1)
for source,output in OUTPUTS.items():
 path=HERE/(source+'.png');prompt=HERE/(source+'.prompt.txt')
 lineage.append({'image':BASE+'/'+path.name,'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'prompt':BASE+'/'+prompt.name,
 'prompt_sha256':hashlib.sha256(prompt.read_bytes()).hexdigest(),'reference':'art/units/source/curated/'+UNIT+'.png',
 'generation_output':'C:/Users/acorp/.codex/generated_images/01a0ccd0-e7c2-7e63-a35e-26d49ab9c84d/'+output,
 'status':'rejected_clipped_rightmost_noses' if source=='move_v1' else 'pending'})
timing={'idle':150,'move':110,'attack':100,'cast':110,'hit':100,'defend':130,'death':130}
clips={k:{'indices':v,'frame_msec':timing[k],'loop':k in ['idle','move'],'static_frame':0} for k,v in clip_indices.items()}
clips['attack']['contact_frame']=4
clips['dead']={'indices':[clips['death']['indices'][-1]],'frame_msec':1000,'loop':False,'static_frame':0}
unit={'unit_id':UNIT,'reference_height':256,'source_facing':'right','frames':frames,'clips':clips,'accepted_clips':[],'preserve_clips':[],
'source_scale_by_image':{f['source']:f['scale'] for f in frames},
'source_scale_reason':'Fixed per-original source calibration to old 254px-wide idle silhouette: regular bodies .53, move .57, death .55, larger 1222x1287 attack master .46. No per-pose scale normalization.',
'visual_review':{'status':'pending','notes':'Original idle had mostly tail movement; replaced with forepaw movement. Six new source sheets supply48paintings. Original4x2 move rejected for rightmost nose clipping, replaced2x4. Individually authored row gutters and x split preserve protruding noses. Review cycle continuity and actual grounded scale before acceptance.'}}
(HERE/'handoff.json').write_text(json.dumps({'schema_version':1,'units':[unit]},indent=2)+'\n',encoding='utf-8')
(HERE/'provenance.json').write_text(json.dumps({'schema_version':1,'tool':'built-in image_gen','sources':lineage,'processing':'Crop and one fixed scale per source only; no synthetic poses.'},indent=2)+'\n',encoding='utf-8')
print(UNIT,len(frames),'candidate paintings pending review')
