from PIL import Image
from pathlib import Path
from collections import deque
D=Path(__file__).parent
for fn in ['move_v1','attack_v2','ranged_v2','idle_v1','reaction_v1','cast_v1','death_v1']:
 im=Image.open(D/(fn+'.png')); w,h=im.size; a=bytearray(im.getchannel('A').point(lambda x:255 if x>8 else 0).tobytes()); comps=[]
 for p in range(len(a)):
  if not a[p]: continue
  q=[p]; a[p]=0; x0=x1=p%w; y0=y1=p//w; count=0
  while q:
   k=q.pop(); x=k%w;y=k//w; count+=1;x0=min(x0,x);x1=max(x1,x);y0=min(y0,y);y1=max(y1,y)
   for nx,ny in [(x-1,y),(x+1,y),(x,y-1),(x,y+1)]:
    if 0<=nx<w and 0<=ny<h:
     nk=ny*w+nx
     if a[nk]:a[nk]=0;q.append(nk)
  if count>180:comps.append([count,[x0,y0,x1+1,y1+1]])
 print(fn,comps)


