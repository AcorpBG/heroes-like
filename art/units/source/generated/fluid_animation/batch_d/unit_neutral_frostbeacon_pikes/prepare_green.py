"""Replace unstable magenta plate using measured green-free original foreground."""
import json
import numpy as np
from PIL import Image
from scipy.ndimage import binary_erosion
import produce as p

def green_take(old,new):
 source=p.SOURCE_DIR/old;out=p.SOURCE_DIR/new
 c=json.loads((source/'config.json').read_bytes())
 assert not (out/'submission.json').exists(),'Submitted originals are immutable'
 colors=[]
 for i in range(len(c['references'])):
  a=np.asarray(Image.open(source/f'guide_{i}_rgba.png').convert('RGBA'),dtype=np.int16)
  mask=binary_erosion(a[:,:,3]>240,iterations=3)
  colors.append(int((a[:,:,1]-np.maximum(a[:,:,0],a[:,:,2]))[mask].max()))
 c['key_rgb']=[0,255,0];c['protected_foreground_chroma']=max(0,max(colors))
 c['prompt']=c['prompt'].replace('bright MAGENTA','bright GREEN')
 c['seed']+=100
 out.mkdir(exist_ok=True)
 p.write(out/'config.json',c);p.prepare(out,c)
 p.write(out/'plate_revision.json',dict(reason='Earlier magenta takes cycle background hue, overlapping foreground and preventing safe extraction.',
  source_take=old,opaque_interior_green_excess=colors,method='Original RGBA alpha>240 eroded three pixels; green-minus-max(red,blue) maximum, no per-frame color manipulation.'))
 print(new,c['protected_foreground_chroma'])

if __name__=='__main__':
 for old,new in [('move_h3_v1','move_h3_v2'),('attack_h3_v1','attack_h3_v2'),('defend_h3_v1','defend_h3_v1'),('cast_h3_v1','cast_h3_v1'),('death_h3_v1','death_h3_v1')]:green_take(old,new)
