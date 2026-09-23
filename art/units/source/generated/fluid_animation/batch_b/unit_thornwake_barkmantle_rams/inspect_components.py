from pathlib import Path
from PIL import Image
import numpy as np
p=Path('art/units/source/generated/fluid_animation/batch_b/unit_thornwake_barkmantle_rams')
for name in ['attack_v1','hit_defend_v1','death_v1','cast_v1']:
 im=Image.open(p/(name+'.png')); a=np.asarray(im)[:,:,3]>8
 # Connected horizontal runs, joining adjacent rows.
 parent=[]; boxes=[]; counts=[]; prev=[]
 def root(i):
  while parent[i]!=i: parent[i]=parent[parent[i]]; i=parent[i]
  return i
 for y,row in enumerate(a):
  d=np.diff(np.r_[False,row,False].astype('int8')); starts=np.where(d==1)[0]; ends=np.where(d==-1)[0]; cur=[]
  for l,r in zip(starts,ends):
   overlaps=[root(i) for pl,pr,i in prev if pl<=r and pr>=l]
   if overlaps:
    i=overlaps[0]
    for j in overlaps[1:]:
     j=root(j); i=root(i)
     if j!=i:
      parent[j]=i; b=boxes[j]; z=boxes[i]; boxes[i]=[min(z[0],b[0]),min(z[1],b[1]),max(z[2],b[2]),max(z[3],b[3])]; counts[i]+=counts[j];counts[j]=0
    b=boxes[i];boxes[i]=[min(b[0],int(l)),min(b[1],y),max(b[2],int(r)),y+1];counts[i]+=int(r-l)
   else:
    i=len(parent);parent.append(i);boxes.append([int(l),y,int(r),y+1]);counts.append(int(r-l))
   cur.append((l,r,i))
  prev=cur
 found=[(boxes[i],counts[i]) for i in range(len(parent)) if root(i)==i and counts[i]>1000]
 print(name,im.size,found)

