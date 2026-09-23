import json,hashlib
from pathlib import Path
from PIL import Image,ImageDraw
D=Path(__file__).parent;R=Path.cwd();unit=D.name
specs={'move':('move_v1',4,2),'attack':('attack_v2',2,4),'ranged':('ranged_v2',2,4),'idle':('idle_v1',2,4),'reaction':('reaction_v1',2,4),'cast':('cast_v1',2,4),'death':('death_v1',2,4)}
frames=[];clips={};source_scales={}
for master,(stem,cols,rows) in specs.items():
 im=Image.open(D/(stem+'.png')).convert('RGBA');W,H=im.size;a=bytearray(im.getchannel('A').point(lambda x:255 if x>8 else 0).tobytes());parts=[]
 for p in range(len(a)):
  if not a[p]:continue
  q=[p];a[p]=0;part=[];x0=x1=p%W;y0=y1=p//W
  while q:
   k=q.pop();part.append(k);x=k%W;y=k//W;x0=min(x0,x);x1=max(x1,x);y0=min(y0,y);y1=max(y1,y)
   for xx,yy in [(x-1,y),(x+1,y),(x,y-1),(x,y+1)]:
    if 0<=xx<W and 0<=yy<H:
     n=yy*W+xx
     if a[n]:a[n]=0;q.append(n)
  parts.append((part,[x0,y0,x1+1,y1+1]))
 bodies=sorted([v for v in parts if len(v[0])>20000],key=lambda v:(round((v[1][1]+v[1][3])/2/(H/rows)-.5),round((v[1][0]+v[1][2])/2/(W/cols)-.5)))
 assert len(bodies)==8,(master,len(bodies))
 srca=im.getchannel('A').tobytes()
 for i,(body,box) in enumerate(bodies):
  l,t,r,b=box;keep=set(body)
  # Preserve disconnected luminous motes belonging to this own source cell.
  if master in ('ranged','cast'):
   for pp,bb in parts:
    if len(pp)<1000 and l-10<=bb[0] and bb[2]<=r+10 and t-10<=bb[1] and bb[3]<=b+10: keep.update(pp)
  crop=im.crop(box);crop.putalpha(Image.frombytes('L',(r-l,b-t),bytes(srca[y*W+x] if y*W+x in keep else 0 for y in range(t,b) for x in range(l,r))))
  fn=f'{stem}_frame_{i}.png';crop.save(D/fn);source=(D/fn).relative_to(R).as_posix();scale=.46;source_scales[source]=scale
  clip=('hit' if i<4 else 'defend') if master=='reaction' else master;k=i%4 if master=='reaction' else i
  ax=(i%cols)*(W/cols)+300
  gy=(i//cols)*(H/rows)+(430 if master=='move' else 390)
  if master=='death':gy=[430,820,1180,1500][i//cols]
  anchor=[round(ax-l),round(gy-t)];idx=len(frames)
  frames.append({'name':f'{clip}_{k}','clip':clip,'source':source,'rects':[[0,0,r-l,b-t]],'anchor':anchor,'scale':scale,'alpha_noise_cutoff':8,'source_master':(D/(stem+'.png')).relative_to(R).as_posix(),'source_master_rect':box})
  clips.setdefault(clip,{'indices':[],'frame_msec':{'idle':130,'move':100,'attack':95,'ranged':105,'cast':110,'hit':100,'defend':110,'death':130}[clip],'loop':clip in ('idle','move'),'static_frame':3 if clip=='defend' else 0})['indices'].append(idx)
for c in ('attack','ranged','cast'):clips[c]['contact_frame']=4
clips['dead']={'indices':[clips['death']['indices'][-1]],'frame_msec':1000,'loop':False,'static_frame':0}
u={'unit_id':unit,'reference_height':256,'source_facing':'right','frames':frames,'clips':clips,'accepted_clips':[],'preserve_clips':[],'source_scale_by_image':source_scales,'source_scale_reason':'All source masters paint approximately 400px-wide original anatomy. Fixed .46 scale for every frame/master preserves existing approximately 190px-wide runtime body envelope; wing extension and grounded collapse remain genuine anatomical changes. Pixel-exact source-component crops, no per-pose normalization.','visual_review':{'status':'pending','notes':'Eight real wingbeat, ram, bell broadside, support, idle and collapse poses; four recoil and four folded-wing guard. Original attack/ranged v1 rejected for overlapping cells; roomier v2 replaces those. Some far-side bells occluded behind folded wings/stalks.'}}
(D/'handoff.json').write_text(json.dumps({'schema_version':1,'units':[u]},indent=2)+'\n')
for clip,c in clips.items():
 if clip=='dead':continue
 canvas=Image.new('RGBA',(1200,520),(35,42,35,255));dr=ImageDraw.Draw(canvas)
 for j,k in enumerate(c['indices']):
  f=frames[k];img=Image.open(R/f['source']);img=img.resize((round(img.width*f['scale']),round(img.height*f['scale'])));ax,ay=[round(v*f['scale']) for v in f['anchor']];canvas.alpha_composite(img,((j%4)*300+175-ax,(j//4)*260+230-ay));dr.text(((j%4)*300+8,(j//4)*260+8),str(j+1),fill='white')
 canvas.save(D/(clip+'_review.png'))
outputs={'move_v1':'exec-7ba91ee8-f99f-4b68-a562-15503ae683b0.png','attack_v1':'exec-19af1839-bf19-4a26-99b6-da9d3a7fab5a.png','ranged_v1':'exec-c3d29c4c-4775-48e8-b938-e05fa22455ee.png','ranged_v2':'exec-2e6173a1-53da-4f58-97c6-a83839c7a7cc.png','attack_v2':'exec-e76cd995-4faa-4510-b676-0770126566ef.png','reaction_v1':'exec-137c9563-5834-4fea-95f4-8ce90ffe3d52.png','death_v1':'exec-1d912f92-4a5e-4fd2-8d40-8ac2d9592894.png','cast_v1':'exec-c27275b7-8f6e-44fa-8dcb-87a251aae637.png','idle_v1':'exec-2f8688ff-83c1-43be-afda-1fe05095d12d.png'}
ref='art/units/source/curated/'+unit+'.png';prov=[]
for stem,out in outputs.items():
 p=D/(stem+'.prompt.txt'); raw=p.read_bytes().decode('utf-8-sig').strip();p.write_bytes(raw.encode('utf-8'))
 prov.append({'source':stem+'.png','source_sha256':hashlib.sha256((D/(stem+'.png')).read_bytes()).hexdigest(),'prompt_file':p.name,'prompt_sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'tool':'image_gen.imagegen','generation_output':'C:/Users/acorp/.codex/generated_images/01a0ccd1-f6ce-7f42-b36a-45bac5e6eca7/'+out,'references':[ref],'reference_sha256':hashlib.sha256((R/ref).read_bytes()).hexdigest(),'status':'rejected_source_overlap' if stem in ('attack_v1','ranged_v1') else 'pending_visual_review'})
(D/'provenance.json').write_text(json.dumps({'schema_version':1,'unit_id':unit,'generations':prov},indent=2)+'\n');print(len(frames),'new frames pending')
