from pathlib import Path
from PIL import Image,ImageDraw
import json
D=Path(__file__).parent;R=Path.cwd();p=D/'cast_v1_frame_2.png';im=Image.open(p);w,h=im.size;a=bytearray(im.getchannel('A').point(lambda x:255 if x>8 else 0).tobytes());parts=[]
for k in range(len(a)):
 if not a[k]:continue
 q=[k];a[k]=0;part=[]
 while q:
  n=q.pop();part.append(n);x=n%w;y=n//w
  for xx,yy in [(x-1,y),(x+1,y),(x,y-1),(x,y+1)]:
   if 0<=xx<w and 0<=yy<h:
    nn=yy*w+xx
    if a[nn]:a[nn]=0;q.append(nn)
 parts.append(part)
body=max(parts,key=len);keep=set(body);src=im.getchannel('A').tobytes();im.putalpha(Image.frombytes('L',(w,h),bytes(v if n in keep else 0 for n,v in enumerate(src))));im.save(p)
print('Removed unrelated component sizes',sorted([len(v) for v in parts if v is not body],reverse=True))
u=json.loads((D/'handoff.json').read_text())['units'][0];canvas=Image.new('RGBA',(1200,560),(35,42,35,255));dr=ImageDraw.Draw(canvas)
for j,k in enumerate(u['clips']['cast']['indices']):
 f=u['frames'][k];im=Image.open(R/f['source']);im=im.resize((round(im.width*f['scale']),round(im.height*f['scale'])));ax,ay=[round(v*f['scale']) for v in f['anchor']];canvas.alpha_composite(im,((j%4)*300+150-ax,(j//4)*280+265-ay));dr.text(((j%4)*300+8,(j//4)*280+8),str(j+1),fill='white')
canvas.save(D/'cast_review.png')

