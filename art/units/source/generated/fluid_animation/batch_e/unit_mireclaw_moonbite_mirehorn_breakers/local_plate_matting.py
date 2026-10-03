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
 lo=minimum_filter(a,size=(3,3,1),mode='nearest');hi=maximum_filter(a,size=(3,3,1),mode='nearest')
 uniform=np.linalg.norm(hi-lo,axis=2)<10
 clear=(maximum_filter(alpha,size=3,mode='nearest')<8/255)&uniform
 clear_labels,count=label(clear,structure=np.ones((3,3),dtype=np.uint8))
 border_labels=np.unique(np.concatenate([clear_labels[0],clear_labels[-1],clear_labels[:,0],clear_labels[:,-1]]))
 retain=np.zeros(count+1,dtype=bool);retain[border_labels]=True;retain[0]=False;clear=retain[clear_labels]
 assert int(clear.sum())>h*w//3,'Insufficient semantic clear plate'
 distance,positions=distance_transform_edt(~clear,return_indices=True)
 bg=a[positions[0],positions[1]]
 variation=np.linalg.norm(hi-lo,axis=2)[positions[0],positions[1]]
 alpha_original=alpha.copy();alpha[alpha>=.98]=1
 soft=(alpha>=8/255)&(alpha<1)
 # Soft neural confidence inside the subject is not proof of plate mixing.
 # Preserve those original RGB pixels. Only the actual near-background edge
 # can use a measured local plate, with unchanged reliability requirements.
 edge=soft&(distance<=8)
 assert np.all(variation[edge]<10),'Nearest measured edge plate is locally nonuniform'
 color=a.copy()
 unmixed=np.clip((a-(1-alpha[:,:,None])*bg)/np.maximum(alpha[:,:,None],.001),0,255)
 color[edge]=unmixed[edge]
 out=np.dstack([color,alpha*255]).astype('uint8');out[out[:,:,3]<8]=0
 labels,n=label(out[:,:,3]>=8,structure=np.ones((3,3),dtype=np.uint8))
 solid=np.unique(labels[out[:,:,3]>=128]);keep=np.zeros(n+1,dtype=bool);keep[solid]=True;keep[0]=False;out[~keep[labels]]=0
 opaque=(alpha_original>=.98)&keep[labels];assert np.array_equal(out[:,:,:3][opaque],a.astype('uint8')[opaque])
 interior=(~edge)&(out[:,:,3]>=8);assert np.array_equal(out[:,:,:3][interior],a.astype('uint8')[interior])
 return Image.fromarray(out),dict(mode='identical_birefnet_semantic_alpha_nearest_observed_clear_plate_boundary_only_unmix',clear_semantic_threshold=8/255,clear_neighborhood=3,clear_must_be_locally_uniform_and_connected_to_image_border=True,clear_pixels=int(clear.sum()),soft_pixels=int(soft.sum()),unmixed_boundary_pixels=int(edge.sum()),nearest_boundary_clear_distance_max=float(distance[edge].max()),clear_sample_3x3_rgb_norm_variation_max=float(variation[edge].max()),background_rgb=np.median(a[clear],axis=0).tolist(),opaque_and_nonboundary_original_rgb_preserved=True)

if __name__=='__main__':
 take='defend_h3_v2';out=p.SOURCE_DIR/take;rec=json.loads((out/'original.json').read_bytes());assert p.sha(out/'original_lossless.mkv')==rec['sha256']
 target=out/'matte_local_plate';assert not list(target.glob('*.png'));target.mkdir(exist_ok=True)
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
  recipe=dict(frames=124,extracted_frames=124,fps=24,rgba_sha256=hashes,background_frames=details,recipe='Identical pinned BiRefNet1024 FP16 mask, resized to original RGB dimensions. Opaquealpha>=.98 and all nonboundary RGB retain exact source RGB. Only soft boundary colors within8px of nearest actual source background pixel unmix measured RGB; entire sample3x3 NNalpha below ORIGINAL background exclusion cutoff8/255 and3x3 RGB norm variation<10 required before nearest choice. Clear candidates must connect to image border; uncertain subject interiors retain originalRGB. No global uniform key assumption, spatial color fit, pose interpolation or geometry change. Same alpha8 cutoff and original solid-connected component rule as strict matte. Alpha byte-identical to all53 retained strict partial frames. Previous strict partial and rejected extraction recipes preserved separately. Full visual review required.',model_manifest=json.loads((segment.BASE/'model_manifest.json').read_bytes()),inference_precision='float16',torch_version=torch.__version__,gpu=torch.cuda.get_device_name(),elapsed_seconds=round(time.time()-start,3),tool_sha256=p.sha(Path(__file__)))
  p.write(out/'matte_local_plate.json',recipe)
 finally:
  del net;torch.cuda.empty_cache()
 print('LOCAL_PLATE_TRIAL_COMPLETED_VISUAL_REVIEW_PENDING',take,len(hashes),flush=True)
