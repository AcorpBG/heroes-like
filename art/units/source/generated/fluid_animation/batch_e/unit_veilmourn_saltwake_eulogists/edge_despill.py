"""Measured plate-color decontamination; unchanged alpha and source geometry."""
import hashlib,json,argparse
from pathlib import Path
import numpy as np
from PIL import Image
from scipy.ndimage import distance_transform_edt
import produce as p

def clean(im,bg):
 a=np.asarray(im).copy();alpha=a[:,:,3].copy();rgb=a[:,:,:3].astype(float)
 edge=(alpha>=8)
 r,g,b=[rgb[:,:,i] for i in range(3)]
 mag=min(bg[0],bg[2])-bg[1];green=bg[1]-max(bg[0],bg[2]);mode='none'
 if mag>80:
  spill=np.maximum(np.minimum(r,b)-g-30,0)*edge;rgb[:,:,0]-=spill;rgb[:,:,2]-=spill;mode='magenta'
 elif green>80:
  spill=np.maximum(g-np.maximum(r,b)-30,0)*edge;rgb[:,:,1]-=spill;mode='green'
 else:spill=np.zeros(alpha.shape)
 a[:,:,:3]=np.clip(rgb,0,255).astype('uint8');assert np.array_equal(a[:,:,3],alpha)
 return Image.fromarray(a),dict(plate_mode=mode,protected_chroma_band=30,boundary_source_pixels=None,scope="measured_original_palette_plate_axis_only",changed_rgb_pixels=int((spill>0).sum()),alpha_sha256=hashlib.sha256(alpha.tobytes()).hexdigest())

if __name__=='__main__':
 a=argparse.ArgumentParser();a.add_argument('takes',nargs='+');args=a.parse_args()
 for name in args.takes:
  out=p.SOURCE_DIR/name;rec=json.loads((out/'matte.json').read_bytes());
  if (out/'edge_despill.json').exists():p.write(out/('edge_despill_boundary.json' if (out/'edge_despill_v1.json').exists() else 'edge_despill_v1.json'),json.loads((out/'edge_despill.json').read_bytes()))
  else:p.write(out/'matte_initial.json',rec)
  details=[]
  for i,bg in enumerate(rec['background_frames']):
   f=out/'matte'/f'rgba_{i:03}.png';assert p.sha(f)==rec['rgba_sha256'][i]
   im,detail=clean(Image.open(f).convert('RGBA'),bg['background_rgb']);im.save(f);rec['rgba_sha256'][i]=p.sha(f);details.append(detail)
  rec['recipe']='Pinned BiRefNet-matting soft alpha inferred at1024 and resized to unchanged original RGB canvas; initial plate-unmix and alpha>=8 component rules recorded in matte_initial.json. Final measured plate-color decontamination removes only magenta/green plate-channel excess above protected original palette band30 from alpha>=8 foreground; original curated maximum14 and ready magenta maximum24 stay protected. Every alpha byte, coordinate, scale and motion phase remains unchanged; FFV1 RGB originals are untouched. No anatomy painting or synthesis.'
  p.write(out/'matte.json',rec);p.write(out/'edge_despill.json',dict(details=details,tool_sha256=p.sha(Path(__file__)),foreground_measurement_sha256=p.sha(p.SOURCE_DIR/'foreground_measurement.json'),initial_recipe_sha256=p.sha(out/'matte_initial.json'),recipe=rec['recipe']))
  p.review(out,json.loads((out/'config.json').read_bytes()));print('EDGE_DESPILLED',name,sum(x['changed_rgb_pixels'] for x in details))
