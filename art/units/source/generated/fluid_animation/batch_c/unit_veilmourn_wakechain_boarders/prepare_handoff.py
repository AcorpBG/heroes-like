import json, hashlib
from pathlib import Path
from PIL import Image, ImageDraw
D=Path(__file__).parent
R=Path.cwd()
UNIT='unit_veilmourn_wakechain_boarders'
outputs={'move_v1':'exec-0f67f3a8-a265-45e0-8ce2-7d71c6179810.png','attack_v1':'exec-7363216f-36da-43b6-8569-af464b686a7e.png','reaction_v1':'exec-1a22ee45-204b-45a5-b334-d3468271f1ad.png','death_v1':'exec-758d6a80-6f9c-448d-9853-a42de7ac6a38.png','cast_v1':'exec-99075798-5233-4520-b25a-972a42c44adb.png','move_keys_v1':'exec-b03f5614-6413-4231-ae04-74f0f663b46a.png','move_opposite_v1':'exec-0538def3-5101-4ffd-8811-7870803f06db.png','idle_v1':'exec-71ad037e-f62f-4101-918a-05ce31c23aad.png'}
ref='art/units/source/curated/'+UNIT+'.png'
prov=[]
for name,out in outputs.items():
 p=D/(name+'.prompt.txt'); raw=p.read_bytes().decode('utf-8-sig').strip(); p.write_bytes(raw.encode('utf-8'))
 prov.append({'source':name+'.png','source_sha256':hashlib.sha256((D/(name+'.png')).read_bytes()).hexdigest(),'prompt_file':p.name,'prompt_sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'tool':'image_gen.imagegen','generation_output':'C:/Users/acorp/.codex/generated_images/01a0ccd1-f6ce-7f42-b36a-45bac5e6eca7/'+out,'references':[ref],'reference_sha256':hashlib.sha256((R/ref).read_bytes()).hexdigest(),'status':'rejected_same_leading_leg' if name.startswith('move') else 'pending_visual_review'})
(D/'provenance.json').write_text(json.dumps({'schema_version':1,'unit_id':UNIT,'generations':prov},indent=2)+'\n')
frames=[]; clips={}
specs=[('idle','idle_v1',8,.60),('attack','attack_v1',8,.63),('hit','reaction_v1',4,.60),('defend','reaction_v1',4,.60),('death','death_v1',8,.55),('cast','cast_v1',8,.65)]
for clip,stem,n,scale in specs:
 im=Image.open(D/(stem+'.png')).convert('RGBA'); indices=[]; previews=[]
 for i in range(n):
  j=i+4 if clip=='defend' else i; row=j//2; col=j%2
  bands=[0,384,768,1152,1536]
  if clip=='death': bands=[0,460,860,1200,1536]
  rects=[[col*512,bands[row],(col+1)*512,bands[row+1]]]
  if clip=='attack' and j==2: rects.append([512,470,534,608])
  if clip=='attack' and j==4: rects.append([512,768,620,921])
  if clip=='attack' and j==5: rects=[[620,768,1024,1152],[512,921,620,1152]]
  tile=Image.new('RGBA',im.size)
  for r in rects: tile.alpha_composite(im.crop(r),(r[0],r[1]))
  a=tile.getchannel('A').point(lambda x:255 if x>8 else 0); bbox=a.getbbox()
  anchor=[col*512+280,bbox[3]-1]
  if clip=='death': anchor=[col*512+270,[432,822,1140,1450][row]]
  indices.append(len(frames)); frames.append({'name':f'{clip}_{i}','clip':clip,'source':(D/(stem+'.png')).relative_to(R).as_posix(),'rects':rects,'anchor':anchor,'scale':scale,'alpha_noise_cutoff':8})
  tile.putalpha(tile.getchannel('A').point(lambda x:0 if x<=8 else x))
  crop=tile.crop(bbox); crop.thumbnail((280,240))
  previews.append(crop)
 durations={'idle':130,'attack':95,'hit':95,'defend':105,'death':120,'cast':100}
 clips[clip]={'indices':indices,'frame_msec':durations[clip],'loop':clip=='idle','static_frame':n-1 if clip in ('death','defend') else 0}
 if clip=='attack': clips[clip]['contact_frame']=4
 canvas=Image.new('RGBA',(1200,560),(35,42,35,255)); dr=ImageDraw.Draw(canvas)
 for i,p in enumerate(previews):
  x=(i%4)*300+(300-p.width)//2; y=(i//4)*280+25
  canvas.alpha_composite(p,(x,y)); dr.text(((i%4)*300+8,(i//4)*280+8),str(i+1),fill='white')
 canvas.save(D/(clip+'_review.png'))
clips['dead']={'indices':[clips['death']['indices'][-1]],'frame_msec':1000,'loop':False,'static_frame':0}
hand={'schema_version':1,'units':[{'unit_id':UNIT,'reference_height':256,'source_facing':'right','frames':frames,'clips':clips,'accepted_clips':[],'preserve_clips':[],'visual_review':{'status':'pending','notes':'Candidate idle, melee attack, hit, defense, death and nonmagical support; movement pending true alternating leg gait. Source masters retain alpha; <=8 alpha noise cleanup only. Existing idle too slight for requested hand movement.'}}]}
(D/'handoff.json').write_text(json.dumps(hand,indent=2)+'\n')
print('Pending handoff:',len(frames),'drawn frames',list(clips))
