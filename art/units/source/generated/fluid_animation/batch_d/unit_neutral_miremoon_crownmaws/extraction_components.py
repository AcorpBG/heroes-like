"""Inspect connected alpha components; original source pixels stay untouched."""
from PIL import Image
from collections import deque
from pathlib import Path
import sys

def components(path):
    im=Image.open(path).convert('RGBA');w,h=im.size
    mask=bytearray(1 if a>8 else 0 for a in im.getchannel('A').tobytes())
    parts=[]
    for start in range(w*h):
        if not mask[start]:continue
        mask[start]=0;q=deque([start]);rows={};area=0
        while q:
            k=q.popleft();y,x=divmod(k,w);area+=1
            if y not in rows:rows[y]=[x,x+1]
            else:rows[y][0]=min(rows[y][0],x);rows[y][1]=max(rows[y][1],x+1)
            for dy,dx in ((0,-1),(0,1),(-1,0),(1,0),(-1,-1),(-1,1),(1,-1),(1,1)):
                xx,yy=x+dx,y+dy
                if 0<=xx<w and 0<=yy<h:
                    n=yy*w+xx
                    if mask[n]:mask[n]=0;q.append(n)
        if area>1000:
            ys=sorted(rows);bounds=[min(v[0] for v in rows.values()),ys[0],max(v[1] for v in rows.values()),ys[-1]+1]
            parts.append({'area':area,'bounds':bounds,'rows':rows})
    return sorted(parts,key=lambda p:(p['bounds'][1]//(h//2),p['bounds'][0]))

if __name__=='__main__':
    for path in sys.argv[1:]:
        parts=components(path);print(Path(path).name,[(p['area'],p['bounds']) for p in parts])
