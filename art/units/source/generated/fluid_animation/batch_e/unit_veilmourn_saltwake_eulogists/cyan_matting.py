"""Source-color matte for a cyan plate separated on the green-minus-red axis."""
import json,hashlib,argparse,av
from pathlib import Path
import numpy as np
from PIL import Image
from scipy.ndimage import label,binary_fill_holes
import produce as p
from edge_despill import clean
def derive(rgb,semantic,bg,c):
 a=np.asarray(rgb).astype(float);bg=np.asarray(bg);protected=120
 if bg[1]>bg[2]+25 and bg[1]-bg[0]-protected>=80:
  corners=[a[:24,:24],a[:24,-24:],a[-24:,:24],a[-24:,-24:]];med=np.array([np.median(x.reshape(-1,3),axis=0) for x in corners]);assert np.linalg.norm(med-bg,axis=1).max()<=10,'Nonuniform cyan plate'
  alpha=np.clip(((bg[1]-bg[0])-(a[:,:,1]-a[:,:,0]))/(bg[1]-bg[0]-protected),0,1);alpha[np.linalg.norm(a-bg,axis=2)<12]=0
  k=(alpha*255).astype('uint8');k[k<8]=0;labels,n=label(k>=8,structure=np.ones((3,3),dtype='uint8'));solid=np.unique(labels[k>=128]);keep=np.zeros(n+1,dtype=bool);keep[solid]=True;keep[0]=False;k[~keep[labels]]=0;mode='measured_green_minus_red'
 else:
  try:k=np.asarray(p.key(rgb,dict(c,protected_foreground_chroma=30))[0])[:,:,3];mode='measured_magenta_or_green'
  except ValueError:k=np.asarray(semantic)[:,:,3];mode='unsafe_plate_semantic_only'
 sa=np.asarray(semantic)[:,:,3];closed=binary_fill_holes(sa>=8)
 combined=np.maximum(sa,k*closed) if mode=='measured_green_minus_red' else np.maximum(sa,k);opacity=combined.astype(float)/255
 color=np.clip((a-(1-opacity[:,:,None])*bg)/np.maximum(opacity[:,:,None],.001),0,255);out=np.dstack([color,combined]).astype('uint8');out[out[:,:,3]<8]=0
 if mode=='measured_green_minus_red':
  # The original curated alpha>=128 palette has G-R<=112. Remove only
  # excess cyan plate color above the protected120 band; alpha is untouched.
  colors=out[:,:,:3].astype(int);spill=np.maximum(np.minimum(colors[:,:,1],colors[:,:,2])-colors[:,:,0]-protected,0)*(combined>=8)
  colors[:,:,1]-=spill;colors[:,:,2]-=spill;out[:,:,:3]=np.clip(colors,0,255).astype('uint8')
  # Blue glass is protected because its blue channel dominates. The plate's
  # additional green excess is absent from original foreground (band30).
  colors=out[:,:,:3].astype(int);green=np.maximum(colors[:,:,1]-np.maximum(colors[:,:,0],colors[:,:,2])-30,0)*(combined>=8)
  colors[:,:,1]-=green;out[:,:,:3]=np.clip(colors,0,255).astype('uint8')
 im,_=clean(Image.fromarray(out),bg)
 if mode=='measured_green_minus_red':assert np.array_equal(combined[~closed],sa[~closed])
 return im,dict(mode=mode,protected_green_minus_red=protected,added_foreground_pixels=int(((combined>sa)&(combined>=128)).sum()),outside_original_semantic_pixels=int(((sa==0)&(combined>=128)).sum()),outside_enclosed_support_alpha_exact=bool(np.array_equal(combined[~closed],sa[~closed])))
if __name__=='__main__':
 a=argparse.ArgumentParser();a.add_argument('take');a.add_argument('--mode',choices=['probe','promote','verify','rebuild'],default='probe');args=a.parse_args();out=p.SOURCE_DIR/args.take;dest=out/'cyan_key_probe' if args.mode=='probe' else out
 if args.mode in ['probe','promote','rebuild']:(dest/'matte').mkdir(parents=True,exist_ok=True)
 original=json.loads((out/'original.json').read_bytes());prior=json.loads((out/'matte.json').read_bytes());c=json.loads((out/'config.json').read_bytes());hashes=[];details=[];alpha_records=json.loads((out/'semantic_alpha.json').read_bytes())['frames'];verified=0
 assert p.sha(out/'original_lossless.mkv')==original['sha256']
 if args.mode=='promote':
  assert not (out/'cyan_matting.json').exists(),'Already promoted'
  p.write(out/'matte_fusion_rejected.json',prior)
 if args.mode in ['verify','rebuild']:assert p.sha(Path(__file__))==json.loads((out/'cyan_matting.json').read_bytes())['tool_sha256']
 palette=np.asarray(Image.open(p.ROOT/'art/units/source/curated/unit_veilmourn_saltwake_eulogists.png').convert('RGBA'));assert (palette[:,:,1].astype(int)-palette[:,:,0].astype(int))[palette[:,:,3]>=128].max()==112
 with av.open(str(out/'original_lossless.mkv')) as video:
  for i,frame in enumerate(video.decode(video=0)):
   rgb=frame.to_image().convert('RGB');assert hashlib.sha256(rgb.tobytes()).hexdigest()==original['decoded_rgb_sha256'][i]
   af=out/'semantic_alpha'/f'alpha_{i:03}.png';assert p.sha(af)==alpha_records[i]['file_sha256'];alpha=Image.open(af).convert('L');assert hashlib.sha256(alpha.tobytes()).hexdigest()==alpha_records[i]['original_alpha_sha256']
   semantic=Image.new('RGBA',rgb.size);semantic.putalpha(alpha);im,detail=derive(rgb,semantic,prior['background_frames'][i]['background_rgb'],c)
   f=dest/'matte'/f'rgba_{i:03}.png'
   if args.mode in ['verify','rebuild'] and f.exists():assert p.sha(f)==prior['rgba_sha256'][i];assert Image.open(f).convert('RGBA').tobytes()==im.tobytes();verified+=1
   if args.mode in ['probe','promote','rebuild']:
    im.save(f)
    if args.mode=='rebuild':assert p.sha(f)==prior['rgba_sha256'][i]
   hashes.append(p.sha(f) if f.exists() else prior['rgba_sha256'][i]);details.append(dict(source_frame=i,**detail))
 recipe=dict(details=details,tool_sha256=p.sha(Path(__file__)),original_curated_alpha128_green_minus_red_max=112,protected_band=120,semantic_alpha_recipe_sha256=p.sha(out/'semantic_alpha.json'),original_lossless_sha256=p.sha(out/'original_lossless.mkv'),rule='Original RGB green-minus-red cyan key, protected curated palette band120, contained inside original soft semantic alpha>=8 enclosed silhouette. Every outside alpha byte exact. Original RGB unmix against uniform plate; remove excess cyan beyond120 and additional green beyond30 while protecting blue glass. No drawing, dilation, shape warp, source-coordinate changes or cross-frame synthesis.')
 if args.mode=='probe':p.write(dest/'matte.json',dict(rgba_sha256=hashes));p.write(out/'cyan_key_probe.json',recipe);p.review(dest,c)
 elif args.mode=='promote':prior['rgba_sha256']=hashes;prior['recipe']=recipe['rule'];p.write(out/'matte.json',prior);p.write(out/'cyan_matting.json',recipe);p.review(out,c)
 else:assert verified;print('EXACT_CPU_CYAN_REBUILD',args.take,verified)
 print('CYAN_SOURCE_KEY_'+args.mode.upper(),len(hashes))
