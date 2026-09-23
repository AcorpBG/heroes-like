from pathlib import Path
import json,hashlib
from PIL import Image
import numpy as np
ROOT=Path(__file__).resolve().parents[7];D=Path(__file__).resolve().parent;REL=D.relative_to(ROOT).as_posix();uid=D.name

def components(im):
 a=np.asarray(im)[:,:,3]>8;parent=[];boxes=[];counts=[];prev=[];runs=[]
 def root(i):
  while parent[i]!=i:parent[i]=parent[parent[i]];i=parent[i]
  return i
 for y,row in enumerate(a):
  delta=np.diff(np.r_[False,row,False].astype('int8'));starts=np.where(delta==1)[0];ends=np.where(delta==-1)[0];cur=[]
  for l,r in zip(starts,ends):
   ov=[root(i) for pl,pr,i in prev if pl<=r and pr>=l]
   if ov:
    i=ov[0]
    for j in ov[1:]:
     j=root(j);i=root(i)
     if i!=j:
      parent[j]=i;b=boxes[j];z=boxes[i];boxes[i]=[min(z[0],b[0]),min(z[1],b[1]),max(z[2],b[2]),max(z[3],b[3])];counts[i]+=counts[j];counts[j]=0
    b=boxes[i];boxes[i]=[min(b[0],int(l)),min(b[1],y),max(b[2],int(r)),y+1];counts[i]+=int(r-l)
   else:i=len(parent);parent.append(i);boxes.append([int(l),y,int(r),y+1]);counts.append(int(r-l))
   cur.append((l,r,i));runs.append((int(l),int(r),y,i))
  prev=cur
 mains=[i for i in range(len(parent)) if root(i)==i and counts[i]>1000]
 mains.sort(key=lambda i:(boxes[i][1]+boxes[i][3])/2)
 ordered=[]
 for k in range(0,len(mains),2):ordered+=sorted(mains[k:k+2],key=lambda i:boxes[i][0])
 groups={i:[] for i in ordered};assignment={i:i for i in ordered}
 for i in range(len(parent)):
  if root(i)!=i or i in assignment:continue
  b=boxes[i];cx=(b[0]+b[2])/2;cy=(b[1]+b[3])/2
  def dist(j):
   l,t,r,bt=boxes[j];return max(l-cx,0,cx-r)**2+max(t-cy,0,cy-bt)**2
  assignment[i]=min(ordered,key=dist)
 for l,r,y,i in runs:groups[assignment[root(i)]].append((l,r,y))
 result=[]
 for i in ordered:
  rr=groups[i];l=min(x[0] for x in rr);r=max(x[1] for x in rr);t=min(x[2] for x in rr);b=max(x[2] for x in rr)+1
  out=Image.new('RGBA',(r-l,b-t))
  for x1,x2,y in rr:out.paste(im.crop((x1,y,x2,y+1)),(x1-l,y-t))
  result.append((out,[l,t,r,b]))
 return result

specs={
'move_v1':(.58,8,[290,770,290,770,290,770,290,770]),
'attack_v1':(.51,8,[285,748,276,763,260,753,286,770]),
'hit_defend_v1':(.51,4,[297,759,295,770]),
'defend_v2':(.31,4,[370,1000,366,1000]),
'death_v1':(.47,8,[287,898,285,890,288,899,292,900]),
'ranged_v1':(.57,8,[305,845,302,845,301,845,305,849]),
'cast_v1':(.52,6,[293,770,295,777,301,776]),
'cast_return_v2':(.275,2,[460,1174])}
frames=[];clips={};mapping={};origmap={};extracts=[]
for name,(scale,count,xanchors) in specs.items():
 im=Image.open(D/(name+'.png')).convert('RGBA');found=components(im)
 expect=4 if name=='defend_v2' else 2 if name=='cast_return_v2' else 8
 assert len(found)==expect,(name,len(found))
 for i,(out,rect) in enumerate(found[:count]):
  clip='hit' if name=='hit_defend_v1' else 'cast' if name.startswith('cast') else name.split('_')[0]
  fn=f'{name}_frame_{i:02d}.png';out.save(D/fn)
  source=f'{REL}/{fn}';mapping[source]=scale;origmap[source]=f'{REL}/{name}.png'
  # Anatomical ground/hover reference comes from the original pose, not resized per-frame geometry.
  anchor=[xanchors[i]-rect[0],rect[3]-rect[1]]
  frames.append({'name':fn[:-4],'clip':clip,'source':source,'rects':[[0,0,out.width,out.height]],'anchor':anchor,'scale':scale,'original_source':f'{REL}/{name}.png','source_rect':rect})
  spec=clips.setdefault(clip,{'indices':[],'frame_msec':95 if clip in ('attack','ranged') else 110,'loop':clip=='move','static_frame':0});spec['indices'].append(len(frames)-1)
  if clip in ('attack','ranged'):spec['contact_frame']=4
  extracts.append({'file':source,'original_source':f'{REL}/{name}.png','original_bounds':rect,'method':'Original connected alpha pixels extracted without repainting, alpha <=8 omitted, separate neighboring poses excluded.'})
clips['dead']={'indices':[clips['death']['indices'][-1]],'frame_msec':1000,'loop':False,'static_frame':0}
entry={'unit_id':uid,'reference_height':256,'source_facing':'right','frames':frames,'clips':clips,'accepted_clips':[],'preserve_clips':['idle'],'source_scale_by_image':mapping,'source_original_by_image':origmap,'source_scale_reason':'All poses from a given original sheet have exactly one scale: flight .58, attack/hit .51, defense .31, death .47, ranged .57, support .52, support return .275. Original sheets have different raster resolutions. Calibration targets old ~194px standing crown-to-foot height and corresponding torso size; raised flight wings may extend higher. Connected-alpha extraction preserves original pose pixels; no per-frame resizing/warping.','visual_review':{'status':'pending','notes':'Forty-eight new proposed action drawings. Existing eight idle reviewed with articulated blowpipe raising and lowering, retained pending coordinator review. Flight shows full wing stroke; revised guard keeps pipe muzzle right. Original support final two frames clipped toes, replaced with two newly generated return poses. Original guard half rejected for reversing pipe; only original hit half used.'}}
(D/'handoff.json').write_text(json.dumps({'schema_version':1,'units':[entry]},indent=2)+'\n')
outs={'move_v1':'exec-16ec5533-95d0-49fb-af19-49d3a78d0772.png','attack_v1':'exec-b03d7957-fa4e-44a3-99b3-8502ceb05735.png','hit_defend_v1':'exec-d00252b7-a25b-485b-8f6e-8673fd896b90.png','defend_v2':'exec-b9f164be-e43c-4df9-b1c7-22a64ee2f579.png','death_v1':'exec-83324719-a674-4e21-b09f-30426f27ca0e.png','ranged_v1':'exec-d993777e-cd71-4f9a-9c5b-d2c2dda79f21.png','cast_v1':'exec-0fcc1eb5-90d8-4684-98dc-0e93af80b89a.png','cast_return_v2':'exec-d767f24d-8739-4b17-b40b-272c2f8e925a.png'}
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();ref=ROOT/'art/units/source/curated'/f'{uid}.png'
prov={'tool':'built-in image_gen','reference':ref.relative_to(ROOT).as_posix(),'reference_sha256':sha(ref),'outputs':[],'extraction':extracts}
for n,o in outs.items():
 prov['outputs'].append({'source':f'{REL}/{n}.png','source_sha256':sha(D/(n+'.png')),'prompt':f'{REL}/{n}.prompt.txt','prompt_sha256':sha(D/(n+'.prompt.txt')),'generated_output':'C:/Users/acorp/.codex/generated_images/01a0ccd0-015a-7981-ae58-ff4d5582854d/'+o,'references':[ref.relative_to(ROOT).as_posix()]+([f'{REL}/cast_v1.png'] if n=='cast_return_v2' else []),'status':'partially_rejected_guard_half' if n=='hit_defend_v1' else 'partially_rejected_clipped_final_two' if n=='cast_v1' else 'pending_visual_review'})
(D/'provenance.json').write_text(json.dumps(prov,indent=2)+'\n');print(uid,len(frames),'proposed poses',list(clips))

# Replay visually reviewed body ownership and anatomical anchor corrections.
import sys as _crop_sys
from pathlib import Path as _CropPath
_crop_dir = _CropPath(__file__).resolve().parent
_crop_root = next(p for p in _crop_dir.parents if (p / "project.godot").exists())
_crop_sys.path.insert(0, str(_crop_root / "tools"))
from refine_fluid_frame_crops import apply_recipe as _apply_crop_recipe
_apply_crop_recipe(_crop_dir / "handoff.json", _crop_dir / "crop_refinements.json")
