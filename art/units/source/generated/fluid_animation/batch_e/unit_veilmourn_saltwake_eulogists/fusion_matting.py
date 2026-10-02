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
 import argparse,av
 from edge_despill import clean
 a=argparse.ArgumentParser();a.add_argument('take');a.add_argument('--rebuild',action='store_true');args=a.parse_args()
 out=p.SOURCE_DIR/args.take;original=json.loads((out/'original.json').read_bytes());alpha_record=json.loads((out/'semantic_alpha.json').read_bytes());matte=json.loads((out/'matte.json').read_bytes());c=json.loads((out/'config.json').read_bytes())
 assert p.sha(out/'original_lossless.mkv')==original['sha256'];verified=0
 with av.open(str(out/'original_lossless.mkv')) as video:
  for i,frame in enumerate(video.decode(video=0)):
   rgb=frame.to_image().convert('RGB');assert hashlib.sha256(rgb.tobytes()).hexdigest()==original['decoded_rgb_sha256'][i]
   record=alpha_record['frames'][i];f=out/'semantic_alpha'/f'alpha_{i:03}.png';assert p.sha(f)==record['file_sha256']
   alpha=Image.open(f).convert('L');assert hashlib.sha256(alpha.tobytes()).hexdigest()==record['original_alpha_sha256']
   semantic=Image.new('RGBA',rgb.size);semantic.putalpha(alpha)
   im,detail=fuse(rgb,semantic,c,matte['background_frames'][i]['background_rgb']);im,edge=clean(im,matte['background_frames'][i]['background_rgb'])
   final=out/'matte'/f'rgba_{i:03}.png'
   if final.exists():
    assert p.sha(final)==matte['rgba_sha256'][i];assert Image.open(final).convert('RGBA').tobytes()==im.tobytes();verified+=1
   if args.rebuild:
    final.parent.mkdir(exist_ok=True);im.save(final);assert p.sha(final)==matte['rgba_sha256'][i]
 assert verified;print('EXACT_CPU_FUSION_REBUILD',args.take,verified,'existing source RGBA frames')
