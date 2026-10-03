"""Same pinned semantic alpha; soft colors unmix nearby observed clear RGB plate."""
import json,time,hashlib
from pathlib import Path
import av,numpy as np,torch
from PIL import Image
from scipy.ndimage import distance_transform_edt,label,minimum_filter,maximum_filter
import produce as p
import segment

def extract(net,rgb):
 a=np.asarray(rgb).astype(np.float32);h,w=a.shape[:2]
 image=rgb.resize((1024,1024),Image.Resampling.BICUBIC)
 tensor=torch.from_numpy(np.array(image)).permute(2,0,1).float().div(255)
 tensor=(tensor-torch.tensor([.485,.456,.406])[:,None,None])/torch.tensor([.229,.224,.225])[:,None,None]
 with torch.inference_mode():
  prediction=net(tensor[None].to('cuda',dtype=torch.float16))[-1].sigmoid().float()
  alpha=torch.nn.functional.interpolate(prediction,size=(h,w),mode='bilinear',align_corners=False)[0,0].cpu().numpy()
 # The clear sample and its entire3x3 neighborhood must be semantic background.
 clear=maximum_filter(alpha,size=3,mode='nearest')<1/255
 assert int(clear.sum())>h*w//3,'Insufficient semantic clear plate'
 distance,positions=distance_transform_edt(~clear,return_indices=True)
 bg=a[positions[0],positions[1]]
 lo=minimum_filter(a,size=(3,3,1),mode='nearest');hi=maximum_filter(a,size=(3,3,1),mode='nearest')
 variation=np.linalg.norm(hi-lo,axis=2)[positions[0],positions[1]]
 alpha_original=alpha.copy();alpha[alpha>=.98]=1
 soft=(alpha>=8/255)&(alpha<1)
 assert np.all(distance[soft]<48),'Soft foreground interior lacks nearby clear background'
 assert np.all(variation[soft]<10),'Nearest measured plate sample is locally nonuniform'
 color=np.clip((a-(1-alpha[:,:,None])*bg)/np.maximum(alpha[:,:,None],.001),0,255)
 out=np.dstack([color,alpha*255]).astype('uint8');out[out[:,:,3]<8]=0
 labels,n=label(out[:,:,3]>=8,structure=np.ones((3,3),dtype=np.uint8))
 solid=np.unique(labels[out[:,:,3]>=128]);keep=np.zeros(n+1,dtype=bool);keep[solid]=True;keep[0]=False;out[~keep[labels]]=0
 opaque=(alpha_original>=.98)&keep[labels];assert np.array_equal(out[:,:,:3][opaque],a.astype('uint8')[opaque])
 return Image.fromarray(out),dict(mode='identical_birefnet_semantic_alpha_nearest_observed_clear_plate_unmix',clear_semantic_threshold=1/255,clear_neighborhood=3,clear_pixels=int(clear.sum()),soft_pixels=int(soft.sum()),nearest_clear_distance_max=float(distance[soft].max()),clear_sample_3x3_rgb_norm_variation_max=float(variation[soft].max()),opaque_original_rgb_preserved=True)

if __name__=='__main__':
 take='defend_h3_v2';out=p.SOURCE_DIR/take;rec=json.loads((out/'original.json').read_bytes());assert p.sha(out/'original_lossless.mkv')==rec['sha256']
 target=out/'matte_local_plate';assert not target.exists();target.mkdir()
 net=segment.model();hashes=[];details=[];start=time.time()
 try:
  for i,frame in enumerate(av.open(str(out/'original_lossless.mkv')).decode(video=0)):
   rgb=frame.to_image().convert('RGB');assert hashlib.sha256(rgb.tobytes()).hexdigest()==rec['decoded_rgb_sha256'][i]
   im,detail=extract(net,rgb);f=target/f'rgba_{i:03}.png'
   prior=out/'matte'/f'rgba_{i:03}.png'
   if prior.exists():assert Image.open(prior).getchannel('A').tobytes()==im.getchannel('A').tobytes(),'Semantic alpha differs from retained strict trial'
   im.save(f);hashes.append(p.sha(f));details.append(detail)
   if i%24==0:print('LOCAL_OBSERVED_PLATE_MATTED',take,i,flush=True)
  assert len(hashes)==124
  recipe=dict(frames=124,extracted_frames=124,fps=24,rgba_sha256=hashes,background_frames=details,recipe='Identical pinned BiRefNet1024 FP16 mask, resized to original RGB dimensions. Opaquealpha>=.98 retains exact source RGB. Only soft edge colors unmix nearest actual source background pixel whose entire3x3 mask neighborhood is below1/255. Every soft pixel requires clear sample distance<48px and3x3 RGB norm variation<10. No global uniform key assumption, spatial color fit, pose interpolation or geometry change. Same alpha8 cutoff and original solid-connected component rule as strict matte. Previous strict partial extraction preserved separately. Full visual review required.',model_manifest=json.loads((segment.BASE/'model_manifest.json').read_bytes()),inference_precision='float16',torch_version=torch.__version__,gpu=torch.cuda.get_device_name(),elapsed_seconds=round(time.time()-start,3),tool_sha256=p.sha(Path(__file__)))
  p.write(out/'matte_local_plate.json',recipe)
 finally:
  del net;torch.cuda.empty_cache()
 print('LOCAL_PLATE_TRIAL_COMPLETED_VISUAL_REVIEW_PENDING',take,len(hashes),flush=True)
