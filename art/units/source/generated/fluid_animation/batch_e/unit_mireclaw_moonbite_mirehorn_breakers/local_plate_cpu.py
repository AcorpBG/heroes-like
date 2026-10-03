"""CPU recovery from immutable pinned semantic mask cache and original RGB."""
import json,hashlib,time
from pathlib import Path
import av,numpy as np
from PIL import Image
from scipy.ndimage import minimum_filter,maximum_filter,distance_transform_edt,label
import produce as p

def extract(rgb,alpha_raw):
 a=np.asarray(rgb).astype(np.float32);h,w=a.shape[:2];assert alpha_raw.shape==(h,w)
 alpha=alpha_raw.copy();assert np.isfinite(alpha).all() and alpha.min()>=0 and alpha.max()<=1
 lo=minimum_filter(a,size=(3,3,1),mode='nearest');hi=maximum_filter(a,size=(3,3,1),mode='nearest')
 uniform=np.linalg.norm(hi-lo,axis=2)<10
 clear=(maximum_filter(alpha,size=3,mode='nearest')<8/255)&uniform
 clear_labels,count=label(clear,structure=np.ones((3,3),dtype=np.uint8))
 border=np.unique(np.concatenate([clear_labels[0],clear_labels[-1],clear_labels[:,0],clear_labels[:,-1]]))
 retain=np.zeros(count+1,dtype=bool);retain[border]=True;retain[0]=False;clear=retain[clear_labels]
 # A local recovery needs an actual qualifying sample, not an arbitrary
 # fraction of the whole canvas. Each recovered pixel separately proves its
 # sample distance and local color reliability; distant RGB stays original.
 assert clear.any(),'No reliable border-connected plate sample'
 distance,positions=distance_transform_edt(~clear,return_indices=True)
 bg=a[positions[0],positions[1]];variation=np.linalg.norm(hi-lo,axis=2)[positions[0],positions[1]]
 alpha[alpha>=.98]=1;soft=(alpha>=8/255)&(alpha<1);edge=soft&(distance<=8)
 assert np.all(variation[edge]<10)
 color=a.copy();unmixed=np.clip((a-(1-alpha[:,:,None])*bg)/np.maximum(alpha[:,:,None],.001),0,255);color[edge]=unmixed[edge]
 out=np.dstack([color,alpha*255]).astype('uint8');out[out[:,:,3]<8]=0
 labels,n=label(out[:,:,3]>=8,structure=np.ones((3,3),dtype=np.uint8))
 solid=np.unique(labels[out[:,:,3]>=128]);keep=np.zeros(n+1,dtype=bool);keep[solid]=True;keep[0]=False;out[~keep[labels]]=0
 interior=(~edge)&(out[:,:,3]>=8);assert np.array_equal(out[:,:,:3][interior],a.astype('uint8')[interior])
 return Image.fromarray(out),dict(mode='cached_original_semantic_alpha_observed_local_boundary_plate',clear_semantic_threshold=8/255,clear_neighborhood=3,clear_must_be_locally_uniform_and_border_connected=True,clear_pixels=int(clear.sum()),unmixed_boundary_pixels=int(edge.sum()),nearest_boundary_clear_distance_max=float(distance[edge].max()) if edge.any() else 0,clear_sample_rgb_variation_max=float(variation[edge].max()) if edge.any() else 0,background_rgb=np.median(a[clear],axis=0).tolist(),opaque_and_nonboundary_original_rgb_preserved=True)

if __name__=='__main__':
 out=p.SOURCE_DIR/'defend_h3_v2';rec=json.loads((out/'original.json').read_bytes());cache=json.loads((out/'semantic_mask_cache.json').read_bytes());assert cache['source_rgb_sha256']==rec['decoded_rgb_sha256']
 target=out/'matte_local_plate_cpu';assert not target.exists();target.mkdir()
 hashes=[];details=[];start=time.time()
 for i,f in enumerate(av.open(str(out/'original_lossless.mkv')).decode(video=0)):
  rgb=f.to_image().convert('RGB');assert hashlib.sha256(rgb.tobytes()).hexdigest()==rec['decoded_rgb_sha256'][i]
  record=cache['masks'][i];file=out/'semantic_mask_cache'/record['file'];assert p.sha(file)==record['sha256']
  im,detail=extract(rgb,np.load(file,allow_pickle=False));prior=out/'matte'/f'rgba_{i:03}.png'
  if prior.exists():assert Image.open(prior).getchannel('A').tobytes()==im.getchannel('A').tobytes(),'Alpha differs from retained strict NN'
  file=target/f'rgba_{i:03}.png';im.save(file);hashes.append(p.sha(file));details.append(detail)
  if i%24==0:print('CPU_ORIGINAL_MASK_PLATE_RECOVERY',i,flush=True)
 assert len(hashes)==124
 recipe=dict(frames=124,extracted_frames=124,fps=24,rgba_sha256=hashes,background_frames=details,recipe='Unchanged pinned1024/FP16 semantic float alpha cache and original RGB. Same opaque.98, alpha8 and solid128-connected component rules. All53 prior strict alpha bytes identical. Only soft boundaries within8px of an observed border-connected source background sample unmix colors; entire sample3x3 NNalpha<8/255 and RGBnorm variation<10. All opaque/nonboundary RGB remains original. No global key fit, alpha refinement, geometry, source coordinate, scale or motion changes. No arbitrary whole-canvas clear-area requirement: every recovered boundary sample proves local reliability. Full original/alpha/native visual review required.',model_manifest=cache['model_manifest'],inference_precision=cache['inference_precision'],torch_version=cache['torch_version'],gpu=cache['gpu'],semantic_mask_cache_sha256=p.sha(out/'semantic_mask_cache.json'),tool_sha256=p.sha(Path(__file__)),elapsed_seconds=round(time.time()-start,3))
 p.write(out/'matte_local_plate_cpu.json',recipe);print('CPU_COMPLETE124_ALPHA_EXACT53_REVIEW_PENDING',flush=True)
