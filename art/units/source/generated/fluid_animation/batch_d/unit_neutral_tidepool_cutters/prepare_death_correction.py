"""Replace the original collapse's changing plate without changing its guides."""
import json
import numpy as np
from PIL import Image
from scipy.ndimage import binary_erosion
import produce as p

out=p.SOURCE_DIR/'death_h3_v2';out.mkdir(exist_ok=False)
c=json.loads((p.SOURCE_DIR/'death_h3_v1/config.json').read_bytes())
c.update(seed=2026092964,key_rgb=[0,0,255],blue_chroma_axis='blue_minus_red')
c['prompt']=c['prompt'].replace('MAGENTA','BLUE')+' Keep the background pure blue from start to finish, with no color changes or illumination cast on the character.'
p.prepare(out,c)
bands=[]
for i in range(len(c['references'])):
 a=np.asarray(Image.open(out/f'guide_{i}_rgba.png')).astype(float);mask=binary_erosion(a[:,:,3]>240,iterations=3)
 bands.append(float((a[:,:,2]-a[:,:,0])[mask].max()))
c['protected_foreground_chroma']=max(0,int(max(bands))+2)
c['foreground_measurement']=dict(rule='Eroded opaque blue minus red maximum plus two.',per_guide_max=bands)
p.write(out/'config.json',c)
p.write(p.SOURCE_DIR/'death_h3_v1/rejection.json',dict(status='rejected',reason='Motion is coherent, but the alternate green backdrop introduces cyan outlines and translucent blocks around the moving figure. Enlarged14/21/26/36/50/55/59/61/65/72/82/123 and full chronology inspected. Do not mask these defects by raising alpha thresholds; regenerate on measured blue plate.'))
