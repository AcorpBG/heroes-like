"""Correct reviewed plate fringes using retained semantic alpha and original RGB."""
import argparse,json,time
from pathlib import Path
import av,numpy as np
from PIL import Image
from scipy.ndimage import label
import produce as p
from creature_animation_lock import exclusive
from segment import refine_plate_boundary

if __name__=='__main__':
 parser=argparse.ArgumentParser();parser.add_argument('take');args=parser.parse_args();out=p.SOURCE_DIR/args.take
 with exclusive('gpu'):
  q=p.request(p.URL,'/queue');assert not q.get('queue_running') and not q.get('queue_pending'),'Foreign Comfy queue active'
  initial=json.loads((out/'matte.json').read_bytes());assert initial['tool_sha256']==p.sha(p.SOURCE_DIR/'segment_initial.py')
  assert not (out/'selection.json').exists(),'Never replace an accepted selection'
  original=json.loads((out/'original.json').read_bytes());assert p.sha(out/'original_lossless.mkv')==original['sha256']
  for i,sha in enumerate(initial['rgba_sha256']):assert p.sha(out/'matte'/f'rgba_{i:03}.png')==sha
  for name in ['matte','matte.json','segmentation_recipe.json']:
   old=out/name;new=out/({'matte':'matte_semantic_initial','matte.json':'matte_semantic_initial.json','segmentation_recipe.json':'segmentation_recipe_initial.json'}[name])
   assert old.resolve().is_relative_to(p.SOURCE_DIR.resolve()) and new.resolve().is_relative_to(p.SOURCE_DIR.resolve()) and not new.exists()
   old.rename(new)
  (out/'matte').mkdir();hashes=[];details=[];started=time.time()
  with av.open(str(out/'original_lossless.mkv')) as video:
   for i,frame in enumerate(video.decode(video=0)):
    rgb=frame.to_image().convert('RGB');assert p.hashlib.sha256(rgb.tobytes()).hexdigest()==original['decoded_rgb_sha256'][i]
    a=np.asarray(rgb).astype(np.float32);old=np.asarray(Image.open(out/'matte_semantic_initial'/f'rgba_{i:03}.png').convert('RGBA'))
    bg=np.array(initial['background_frames'][i]['background_rgb'],dtype=np.float32)
    alpha,edge=refine_plate_boundary(a,old[:,:,3].astype(np.float32)/255,bg)
    color=np.clip((a-(1-alpha[:,:,None])*bg)/np.maximum(alpha[:,:,None],.001),0,255)
    rgba=np.dstack([color,alpha*255]).astype('uint8');rgba[rgba[:,:,3]<8]=0
    labels,n=label(rgba[:,:,3]>=8,structure=np.ones((3,3),dtype=np.uint8));solid=np.unique(labels[rgba[:,:,3]>=128]);keep=np.zeros(n+1,dtype=bool);keep[solid]=True;keep[0]=False;rgba[~keep[labels]]=0
    opaque=rgba[:,:,3]==255;assert np.array_equal(rgba[:,:,:3][opaque],np.asarray(rgb)[opaque]),'Opaque original RGB changed'
    path=out/'matte'/f'rgba_{i:03}.png';Image.fromarray(rgba,'RGBA').save(path);hashes.append(p.sha(path))
    details.append(dict(initial['background_frames'][i],edge_plate_refinement=edge))
  assert len(hashes)==124
  parent=dict(path=(out/'matte_semantic_initial.json').relative_to(p.ROOT).as_posix(),sha256=p.sha(out/'matte_semantic_initial.json'))
  recipe='Canonical retained eight-bit BiRefNet semantic alpha with measured magenta/green/blue plate mixture refinement only within two source pixels of its opaque contour. Protected chroma32/16/32; all opaque output RGB stays at original coordinates. Uniform corner-spread assertion unchanged. No pose/image warp, painting or interpolation.'
  p.write(out/'matte.json',dict(initial,rgba_sha256=hashes,background_frames=details,recipe=recipe,parent_recipe=parent,initial_semantic_tool_sha256=initial['tool_sha256'],tool_sha256=p.sha(Path(__file__)),elapsed_seconds=round(time.time()-started,3)))
  p.write(out/'segmentation_recipe.json',dict(recipe=recipe,parent_recipe=parent,model_manifest=initial['model_manifest'],tool_sha256=p.sha(Path(__file__)),canonical_future_segment_tool_sha256=p.sha(p.SOURCE_DIR/'segment.py')))
  guide=out/'guide_0_rgba.png';a=np.asarray(Image.open(guide).convert('RGBA')).astype(float);opaque=a[:,:,3]>=250
  measured=dict(magenta_max=float((np.minimum(a[:,:,0],a[:,:,2])-a[:,:,1])[opaque].max()),green_max=float((a[:,:,1]-np.maximum(a[:,:,0],a[:,:,2]))[opaque].max()))
  assert measured['magenta_max']<=32 and measured['green_max']<=16
  p.write(p.SOURCE_DIR/'foreground_measurement.json',dict(reference=dict(path=guide.relative_to(p.ROOT).as_posix(),sha256=p.sha(guide)),opaque_alpha_min=250,observed_chroma=measured,protected_chroma=dict(magenta=32,green=16,blue=32),boundary_source_pixels=2,review='Full124 semantic mattes and enlarged8 leg/grip poses exposed plate-colored soft fringes. Original ready wardrobe has no saturated magenta/green material; boundary-only mixture correction preserves every opaque output RGB and all coordinates.'))
  p.review(out,json.loads((out/'config.json').read_bytes()));print('REFINED_124_ORIGINAL_BOUNDARIES',args.take,round(time.time()-started,3),flush=True)
