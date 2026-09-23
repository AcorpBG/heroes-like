import json,hashlib
from pathlib import Path
from PIL import Image,ImageDraw
D=Path(__file__).parent;R=Path.cwd();unit=D.name
# Explicit source rectangles follow each painted body, not an assumed equal-row grid.
boxes={
'move':[[51,13,475,394],[533,21,985,394],[38,398,498,777],[529,402,1006,777],[55,778,494,1155],[549,781,980,1156],[62,1156,494,1536],[557,1157,1008,1536]],
'attack':[[69,1,439,397],[565,5,920,398],[54,377,443,796],[543,401,1000,796],[17,798,537,1137],[545,785,976,1137],[58,1137,468,1536],[545,1137,976,1536]],
'idle':[[90,5,479,393],[544,5,929,393],[89,388,486,779],[547,388,938,779],[91,767,487,1153],[547,765,938,1154],[95,1144,488,1536],[545,1142,944,1536]],
'reaction':[[87,6,468,383],[550,10,962,384],[75,380,482,770],[558,380,957,771],[75,766,482,1146],[569,767,949,1146],[76,1139,475,1536],[569,1139,959,1536]],
'cast':[[101,3,472,379],[571,4,935,379],[93,383,478,767],[568,383,956,767],[97,767,482,1150],[571,771,955,1150],[91,1151,473,1536],[574,1150,949,1536]],
'death':[[32,4,509,480],[516,31,987,496],[9,473,507,914],[490,570,1013,924],[7,1028,509,1214],[507,1057,1020,1216],[5,1352,506,1501],[510,1358,1016,1502]]}
scales={'move':.62,'idle':.62,'attack':.62,'reaction':.62,'cast':.62,'death':.53}
frames=[];clips={};srcscale={}
for master,bb in boxes.items():
 im=Image.open(D/(master+'_v1.png')).convert('RGBA')
 for i,(l,t,r,b) in enumerate(bb):
  crop=im.crop((l,t,r,b));w,h=crop.size;a=bytearray(crop.getchannel('A').point(lambda x:255 if x>8 else 0).tobytes());parts=[]
  for p in range(len(a)):
   if not a[p]:continue
   q=[p];a[p]=0;part=[]
   while q:
    k=q.pop();part.append(k);x=k%w;y=k//w
    for xx,yy in [(x-1,y),(x+1,y),(x,y-1),(x,y+1)]:
     if 0<=xx<w and 0<=yy<h:
      n=yy*w+xx
      if a[n]:a[n]=0;q.append(n)
   parts.append(part)
  keep=set(max(parts,key=len))
  # Cast light motes intentionally remain within its own source cell.
  if master=='cast':keep={n for part in parts for n in part}
  orig=crop.getchannel('A').tobytes();crop.putalpha(Image.frombytes('L',(w,h),bytes(v if n in keep else 0 for n,v in enumerate(orig))))
  fn=master+f'_v1_frame_{i}.png';crop.save(D/fn)
  clip=('hit' if i<4 else 'defend') if master=='reaction' else master; k=i%4 if master=='reaction' else i
  source=(D/fn).relative_to(R).as_posix();scale=scales[master];srcscale[source]=scale
  anchor=[(i%2)*512+310-l,h-12]
  if master=='death':anchor=[(i%2)*512+320-l,h-15]
  idx=len(frames);frames.append({'name':clip+f'_{k}','clip':clip,'source':source,'rects':[[0,0,w,h]],'anchor':anchor,'scale':scale,'alpha_noise_cutoff':8,'source_master':(D/(master+'_v1.png')).relative_to(R).as_posix(),'source_master_rect':[l,t,r,b]})
  clips.setdefault(clip,{'indices':[],'frame_msec':{'idle':140,'move':105,'attack':95,'hit':100,'defend':110,'cast':110,'death':130}[clip],'loop':clip in ('idle','move'),'static_frame':3 if clip=='defend' else 0})['indices'].append(idx)
clips['attack']['contact_frame']=4;clips['cast']['contact_frame']=4;clips['dead']={'indices':[clips['death']['indices'][-1]],'frame_msec':1000,'loop':False,'static_frame':0}
u={'unit_id':unit,'reference_height':256,'source_facing':'right','frames':frames,'clips':clips,'accepted_clips':[],'preserve_clips':[],'source_scale_by_image':srcscale,'source_scale_reason':'All 2x4 standing masters fixed .62 scale. Death master has a larger original standing body registration, fixed .53 for all its frames, preserving same anatomical size in collapse. Original pixel component cutout crops inherit master scale, no per-pose scaling or warping.','visual_review':{'status':'pending','notes':'Eight hover phases appropriate to floor-length robed spectral unit; original staff strike/cast/reaction/idle/death. No live catalogs changed.'}}
(D/'handoff.json').write_text(json.dumps({'schema_version':1,'units':[u]},indent=2)+'\n')
for clip,c in clips.items():
 if clip=='dead':continue
 canvas=Image.new('RGBA',(1200,600),(35,42,35,255));dr=ImageDraw.Draw(canvas)
 for j,k in enumerate(c['indices']):
  f=frames[k];img=Image.open(R/f['source']);img=img.resize((round(img.width*f['scale']),round(img.height*f['scale'])));ax,ay=[round(v*f['scale']) for v in f['anchor']];canvas.alpha_composite(img,((j%4)*300+175-ax,(j//4)*300+280-ay));dr.text(((j%4)*300+8,(j//4)*300+8),str(j+1),fill='white')
 canvas.save(D/(clip+'_review.png'))
outputs={'move':'exec-2e5f152e-515e-4ab7-92b6-d95607df5f99.png','attack':'exec-a56f1fa3-ad79-4b99-a864-6dc074a1b711.png','reaction':'exec-c77c88cb-5dba-4e0e-b921-24edea182965.png','death':'exec-8701f20d-c8d8-4a5b-b7ec-cebe4f4aaaca.png','cast':'exec-41d151cc-15a9-4f25-99b1-7a1fcb43f609.png','idle':'exec-62e5f93c-9b58-4159-982c-10743063a2de.png'}
ref='art/units/source/curated/'+unit+'.png';prov=[]
for stem,out in outputs.items():
 p=D/(stem+'_v1.prompt.txt');prov.append({'source':stem+'_v1.png','source_sha256':hashlib.sha256((D/(stem+'_v1.png')).read_bytes()).hexdigest(),'prompt_file':p.name,'prompt_sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'tool':'image_gen.imagegen','generation_output':'C:/Users/acorp/.codex/generated_images/01a0ccd1-f6ce-7f42-b36a-45bac5e6eca7/'+out,'references':[ref],'reference_sha256':hashlib.sha256((R/ref).read_bytes()).hexdigest(),'status':'pending_visual_review'})
(D/'provenance.json').write_text(json.dumps({'schema_version':1,'unit_id':unit,'generations':prov},indent=2)+'\n');print(len(frames),'new frames pending')
