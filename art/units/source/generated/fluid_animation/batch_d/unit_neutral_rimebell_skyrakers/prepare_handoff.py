"""Source extraction and pending handoff; no pose synthesis or runtime writes."""
import json,hashlib
from pathlib import Path
import numpy as np
from PIL import Image
HERE=Path(__file__).resolve().parent
ROOT=next(p for p in HERE.parents if (p/'project.godot').exists())
REL=HERE.relative_to(ROOT).as_posix()
OUTPUT='C:/Users/acorp/.codex/generated_images/01a0ccd3-0f4d-76f1-9dbf-e05854f78ac7/'
outputs={'move_v2':'exec-2867d1cf-5133-4778-8cec-1e3c0bb67f85.png','attack_v1':'exec-fa7e826a-8853-48bd-87a7-7fd5948815eb.png','reactions_v1':'exec-f571e41d-9abf-434e-814c-c9dfdbe0d6eb.png','death_v1':'exec-40dadf04-4d1c-47cf-bdcb-d3272bdc8b67.png','cast_v1':'exec-fcb6436c-7a2b-4bab-8f2c-e8185f982900.png'}
def components(alpha):
 parents=[];runs=[];previous=[]
 def root(i):
  while parents[i]!=i:parents[i]=parents[parents[i]];i=parents[i]
  return i
 for y,row in enumerate(alpha>16):
  edges=np.flatnonzero(np.diff(np.r_[False,row,False]));current=[]
  for x0,x1 in edges.reshape(-1,2):
   i=len(parents);parents.append(i);current.append((int(x0),int(x1),i));runs.append((y,int(x0),int(x1),i))
   for p0,p1,j in previous:
    if p0<=x1 and p1>=x0:parents[root(i)]=root(j)
  previous=current
 groups={}
 for y,x0,x1,i in runs:groups.setdefault(root(i),[]).append((y,x0,x1))
 return sorted(groups.values(),key=lambda rr:sum(b-a for _,a,b in rr),reverse=True)
frames=[];clips={};records=[];mapping={}
spec={'attack_v1':('attack',list(range(8)),100,4,.50),'move_v2':('move',list(range(8)),100,None,.50),'death_v1':('death',list(range(8)),115,None,.53),'cast_v1':('cast',list(range(8)),115,4,.53),'reactions_v1':('hit',[0,2,4,6],110,None,.53)}
for stem,out in outputs.items():
 prompt=HERE/(stem+'.prompt.txt');data=prompt.read_bytes().rstrip(b'\r\n');prompt.write_bytes(data)
 im=Image.open(HERE/(stem+'.png')).convert('RGBA');array=np.array(im);groups=components(array[:,:,3]);major=groups[:8]
 def box(g):return (min(a for _,a,b in g),min(y for y,a,b in g),max(b for _,a,b in g),max(y for y,a,b in g)+1)
 # Sort by source rows then left/right, allowing collapse heights to differ.
 major.sort(key=lambda g:(box(g)[1]+box(g)[3])/2)
 ordered=[]
 for row in range(4):ordered+=sorted(major[row*2:row*2+2],key=lambda g:box(g)[0])
 boxes=[box(g) for g in ordered]
 # Preserve small disconnected equipment/fire components with nearest figure.
 for g in groups[8:]:
  b=box(g);cx=(b[0]+b[2])/2;cy=(b[1]+b[3])/2
  nearest=min(range(8),key=lambda i:((boxes[i][0]+boxes[i][2])/2-cx)**2+((boxes[i][1]+boxes[i][3])/2-cy)**2)
  if sum(x1-x0 for _,x0,x1 in g)>=2:ordered[nearest].extend(g)
 for cell,g in enumerate(ordered):
  b=box(g);canvas=Image.new('RGBA',im.size);pixels=np.zeros_like(array)
  for y,x0,x1 in g:pixels[y,x0:x1]=array[y,x0:x1]
  # Preserve source pixels exactly above alpha cutoff (16/255 to sever faint background bridges), do not transform anatomy.
  cropped=Image.fromarray(pixels).crop(b);dst=HERE/'extracted'/f'{stem}_{cell:02d}.png';dst.parent.mkdir(exist_ok=True);cropped.save(dst)
  mapping[(stem,cell)]=(dst.relative_to(ROOT).as_posix(),cropped.size,b)
 records.append({'source':REL+'/'+stem+'.png','source_sha256':hashlib.sha256((HERE/(stem+'.png')).read_bytes()).hexdigest(),'prompt':REL+'/'+prompt.name,'prompt_sha256':hashlib.sha256(data).hexdigest(),'reference':'art/units/source/curated/unit_neutral_rimebell_skyrakers.png','output':OUTPUT+out,'tool':'built-in image_gen','status':'pending_visual_review'})
for stem,(clip,order,msec,contact,scale) in spec.items():
 subsets=[(clip,order)] if stem!='reactions_v1' else [('hit',[0,2,4,6]),('defend',[1,3,5,7])]
 for clip,order in subsets:
  ids=[]
  for cell in order:
   source,size,b=mapping[(stem,cell)];ids.append(len(frames));frames.append({'name':f'{clip}_{len(ids)-1:02d}','clip':clip,'source':source,'rects':[[0,0,*size]],'anchor':[size[0]/2,size[1]],'scale':scale})
  clips[clip]={'indices':ids,'frame_msec':msec,'loop':clip=='move','static_frame':len(ids)-1 if clip in ('defend','death') else 0}
  if contact is not None:clips[clip]['contact_frame']=contact
# Register hovering clips by chest rather than variable wing/tail envelope.
cores={
 'move_v2':[(289,233),(841,239),(300,506),(844,520),(310,789),(845,789),(302,1099),(845,1090)],
 'attack_v1':[(288,214),(858,219),(302,510),(863,507),(322,804),(875,804),(294,1103),(864,1103)],
 'reactions_v1':[(196,245),(651,241),(188,631),(658,624),(202,1010),(650,1007),(203,1368),(651,1357)],
 'cast_v1':[(200,230),(704,233),(204,580),(716,617),(205,985),(710,970),(203,1327),(710,1323)]}
for frame in frames:
 stem=Path(frame['source']).stem.rsplit('_',1)[0];cell=int(Path(frame['source']).stem.rsplit('_',1)[1])
 if stem in cores:
  _,_,bounds=mapping[(stem,cell)];cx,cy=cores[stem][cell]
  frame['anchor']=[cx+60-bounds[0],cy+125-bounds[1]]
clips['dead']={'indices':[clips['death']['indices'][-1]],'frame_msec':100,'loop':False}
unit={'unit_id':'unit_neutral_rimebell_skyrakers','reference_height':256,'source_facing':'left','frames':frames,'clips':clips,'preserve_clips':['idle'],'accepted_clips':[],'source_scale_by_image':{f['source']:f['scale'] for f in frames},'source_scale_reason':'Fixed per-original resolution: square move/attack sheets show approximately460px resting width at0.50; portrait reaction/death/support sheets about430px resting width at0.53. Target about230px resting wingspan matching inherited runtime; all poses of original share scale, no per-pose normalization.','visual_review':{'status':'pending','notes':['Existing eight-pose idle inspected: independent wing feather flexion and slight talon movement; preserve pending coordinator confirmation. Existing runtime faces RIGHT and new sources LEFT; preserve pipeline must normalize facing.','New flight wingbeat pending temporal review; source v1 clipped tail and is rejected. Anchor requires chest alignment for hovering body.','Extracted images copy original alpha>16 component pixels without synthesis or deformation; preserved masters and rebuild recipe included.','Death terminal is grounded closed-eye corpse; no additional corpse painting.']}}
prompt=HERE/'move_v1.prompt.txt';raw=prompt.read_bytes().rstrip(b'\r\n');prompt.write_bytes(raw)
records.append({'source':REL+'/move_v1.png','source_sha256':hashlib.sha256((HERE/'move_v1.png').read_bytes()).hexdigest(),'prompt':REL+'/'+prompt.name,'prompt_sha256':hashlib.sha256(raw).hexdigest(),'reference':'art/units/source/curated/unit_neutral_rimebell_skyrakers.png','output':OUTPUT+'exec-c692c987-b96d-4667-8165-3595cfb29a9c.png','tool':'built-in image_gen','status':'rejected','reason':'4x2 layout clips right tail; superseded by move_v2.'})
(HERE/'provenance.json').write_text(json.dumps({'schema_version':1,'records':records,'extraction':'Connected components alpha>16; eight largest figures in row-major order; small detached features assigned nearest body; copied exact pixels, no painting.'},indent=2)+'\n')
(HERE/'handoff.json').write_text(json.dumps({'schema_version':1,'units':[unit]},indent=2)+'\n')
print('Pending handoff',len(frames),'poses, preserve inspected idle; review required')
