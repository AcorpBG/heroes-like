"""Rejected matte experiment: source preserved to explain colored-fringe failure.
Run only to reproduce the rejected defense extraction, never to approve it.
"""
import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent.parent))
from produce import *

def key(rgb,c):
 a=np.asarray(rgb,dtype=np.float32)
 corner_tiles=[a[:24,:24],a[:24,-24:],a[-24:,:24],a[-24:,-24:]]
 corner_medians=np.array([np.median(tile.reshape(-1,3),axis=0) for tile in corner_tiles])
 bg=np.median(corner_medians,axis=0)
 spread=float(np.max(np.linalg.norm(corner_medians-bg,axis=1)))
 if spread>10:raise ValueError(f'unsafe spatially varying corner plate {bg}; median spread={spread:.2f}')
 adaptive=c.get('protected_chroma_by_axis')
 if adaptive:
  # Six primary/secondary chroma axes, calibrated against opaque original
  # guide pixels. A color-changing plate is usable only while uniform and
  # separated from every source foreground color by at least 80 units.
  def scores(v):
   r,g,b=[v[...,i] for i in range(3)]
   return np.stack([r-np.maximum(g,b),g-np.maximum(r,b),b-np.maximum(r,g),np.minimum(r,g)-b,np.minimum(g,b)-r,np.minimum(r,b)-g],axis=-1)
  score=scores(bg);axis=int(score.argmax());bgc=float(score[axis]);protected=float(adaptive[axis])
  if bgc-protected<80:raise ValueError(f'unsafe foreground/plate separation {bgc-protected:.2f}')
  chroma=scores(a)[...,axis];is_green=axis==1
 else:
  magenta=min(bg[0],bg[2])-bg[1]
  green=bg[1]-max(bg[0],bg[2]);is_green=green>magenta;bgc=green if is_green else magenta
  if bgc<80:raise ValueError(f'unsafe insufficiently separated chroma backdrop {bg}')
  chroma=a[:,:,1]-np.maximum(a[:,:,0],a[:,:,2]) if is_green else np.minimum(a[:,:,0],a[:,:,2])-a[:,:,1]
  protected=float(c.get('protected_foreground_chroma',0)) if is_green else 0
 alpha=np.clip((bgc-chroma)/(bgc-protected),0,1)
 alpha[np.linalg.norm(a-bg,axis=2)<12]=0
 color=np.clip((a-(1-alpha[:,:,None])*bg)/np.maximum(alpha[:,:,None],.001),0,255)
 if adaptive:
  # Remove residual plate chroma only on partially transparent edge pixels;
  # every confidently opaque source pixel retains its original RGB.
  channels=[(0,),(1,),(2,),(0,1),(1,2),(0,2)][axis]
  other=[i for i in range(3) if i not in channels]
  spill=np.maximum(np.min(color[:,:,channels],axis=2)-np.max(color[:,:,other],axis=2),0)*(alpha<.98)
  for channel in channels:color[:,:,channel]-=spill
  mode='calibrated_'+['red','green','blue','yellow','cyan','magenta'][axis]+'_chroma_unmix'
 else:
  if is_green:
   spill=np.maximum(color[:,:,1]-np.maximum(color[:,:,0],color[:,:,2]),0)*(alpha<.98);color[:,:,1]-=spill
  else:
   spill=np.maximum(np.minimum(color[:,:,0],color[:,:,2])-color[:,:,1],0)*(alpha<.98);color[:,:,0]-=spill;color[:,:,2]-=spill
  mode='flat_green_chroma_unmix' if is_green else 'flat_magenta_chroma_unmix'
 out=np.dstack([color,alpha*255]).astype('uint8');out[out[:,:,3]<8]=0
 # Retain every >8-alpha connected creature component that contains at least
 # one confidently opaque pixel. This removes disconnected plate noise while
 # keeping fine sling cords, hair, reeds and separate equipment edges attached
 # to their own solid pixels.
 mask=out[:,:,3]>=8; labels,n=label(mask,structure=np.ones((3,3),dtype=np.uint8))
 solid=np.unique(labels[out[:,:,3]>=128]); keep=np.zeros(n+1,dtype=bool);keep[solid]=True;keep[0]=False
 out[~keep[labels]]=0
 return Image.fromarray(out,'RGBA'),dict(background_rgb=[round(float(v),3) for v in bg],corner_median_spread=round(float(spread),3),mode=mode,component_rule='alpha>=8 components retained only when they contain alpha>=128 source pixels')


def process(out,c):
 c=dict(c)
 settings=out/'extraction_settings.json'
 if settings.exists():c.update(json.loads(settings.read_bytes()))
 (out/'matte').mkdir(exist_ok=True);hashes=[];details=[]
 intervals=json.loads((out/'extract_ranges.json').read_bytes())['inclusive_ranges'] if (out/'extract_ranges.json').exists() else [[0,123]]
 assert all(0<=a<=b<124 for a,b in intervals)
 with av.open(str(out/'original_lossless.mkv')) as video:
  for i,frame in enumerate(video.decode(video=0)):
   if not any(a<=i<=b for a,b in intervals):hashes.append(None);details.append(dict(excluded=True));continue
   im,detail=key(frame.to_image().convert('RGB'),c)
   expected='flat_green_chroma_unmix' if c.get('key_rgb')==[0,255,0] else 'flat_magenta_chroma_unmix'
   if not c.get('protected_chroma_by_axis') and detail['mode']!=expected:raise ValueError('Backdrop changed outside the reviewed guide palette; reject this interval')
   p=out/'matte'/f'rgba_{i:03}.png';im.save(p);hashes.append(sha(p));details.append(detail)
 assert len(hashes)==124
 write(out/'matte.json',dict(frames=124,fps=24,rgba_sha256=hashes,background_frames=details,protected_foreground_chroma=c.get('protected_foreground_chroma',0),protected_chroma_by_axis=c.get('protected_chroma_by_axis'),recipe='Measured uniform guide plate; corner spread<=10, chroma separation>=80; protected foreground chroma band, color-specific alpha unmix and edge-only despill; alpha>=8 regions retained when containing alpha>=128 pixels. Original geometry unchanged.'))


if __name__=='__main__':
 out=Path(__file__).resolve().parent
 process(out,json.loads((out/'config.json').read_bytes()))
