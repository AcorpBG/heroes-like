"""Review-bounded extraction for the observed magenta/green death backdrop."""
import json
import numpy as np
from PIL import Image
from scipy.ndimage import binary_erosion
import produce as p

out=p.SOURCE_DIR/'death_h3_v1'
c=json.loads((out/'config.json').read_bytes())
bands=[]
for i in range(len(c['references'])):
 a=np.asarray(Image.open(out/f'guide_{i}_rgba.png')).astype(float);mask=binary_erosion(a[:,:,3]>240,iterations=3)
 bands.append(dict(magenta=float((np.minimum(a[:,:,0],a[:,:,2])-a[:,:,1])[mask].max()),green=float((a[:,:,1]-np.maximum(a[:,:,0],a[:,:,2]))[mask].max())))
protected=max(0,int(max(max(row.values()) for row in bands))+2)
ranges=[[12,24],[37,48],[61,72],[86,96],[109,120]]
p.write(out/'extraction_settings.json',dict(protected_foreground_chroma=protected,reviewed_key_ranges=[dict(start=a,end=b,key_rgb=[0,255,0]) for a,b in ranges],foreground_measurement=bands,reason='All124 original RGB frames reviewed; only the observed flat magenta and green intervals authorized. Measure both chroma axes on every original guide. Preserve original pixels, fixed scale and anchors; native alpha review still required.'))
p.process(out,c)
p.review(out,c)
print('Death extraction ready; protected foreground band',protected)
