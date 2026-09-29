"""Reproduce measured mattes for the reviewed color-changing second takes."""
import json
import numpy as np
from PIL import Image
from scipy.ndimage import binary_erosion
import produce as p

def band(out,c,color):
 values=[]
 for i in range(len(c['references'])):
  a=np.asarray(Image.open(out/f'guide_{i}_rgba.png')).astype(float)
  mask=binary_erosion(a[:,:,3]>240,iterations=3)
  r,g,b=a[:,:,0],a[:,:,1],a[:,:,2]
  axis={(0,0,255):b-np.maximum(r,g),(0,255,0):g-np.maximum(r,b),
        (255,255,0):np.minimum(r,g)-b,(255,0,255):np.minimum(r,b)-g}[tuple(color)]
  values.append(float(axis[mask].max()))
 return max(0,int(max(values))+2),values

for name,ranges,extract in [
 ('hit_h3_v2',[(73,115,[0,255,0])],[[0,123]]),
 ('cast_h3_v2',[(20,29,[0,255,0]),(30,49,[255,255,0])],[[20,123]])]:
 out=p.SOURCE_DIR/name;c=json.loads((out/'config.json').read_bytes())
 protected,measured=band(out,c,c['key_rgb']);reviewed=[]
 for first,last,color in ranges:
  limit,values=band(out,c,color)
  reviewed.append(dict(start=first,end=last,key_rgb=color,protected_foreground_chroma=limit,measured_original_interiors=values))
 p.write(out/'extraction_settings.json',dict(protected_foreground_chroma=protected,
  foreground_measurement=measured,blue_chroma_axis='blue_minus_max_red_green',reviewed_key_ranges=reviewed,
  reason='Full original chronology reviewed. Background-only hue changes are uniform in these intervals; measure each axis on every original guide before unmixing. Retain opaque costume, hands, face and pike. No geometry editing. Support frames 0-19 are unused ready holds including a gradient transition.'))
 p.write(out/'extract_ranges.json',dict(inclusive_ranges=extract))
 print(name,protected,reviewed,flush=True)
 p.process(out,c);p.review(out,c)
