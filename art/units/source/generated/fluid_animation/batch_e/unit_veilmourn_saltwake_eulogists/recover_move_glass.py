"""Source-backed chroma recovery inside closed semantic foreground holes."""
import json,hashlib
import av,numpy as np
from PIL import Image
from scipy.ndimage import binary_fill_holes
import produce as p
from edge_despill import clean
out=p.SOURCE_DIR/'move_h3_v1';c=json.loads((out/'config.json').read_bytes());c['protected_foreground_chroma']=30
prior=json.loads((out/'matte.json').read_bytes());record=json.loads((out/'original.json').read_bytes());dest=out/'closed_recovery_probe';(dest/'matte').mkdir(parents=True,exist_ok=True)
hashes=[];details=[]
with av.open(str(out/'original_lossless.mkv')) as video:
 for i,frame in enumerate(video.decode(video=0)):
  rgb=frame.to_image().convert('RGB');assert hashlib.sha256(rgb.tobytes()).hexdigest()==record['decoded_rgb_sha256'][i]
  sem=np.array(Image.open(out/'matte'/f'rgba_{i:03}.png').convert('RGBA'));sa=sem[:,:,3].copy();mask=sa>=8;closed=binary_fill_holes(sa>=128)
  try:
   key,keydetail=p.key(rgb,c);ka=np.array(key)[:,:,3];combined=np.maximum(sa,ka*closed);reason=None
  except ValueError as exc:combined=sa;reason=str(exc)
  a=np.array(rgb).astype(float);bg=np.array(prior['background_frames'][i]['background_rgb']);alpha=combined.astype(float)/255
  color=np.clip((a-(1-alpha[:,:,None])*bg)/np.maximum(alpha[:,:,None],.001),0,255)
  arr=np.dstack([color,combined]).astype('uint8');arr[arr[:,:,3]<8]=0;im,edge=clean(Image.fromarray(arr),bg)
  f=dest/'matte'/f'rgba_{i:03}.png';im.save(f);hashes.append(p.sha(f));details.append(dict(source_frame=i,recovered_pixels=int((combined>sa).sum()),unsafe_key_reason=reason))
p.write(dest/'matte.json',dict(rgba_sha256=hashes));p.write(out/'closed_recovery_probe.json',dict(details=details,rule='For uniformly separated plate only: Within closed regions enclosed by semantic alpha>=128, opacity is maximum(original RGB uniform-plate chroma alpha, semantic alpha). The original color key preserves transparent negative spaces. Outside the enclosed semantic support, every alpha byte remains exact. No dilation, hand-painted regions, invented color, contours or anatomy.'))
p.review(dest,c)
print('HOLE_RECOVERY',sum(d['recovered_pixels'] for d in details))


