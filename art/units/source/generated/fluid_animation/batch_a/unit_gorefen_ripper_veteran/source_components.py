"""Isolate painted silhouettes using original source pixel rectangles only."""
from array import array
from collections import deque
from PIL import Image

def silhouettes(path,count=8):
 im=Image.open(path).convert('RGBA'); w,h=im.size
 ink=im.getchannel('A').point(lambda a:255 if a>8 else 0).tobytes()
 labels=array('i',[0])*(w*h); parts=[]
 for start in range(w*h):
  if not ink[start] or labels[start]:continue
  label=len(parts)+1; labels[start]=label; q=deque([start]); size=0; sx=sy=0
  l=w;t=h;r=b=0
  while q:
   pos=q.popleft(); y,x=divmod(pos,w);size+=1;sx+=x;sy+=y
   l=min(l,x);r=max(r,x+1);t=min(t,y);b=max(b,y+1)
   for np in ((pos-1 if x else -1),(pos+1 if x+1<w else -1),(pos-w if y else -1),(pos+w if y+1<h else -1)):
    if np>=0 and ink[np] and not labels[np]:labels[np]=label;q.append(np)
  parts.append(dict(label=label,size=size,cx=sx/size,cy=sy/size,bounds=[l,t,r,b]))
 major=sorted(parts,key=lambda p:p['size'],reverse=True)[:count]
 if len(major)!=count or min(p['size'] for p in major)<1000:raise ValueError('not enough complete silhouettes')
 # Order by visual rows. The source sheets have two columns except explicit4x2.
 cols=4 if w>1700 else 2
 major=sorted(major,key=lambda p:p['cy'])
 ordered=[]
 for row in range(count//cols):ordered+=sorted(major[row*cols:(row+1)*cols],key=lambda p:p['cx'])
 assign={p['label']:i for i,p in enumerate(ordered)}
 for p in parts:
  if p['label'] in assign:continue
  near=min(range(count),key=lambda i:(p['cx']-ordered[i]['cx'])**2+(p['cy']-ordered[i]['cy'])**2)
  assign[p['label']]=near
 rects=[[] for _ in range(count)]
 for y in range(h):
  x=0
  while x<w:
   label=labels[y*w+x]
   if not label:x+=1;continue
   group=assign[label];start=x;x+=1
   while x<w and labels[y*w+x] and assign[labels[y*w+x]]==group:x+=1
   rects[group].append([start,y,x,y+1])
 # Merge vertically identical scan runs into larger exact source rectangles.
 merged=[]
 for runs in rects:
  active={};out=[]
  for l,t,r,b in runs:
   key=(l,r)
   previous=active.get(key)
   if previous is not None and out[previous][3]==t:out[previous][3]=b
   else:active[key]=len(out);out.append([l,t,r,b])
  merged.append(out)
 return ordered,merged

if __name__=='__main__':
 from pathlib import Path
 for name in ['attack_v2.png','reactions_v1.png','cast_v1.png']:
  parts,rects=silhouettes(Path(__file__).parent/name)
  print(name,[(p['size'],p['bounds'],len(r)) for p,r in zip(parts,rects)])
