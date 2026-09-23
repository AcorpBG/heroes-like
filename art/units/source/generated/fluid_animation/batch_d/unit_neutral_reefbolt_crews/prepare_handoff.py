"""Rebuild pending source handoff; no painting, warping, or runtime mutations."""
import json, hashlib
from pathlib import Path
from PIL import Image

HERE = Path(__file__).resolve().parent
ROOT = next(p for p in HERE.parents if (p / 'project.godot').exists())
relative = HERE.relative_to(ROOT).as_posix()
generation = 'C:/Users/acorp/.codex/generated_images/01a0ccd3-0f4d-76f1-9dbf-e05854f78ac7/'
outputs = {
 'idle_return_v1':'exec-a9908379-b728-4180-b119-9b22a172238f.png',
 'move_v3':'exec-b0607bbf-f008-44f9-bb23-74a67511c795.png',
 'idle_v1':'exec-3806b056-b186-4fab-8359-c0807f167c8a.png',
 'idle_v2':'exec-286ad24e-d907-4569-9df3-0aa926cb195f.png',
 'move_v1':'exec-2ac2786e-4c35-4951-b78f-eac09ebeae10.png',
 'move_v2':'exec-53ca470f-5590-42ed-8dba-02b9c963e754.png',
 'ranged_v1':'exec-c74b5d1a-f4e6-44a0-a1af-54e67117215b.png',
 'reactions_v1':'exec-fdc9549c-a606-4e88-b77c-31b2f116402f.png',
 'death_v1':'exec-0c0b2796-5012-47ea-b856-48b85d26b5af.png',
 'cast_v1':'exec-79a20d80-92b8-4cc2-a96d-07bb65ae81ab.png',
 'attack_v1':'exec-ce52a235-8e60-48a9-bf0b-34f5bb632c70.png',
}
records=[]
for stem,output in outputs.items():
 prompt=HERE/(stem+'.prompt.txt')
 # apply_patch's trailing newline was not part of the image tool argument.
 content=prompt.read_bytes().rstrip(b'\r\n');prompt.write_bytes(content)
 reference=relative+'/move_v1.png' if stem=='move_v2' else relative+'/idle_v2.png' if stem=='idle_return_v1' else 'art/units/source/curated/unit_neutral_reefbolt_crews.png'
 records.append({'source':relative+'/'+stem+'.png','source_sha256':hashlib.sha256((HERE/(stem+'.png')).read_bytes()).hexdigest(),'prompt':relative+'/'+prompt.name,'prompt_sha256':hashlib.sha256(content).hexdigest(),'tool':'built-in image_gen','output':generation+output,'reference':reference,'status':'rejected' if stem in ('idle_v1','move_v1','move_v2') else 'pending_visual_review'})
(HERE/'provenance.json').write_text(json.dumps({'schema_version':1,'records':records,'notes':['Idle v1 clips weapon edge. Idle v2 needs smoother return. Both gait attempts keep near leg forward; rejected, not counted complete.','No automatic visual acceptance. Generated masters retained unchanged.']},indent=2)+'\n')
frames=[];clips={}
specs=[('attack','attack_v1',list(range(8)),[0,386,769,1156,1536],.60,100,4),('ranged','ranged_v1',[0,1,2,3,6,4,5,7],[0,390,770,1153,1536],.60,115,2),('hit','reactions_v1',list(range(4)),[0,425,835,1198,1536],.54,105,None),('defend','reactions_v1',list(range(4,8)),[0,425,835,1198,1536],.54,110,None),('death','death_v1',list(range(8)),[0,456,820,1200,1536],.60,115,None),('cast','cast_v1',[0,2,1,3,4,5,6,7],[0,388,764,1159,1536],.60,110,4)]
for clip,stem,order,ys,scale,msec,contact in specs:
 indices=[]
 for cell in order:
  col,row=cell%2,cell//2;left,right=col*512,(col+1)*512
  rects=[[left,ys[row],right,ys[row+1]]]
  if stem=='cast_v1' and cell==2:rects=[[0,388,512,752],[215,752,512,764]]
  if stem=='cast_v1' and cell==4:rects=[[0,764,512,1159],[130,750,195,764]]
  # Anchor follows stationary tripod ground contact; collapse keeps the ground plane.
  ground={'attack_v1':[375,375,758,758,1141,1141,1526,1526], 'ranged_v1':[383,388,766,765,1153,1147,1526,1525], 'reactions_v1':[420,420,817,819,1188,1188,1525,1529], 'death_v1':[419,419,784,779,1156,1138,1481,1468], 'cast_v1':[381,381,762,762,1153,1153,1529,1529]}[stem][cell]
  indices.append(len(frames));frames.append({'name':f'{clip}_{len(indices)-1:02d}','clip':clip,'source':relative+'/'+stem+'.png','rects':rects,'anchor':[left+284,ground],'scale':scale})
 clips[clip]={'indices':indices,'frame_msec':msec,'loop':False,'static_frame':len(indices)-1 if clip in ('defend','death') else 0}
 if contact is not None:clips[clip]['contact_frame']=contact
clips['dead']={'indices':[clips['death']['indices'][-1]],'frame_msec':100,'loop':False}
unit={'unit_id':'unit_neutral_reefbolt_crews','reference_height':256,'source_facing':'right','frames':frames,'clips':clips,'accepted_clips':[],'preserve_clips':['idle','move'],'visual_review':{'status':'pending','notes':['Partial handoff; idle and move remain deficient and need replacement.','Ranged source cells reordered 1,2,3,4,7,5,6,8 for consistent unloaded-to-loaded recovery.','Cast source cells reordered 1,3,2,4,5,6,7,8 to follow hand elevation.','Review melee frame 3 bolt direction and overlap crops before acceptance.']}}
idle=[]
for cell in range(8):
 stem='idle_v2' if cell<4 else 'idle_return_v1';local=cell if cell<4 else cell-4
 col,row=local%2,local//2
 ys=[0,393,769] if cell<4 else [0,740,1536]
 scale=.60 if cell<4 else .49
 ground=[386,386,761,761][local] if cell<4 else [620,620,1317,1310][local]
 rects=[[col*512,ys[row],(col+1)*512,ys[row+1]]]
 if stem=='idle_return_v1' and col==0:rects[0][2]=520
 idle.append(len(frames));frames.append({'name':f'idle_{cell:02d}','clip':'idle','source':relative+'/'+stem+'.png','rects':rects,'anchor':[col*512+284,ground],'scale':scale})
clips['idle']={'indices':idle,'frame_msec':140,'loop':True,'static_frame':0}
unit['preserve_clips']=['move']
unit['source_scale_by_image']={f['source']:f['scale'] for f in frames}
unit['source_scale_reason']='Fixed painting-resolution normalization, not per-pose resizing. Main 2x4 sheets paint the standing crew about 360 px tall (0.60); reaction sheet paints its neutral crew about 400 px tall (0.54); separate 2x2 idle-return sheet paints crew about 440 px tall (0.49). Each original source uses one identical scale across every selected pose. New target standing height is about 216 px within reference_height 256; runtime visual review remains pending.'
unit['visual_review']['notes'][0]='Idle revised using four original raising poses and four new lowering poses; pending anchor/volume review. Gait remains deficient; move_v3 is retained for review but not in this handoff.'
(HERE/'handoff.json').write_text(json.dumps({'schema_version':1,'units':[unit]},indent=2)+'\n')
print('Pending handoff:',len(frames),'new frames; idle/move incomplete')
