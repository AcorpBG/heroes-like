"""Rebuild this unit's authored crop recipe and byte-exact lineage."""
from pathlib import Path
from PIL import Image
import numpy as np
import json, hashlib

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[6]
UNIT='unit_brasshollow_quenchbell_mortars'
BASE='art/units/source/generated/fluid_animation/batch_c/'+UNIT
ORIGINALS={
 'move':'exec-ec07fe8f-bf1b-4e85-9551-c452cb6489ec.png',
 'attack':'exec-bc58b61c-3e52-4bf1-8108-5ebe796c7528.png',
 'ranged':'exec-0a49d7cd-8be1-46fd-a075-044eda710ac5.png',
 'death':'exec-6b261e7d-528f-427d-9151-b7f8ac95ab1b.png',
 'cast':'exec-8f52ada3-fd4f-4be8-905c-43147b860ce6.png',
 'reactions':'exec-7a29e90d-c5a1-4cbd-89e2-a1d27986bd4e.png',
 'idle':'exec-3e6ebfeb-f4ac-4e3b-9f01-1d1fa19b0bce.png',
}
# Authored row boundaries follow the actual irregular transparent gutters.
RECIPES={
 'idle':([0,380,766,1149,1536],.57,[293,802],[369,370,754,754,1139,1138,1523,1522]),
 'move':([0,377,758,1131,1536],.57,[300,802],[372,370,749,750,1125,1125,1508,1509]),
 'attack':([0,372,754,1127,1536],.57,[335,850],[369,368,747,746,1122,1122,1510,1506]),
 'ranged':([0,379,754,1145,1536],.57,[291,804],[371,370,748,747,1139,1141,1515,1516]),
 'death':([0,462,874,1240,1536],.51,[304,808],[452,452,839,840,1168,1179,1505,1505]),
 'cast':([0,329,651,989,1312],.66,[369,877],[322,322,648,648,982,982,1304,1304]),
 'reactions':([0,331,666,964,1287],.66,[373,890],[327,328,659,658,955,956,1256,1256]),
}
frames=[];clips={};lineage=[]
for source_key in ['idle','move','attack','ranged','cast','reactions','death']:
    name=source_key+'_v1'
    path=HERE/(name+'.png'); im=Image.open(path)
    bands,scale,ax,ay=RECIPES[source_key]
    for i in range(8):
        col=i%2;row=i//2;left=round(col*im.width/2);right=round((col+1)*im.width/2)
        clip=source_key if source_key!='reactions' else ('hit' if i<4 else 'defend')
        rects=[[left,bands[row],right,bands[row+1]]]
        if source_key=='attack' and i==4:
            rects=[[0,bands[row],565,bands[row+1]]]
        if source_key=='attack' and i==5:
            rects=[[565,bands[row],1024,bands[row+1]]]
        if source_key=='cast' and i==4:
            rects=[[left,644,280,651],[left,651,right,bands[row+1]]]
        if source_key=='ranged' and i==4:
            rects=[[left,735,120,754],[left,754,right,bands[row+1]]]
        frames.append({'name':f'{clip}_{len(clips.get(clip,[]))}','clip':clip,'source':BASE+'/'+name+'.png',
                       'rects':rects,'anchor':[ax[col],ay[i]],'scale':scale,'alpha_noise_cutoff':8})
        clips.setdefault(clip,[]).append(len(frames)-1)
    prompt=HERE/(name+'.prompt.txt')
    lineage.append({'image':BASE+'/'+name+'.png','sha256':hashlib.sha256(path.read_bytes()).hexdigest(),
                    'prompt':BASE+'/'+name+'.prompt.txt','prompt_sha256':hashlib.sha256(prompt.read_bytes()).hexdigest(),
                    'reference':'art/units/source/curated/'+UNIT+'.png',
                    'generation_output':'C:/Users/acorp/.codex/generated_images/01a0ccd0-e7c2-7e63-a35e-26d49ab9c84d/'+ORIGINALS[source_key]})
timings={'idle':150,'move':115,'attack':100,'ranged':110,'cast':110,'hit':100,'defend':130,'death':130}
clips={k:{'indices':v,'frame_msec':timings[k],'loop':k in ['idle','move'],'static_frame':0} for k,v in clips.items()}
for k in ['attack','ranged']: clips[k]['contact_frame']=4
clips['dead']={'indices':[clips['death']['indices'][-1]],'frame_msec':1000,'loop':False,'static_frame':0}
unit={'unit_id':UNIT,'reference_height':256,'source_facing':'left','frames':frames,'clips':clips,
      'source_scale_by_image':{BASE+'/'+key+'_v1.png':value[1] for key,value in RECIPES.items()},
      'source_scale_reason':'Fixed source-image resolution calibration to the existing runtime ~206px standing machine. Regular sheets use 0.57; the larger death source uses 0.51 preserving machinery volume throughout collapse; cast/reactions masters are 1199x1312 and 1222x1287 with smaller painted standing bodies, use 0.66. Each original retains exactly one scale for all its poses, never normalizing individual pose bounding boxes.',
      'accepted_clips':[],'preserve_clips':[],
      'visual_review':{'status':'pending','notes':'Original runtime idle inspected: weak arm motion, replaced. New sources preserve furnace machine identity and articulate limbs. Coordinator must check motion continuity, crop isolation, contact and body scale. Uneven generated gutters have individually authored row boundaries; tiny detached steam at boundaries may need further isolation.'}}
(HERE/'handoff.json').write_text(json.dumps({'schema_version':1,'units':[unit]},indent=2)+'\n',encoding='utf-8')
(HERE/'provenance.json').write_text(json.dumps({'schema_version':1,'tool':'built-in image_gen','sources':lineage,'processing':'Crop rectangles and fixed source scale only; no painted/warped/interpolated frames.'},indent=2)+'\n',encoding='utf-8')
print('Prepared',UNIT,len(frames),'source paintings; pending visual acceptance')
