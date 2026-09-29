"""Use a blue plate separated from the original teal/gold/cream palette."""
import json
import numpy as np
from PIL import Image
from scipy.ndimage import binary_erosion
import produce as p

for name,original in [('move_h3_v2',None),('defend_h3_v2',None),('cast_h3_v2','cast_h3_v1')]:
 out=p.SOURCE_DIR/name
 if original:
  out.mkdir(exist_ok=False)
  c=json.loads((p.SOURCE_DIR/original/'config.json').read_bytes());c['seed']=2026092963
 else:c=json.loads((out/'config.json').read_bytes())
 assert not (out/'submission.json').exists()
 c['key_rgb']=[0,0,255];c['blue_chroma_axis']='blue_minus_red'
 c['prompt']=c['prompt'].replace('MAGENTA','BLUE').replace('magenta','blue')
 c['prompt']+=' The background stays plain pure blue throughout the entire shot, without color cycling or darkening.'
 p.prepare(out,c)
 bands=[]
 for i in range(len(c['references'])):
  a=np.asarray(Image.open(out/f'guide_{i}_rgba.png')).astype(float);mask=binary_erosion(a[:,:,3]>240,iterations=3)
  bands.append(float((a[:,:,2]-a[:,:,0])[mask].max()))
 c['protected_foreground_chroma']=max(0,int(max(bands))+2)
 c['foreground_measurement']=dict(rule='Eroded opaque blue minus red foreground band plus two; protects teal costume.',per_guide_max=bands)
 p.write(out/'config.json',c)
p.write(p.SOURCE_DIR/'cast_h3_v1/rejection.json',dict(status='rejected',reason='Original backdrop cycles yellow/green/magenta and affects edge lighting. Yellow overlaps gold costume. Repeat with a blue plate measured against teal costume rather than silently changing thresholds.'))
p.write(p.SOURCE_DIR/'death_h3_v1_decode128/rejection.json',dict(status='decode_trial_not_selected',reason='The unchanged latent decoded with full temporal window still has the same background color cycle. The defect is not resolved by larger temporal tiles. Retain original decode; inspect measured alternate-color extraction or regenerate.'))
