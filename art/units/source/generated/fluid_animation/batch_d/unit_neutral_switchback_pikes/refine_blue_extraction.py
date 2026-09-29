"""Measure guide colors before extracting a reviewed pure-blue plate.

The walking take uses its separately measured blue-minus-red settings because
its decoded background becomes cyan; rebuild that take with produce.py process.
"""
import json,sys
import numpy as np
from PIL import Image
from scipy.ndimage import binary_erosion
import produce as p

for name in sys.argv[1:]:
 out=p.SOURCE_DIR/name;c=json.loads((out/'config.json').read_bytes())
 assert c['key_rgb']==[0,0,255]
 bands=[]
 for i in range(len(c['references'])):
  a=np.asarray(Image.open(out/f'guide_{i}_rgba.png')).astype(float);mask=binary_erosion(a[:,:,3]>240,iterations=3)
  bands.append(float((a[:,:,2]-np.maximum(a[:,:,0],a[:,:,1]))[mask].max()))
 settings=dict(protected_foreground_chroma=max(0,int(max(bands))+2),blue_chroma_axis='blue_minus_max_red_green',foreground_measurement=bands,reason='Use only after original-frame review confirms a pure-blue plate. Blue minus max(red,green) separates that plate from the original costume without changing geometry or discarding opaque foreground colors. Original eroded interiors measured across all guides; edge-only unmix/despill.')
 p.write(out/'extraction_settings.json',settings)
 p.process(out,c);p.review(out,c)
 print('REFINED',name,settings['protected_foreground_chroma'],flush=True)
