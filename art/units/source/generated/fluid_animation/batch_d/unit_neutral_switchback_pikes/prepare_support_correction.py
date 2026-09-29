"""Regenerate the complete support gesture on a separated bright plate."""
import json
import numpy as np
from PIL import Image
from scipy.ndimage import binary_erosion
import produce as p
from prepare import IDENTITY,TAKES

out=p.SOURCE_DIR/'cast_h3_v2'
out.mkdir(exist_ok=False)
c=json.loads((p.SOURCE_DIR/'cast_h3_v1/config.json').read_bytes())
c['seed']=2026092984
c['key_rgb']=[255,0,255]
c.pop('blue_chroma_axis',None)
c['guides']=[[12,0],[112,0]]
c['prompt']=(IDENTITY+TAKES['cast_h3_v1'][3]+
 ' Flat vivid saturated MAGENTA background, exactly the same brightness and '
 'color in every frame. The magenta fills all space around the actor, including '
 'the gaps between his arms, boots and pike. Even constant illumination. '
 'Locked orthographic camera, fixed body scale and planted boot contacts. '
 'Every part of the figure and both weapon ends stays inside the canvas.').strip()
p.prepare(out,c)
a=np.asarray(Image.open(out/'guide_0_rgba.png')).astype(float)
mask=binary_erosion(a[:,:,3]>240,iterations=3)
band=float((np.minimum(a[:,:,0],a[:,:,2])-a[:,:,1])[mask].max())
c['protected_foreground_chroma']=max(0,int(band)+2)
c['foreground_measurement']=dict(rule='Eroded original opaque min(red,blue)-green maximum plus two.',per_guide_max=[band])
p.write(out/'config.json',c)
p.write(out/'correction.json',dict(replaces='cast_h3_v1',
 defect='Blue plate fades to near-black throughout the actual gesture. Complete source reviewed; do not relax matte separation or erase dark costume.',
 change='Use original ready reference on a measured bright magenta plate; pin original ready at frames 12 and 112, preserve original body scale and gesture.'))
