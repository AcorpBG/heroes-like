"""Source-only crop recipe. Candidates remain pending visual acceptance."""
import json,hashlib
from pathlib import Path
from PIL import Image
import numpy as np
HERE=Path(__file__).resolve().parent
UNIT='unit_brasshollow_quenchspool_slingers'
BASE='art/units/source/generated/fluid_animation/batch_c/'+UNIT
OUTPUTS={
'move_v1':'exec-f04fabcd-f7e2-437d-8fab-a61f82727b4b.png',
'move_v2':'exec-a38b1482-5387-466a-bb59-2f908aa887ed.png',
'move_return_v1':'exec-fe281b4b-0ef0-4a79-a997-7dc694a7ae30.png',
'attack_v1':'exec-40f9c366-d9f5-4ce6-8db9-7738137d2cbe.png',
'ranged_v1':'exec-64a45da1-8071-4c15-a37e-3aee17e81195.png',
'death_v1':'exec-8f9547fc-e74b-452d-8898-210f21108157.png',
'cast_v1':'exec-87b3f356-ee65-4c7e-b366-fa3cd639b3d0.png',
'reactions_v1':'exec-ab139a1b-1231-4dfa-97e0-c6386738faf8.png',
'idle_v1':'exec-38f2ec9f-fbb9-42bc-a180-ec4e9760363b.png'}
frames=[];clip_indices={};lineage=[]
for key in ['idle','move','attack','ranged','cast','reactions','death']:
    version='v2' if key=='move' else 'v1'
    source=key+'_'+version
    im=Image.open(HERE/(source+'.png'));a=np.array(im)[:,:,3]>8
    boundaries=[0,384,768,1152,1536] if key!='death' else [0,535,935,1260,1536]
    scale=.58 if key!='death' else .46
    anchors_x=[305,806]
    for i in range(8):
        col=i%2;row=i//2;l=col*512;r=l+512;t=boundaries[row];b=boundaries[row+1]
        clip=key if key!='reactions' else ('hit' if i<4 else 'defend')
        # Ground is the painted boot/contact baseline, independent of changing height.
        ys,xs=np.nonzero(a[t:b,l:r]);ground=t+int(ys.max()) if len(ys) else b-1
        rects=[[l,t,r,b]]
        if key=='ranged' and i==4:
            # Launch projectile is owned by runtime, isolate the actor here.
            rects=[[l,t,395,b]]
        if key=='ranged' and i==5:
            # Excludes preceding frame's projectile protruding across gutter.
            rects=[[590,t,1024,b]]
        frames.append({'name':clip+'_'+str(len(clip_indices.get(clip,[]))), 'clip':clip,
                       'source':BASE+'/'+source+'.png','rects':rects,'anchor':[anchors_x[col],ground],
                       'scale':scale,'alpha_noise_cutoff':8})
        clip_indices.setdefault(clip,[]).append(len(frames)-1)
for source,output in OUTPUTS.items():
    path=HERE/(source+'.png');prompt=HERE/(source+'.prompt.txt')
    lineage.append({'image':BASE+'/'+path.name,'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),
                    'prompt':BASE+'/'+prompt.name,'prompt_sha256':hashlib.sha256(prompt.read_bytes()).hexdigest(),
                    'reference':BASE+'/move_v1.png' if source=='move_v2' else 'art/units/source/curated/'+UNIT+'.png',
                    'generation_output':'C:/Users/acorp/.codex/generated_images/01a0ccd0-e7c2-7e63-a35e-26d49ab9c84d/'+output,
                    'status':'rejected_gait_leg_alternation' if source.startswith('move') else 'pending'})
timing={'idle':150,'move':115,'attack':100,'ranged':110,'cast':110,'hit':100,'defend':130,'death':130}
clips={k:{'indices':v,'frame_msec':timing[k],'loop':k in ['idle','move'],'static_frame':0} for k,v in clip_indices.items()}
for key in ['attack','ranged']:clips[key]['contact_frame']=4
clips['dead']={'indices':[clips['death']['indices'][-1]],'frame_msec':1000,'loop':False,'static_frame':0}
unit={'unit_id':UNIT,'reference_height':256,'source_facing':'right','frames':frames,'clips':clips,'accepted_clips':[],
      'preserve_clips':[],'source_scale_by_image':{f['source']:f['scale'] for f in frames},
      'source_scale_reason':'One fixed scale per source: .58 for ~350px standing action bodies, .46 for death source whose initial body is ~450px. Maintains previous runtime ~206px body; no individual pose scaling.',
      'visual_review':{'status':'pending','rejected_clips':['move'],
                       'notes':'All candidate actions retain identity and equipment. Move v1/v2/return sources fail clear near/far leg alternation and must not count as complete. Ranged release actor cropped separately from projectile which runtime supplies; verify no adjacent artwork. Idle replaces weak prior crank movement. Coordinator must review action timing, grounding and crop isolation.'}}
(HERE/'handoff.json').write_text(json.dumps({'schema_version':1,'units':[unit]},indent=2)+'\n',encoding='utf-8')
(HERE/'provenance.json').write_text(json.dumps({'schema_version':1,'tool':'built-in image_gen','sources':lineage,'processing':'Cropping and fixed per-source scale only; no synthetic frames.'},indent=2)+'\n',encoding='utf-8')
print(UNIT,len(frames),'candidate frames; move rejected pending revision')

# Replay visually reviewed body ownership and anatomical anchor corrections.
import sys as _crop_sys
from pathlib import Path as _CropPath
_crop_dir = _CropPath(__file__).resolve().parent
_crop_root = next(p for p in _crop_dir.parents if (p / "project.godot").exists())
_crop_sys.path.insert(0, str(_crop_root / "tools"))
from refine_fluid_frame_crops import apply_recipe as _apply_crop_recipe
_apply_crop_recipe(_crop_dir / "handoff.json", _crop_dir / "crop_refinements.json")
