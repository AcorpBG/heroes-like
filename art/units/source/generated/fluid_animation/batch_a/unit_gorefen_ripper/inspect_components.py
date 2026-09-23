from pathlib import Path
from PIL import Image
from collections import deque
import numpy as np

for p in Path(__file__).parent.glob('*.png'):
    im=Image.open(p).convert('RGBA'); a=np.asarray(im)[:,:,3]; mask=a>8
    h,w=mask.shape; seen=np.zeros_like(mask); components=[]
    for y,x in zip(*np.where(mask)):
        if seen[y,x]: continue
        q=deque([(int(x),int(y))]); seen[y,x]=True; pts=[]
        while q:
            xx,yy=q.popleft(); pts.append((xx,yy))
            for nx,ny in ((xx-1,yy),(xx+1,yy),(xx,yy-1),(xx,yy+1)):
                if 0<=nx<w and 0<=ny<h and mask[ny,nx] and not seen[ny,nx]:
                    seen[ny,nx]=True; q.append((nx,ny))
        if len(pts)>10000:
            xs,ys=zip(*pts); components.append((len(pts),[min(xs),min(ys),max(xs)+1,max(ys)+1]))
    print(p.name,im.size,components,flush=True)
