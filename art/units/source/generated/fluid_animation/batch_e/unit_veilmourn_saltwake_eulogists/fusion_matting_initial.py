"""Uniform-plate opacity recovery enclosed by original semantic foreground."""
import json,hashlib
from pathlib import Path
import numpy as np
from PIL import Image
from scipy.ndimage import binary_fill_holes
import produce as p

def fuse(rgb,semantic,c,bg):
 sem=np.asarray(semantic);sa=sem[:,:,3];closed=binary_fill_holes(sa>=128)
 try:
  key,detail=p.key(rgb,dict(c,protected_foreground_chroma=30));ka=np.asarray(key)[:,:,3]
  combined=np.maximum(sa,ka*closed);reason=None
 except ValueError as exc:combined=sa.copy();reason=str(exc)
 assert np.array_equal(combined[~closed],sa[~closed])
 alpha=combined.astype(float)/255;a=np.asarray(rgb).astype(float)
 color=np.clip((a-(1-alpha[:,:,None])*np.array(bg))/np.maximum(alpha[:,:,None],.001),0,255)
 result=np.dstack([color,combined]).astype('uint8');result[result[:,:,3]<8]=0
 return Image.fromarray(result),dict(recovered_pixels=int((combined>sa).sum()),unsafe_key_reason=reason,semantic_alpha_sha256=hashlib.sha256(sa.tobytes()).hexdigest(),combined_alpha_sha256=hashlib.sha256(combined.tobytes()).hexdigest(),outside_enclosed_support_alpha_exact=True)

if __name__=='__main__':
 import shutil
 out=p.SOURCE_DIR/'move_h3_v1';prior=json.loads((out/'matte.json').read_bytes());assert not (out/'fusion_matting.json').exists()
 p.write(out/'matte_semantic.json',prior)
 recovery=json.loads((out/'closed_recovery_probe.json').read_bytes());probe=json.loads((out/'closed_recovery_probe/matte.json').read_bytes())
 for i,sha in enumerate(probe['rgba_sha256']):
  src=out/'closed_recovery_probe/matte'/f'rgba_{i:03}.png';assert p.sha(src)==sha;shutil.copyfile(src,out/'matte'/src.name)
 prior['rgba_sha256']=probe['rgba_sha256'];prior['recipe']='Pinned semantic soft alpha with uniform original-RGB chroma opacity recovery only inside regions enclosed by semantic alpha>=128. Outside enclosed support alpha stays exact; original key preserves internal negative spaces. Protected band30; plate separation>=80 and corner spread<=10, else source phase excluded from selection. Palette-bound RGB despill, fixed canvas/anchor/scale. No painted anatomy, invented contours or interpolation.'
 p.write(out/'matte.json',prior);p.write(out/'fusion_matting.json',dict(rule=recovery['rule'],details=recovery['details'],tool_sha256=p.sha(Path(__file__)),original_semantic_recipe_sha256=p.sha(out/'matte_semantic.json'),excluded_source_frames=[d['source_frame'] for d in recovery['details'] if d['unsafe_key_reason']],rejected_alternatives='Unconstrained original chroma retains low-alpha plate checker noise; simple zero-alpha holes miss glass that already has faint semantic opacity. Use closed opaque semantic support intersected with original chroma only.'))
 p.review(out,json.loads((out/'config.json').read_bytes()))
 print('PROMOTED_REVIEWED_MOVE_SOURCE_RECOVERY')
