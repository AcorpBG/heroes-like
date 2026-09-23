from pathlib import Path
import json
from PIL import Image,ImageDraw
D=Path(__file__).parent; R=Path.cwd()
boxes={
'attack_v1':[[129,32,431,386],[592,26,952,388],[91,393,528,770],[572,431,973,767],[77,814,615,1112],[576,799,959,1120],[105,1129,439,1504],[615,1129,928,1506]],
'idle_v1':[[132,12,409,382],[625,11,910,382],[149,391,416,764],[626,387,910,765],[142,775,415,1150],[627,774,897,1150],[139,1161,408,1533],[613,1160,893,1533]],
'reaction_v1':[[146,34,449,380],[585,67,874,379],[131,394,469,762],[586,382,909,765],[148,766,464,1131],[582,777,900,1133],[156,1135,481,1492],[582,1133,900,1493]],
'cast_v1':[[207,11,458,366],[607,40,849,366],[207,391,457,745],[611,367,874,748],[202,720,479,1139],[600,774,863,1140],[205,1167,458,1508],[597,1151,869,1508]],
'death_v1':[[63,34,424,435],[562,101,919,423],[60,520,445,821],[526,569,1008,833],[17,910,505,1157],[515,982,1010,1165],[14,1290,505,1475],[519,1313,1011,1475]]}
# Derive alpha cutouts by exact connected-component ownership, no painting or warping.
# Restrict reaction guard rows at known transparent gutter because low alpha noise connects them.
for stem,bb in boxes.items():
 im=Image.open(D/(stem+'.png')).convert('RGBA'); w,h=im.size
 for i,(l,t,r,b) in enumerate(bb):
  crop=im.crop((l,t,r,b)); cw,ch=crop.size; alpha=bytearray(crop.getchannel('A').point(lambda x:255 if x>8 else 0).tobytes()); original=alpha[:]; parts=[]
  for p in range(len(alpha)):
   if not alpha[p]:continue
   q=[p];alpha[p]=0;pixels=[]
   while q:
    k=q.pop();pixels.append(k);x=k%cw;y=k//cw
    for nx,ny in [(x-1,y),(x+1,y),(x,y-1),(x,y+1)]:
     if 0<=nx<cw and 0<=ny<ch:
      nk=ny*cw+nx
      if alpha[nk]:alpha[nk]=0;q.append(nk)
   parts.append(pixels)
  body=max(parts,key=len); keep=bytearray(cw*ch)
  for p in body:keep[p]=255
  # Small disconnected fragments lying in this cell belong to the cutout unless another sprite intrudes.
  if stem!='attack_v1' and not (stem=='cast_v1' and i in (2,4)):
   for part in parts:
    for p in part:keep[p]=255
  srca=crop.getchannel('A').tobytes(); crop.putalpha(Image.frombytes('L',(cw,ch),bytes(v if keep[n] else 0 for n,v in enumerate(srca))))
  crop.save(D/f'{stem}_frame_{i}.png')
hand=json.loads((D/'handoff.json').read_text()); u=hand['units'][0]
for f in u['frames']:
 if f['clip']=='move': continue
 stem=Path(f['source']).stem; idx=int(f['name'].rsplit('_',1)[1]); idx+=4 if f['clip']=='defend' else 0
 l,t,r,b=boxes[stem][idx]; fn=f'{stem}_frame_{idx}.png'; f['source']=(D/fn).relative_to(R).as_posix(); f['rects']=[[0,0,r-l,b-t]]
 original_x=(idx%2)*512+(330 if stem=='cast_v1' else 280)
 f['anchor']=[original_x-l,b-t-1]
 if stem=='death_v1': f['anchor']=[(idx%2)*512+270-l,b-t-12]
 f['source_master']=(D/(stem+'.png')).relative_to(R).as_posix(); f['source_master_rect']=[l,t,r,b]
(D/'handoff.json').write_text(json.dumps(hand,indent=2)+'\n')
for clip, spec in u['clips'].items():
 if clip in ('dead','move'):continue
 canvas=Image.new('RGBA',(1200,560),(35,42,35,255)); dr=ImageDraw.Draw(canvas)
 for j,k in enumerate(spec['indices']):
  f=u['frames'][k]; im=Image.open(R/f['source']); im=im.resize((round(im.width*f['scale']),round(im.height*f['scale'])))
  ax,ay=[round(v*f['scale']) for v in f['anchor']];x=(j%4)*300+150-ax;y=(j//4)*280+265-ay
  canvas.alpha_composite(im,(x,y));dr.text(((j%4)*300+8,(j//4)*280+8),str(j+1),fill='white')
 canvas.save(D/(clip+'_review.png'))
print('Derived original-pixel crops and calibrated contact sheets ready')

