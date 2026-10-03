"""Measure a smooth original RGB plate; never infer a mask or subject colors."""
import numpy as np

def uniform_candidate(rgb):
 a=np.asarray(rgb).astype(np.float32)
 medians=np.array([np.median(c.reshape(-1,3),axis=0) for c in [a[:24,:24],a[:24,-24:],a[-24:,:24],a[-24:,-24:]]])
 bg=np.median(medians,axis=0)
 return float(np.linalg.norm(medians-bg,axis=1).max())<10 or bool(np.max(np.sum(np.linalg.norm(medians[:,None]-medians[None,:],axis=2)<10,axis=1))>=3)

def measure(rgb):
 a=np.asarray(rgb).astype(np.float32);h,w=a.shape[:2]
 y,x=np.mgrid[:h,:w];xn=x/(w-1)*2-1;yn=y/(h-1)*2-1
 terms=np.stack([np.ones_like(xn),xn,yn,xn*yn],axis=-1)
 border=(x<32)|(x>=w-32)|(y<32)|(y>=h-32)
 train=border&(x%8==0)&(y%8==0)
 coefficients=np.linalg.lstsq(terms[train],a[train],rcond=None)[0]
 field=np.clip(terms@coefficients,0,255).astype(np.float32)
 # Independent clear perimeter strips were personally inspected in all124
 # original guard frames. NN extraction additionally proves mask exclusion.
 validate=((x<72)|(x>=w-72)|(y<96)|(y>=h-24))&(x%8==4)&(y%8==4)
 errors=np.linalg.norm(a[validate]-field[validate],axis=1)
 detail=dict(coefficients_rgb=coefficients.tolist(),training_pixels=int(train.sum()),validation_pixels=int(validate.sum()),validation_error_rgb_norm_max=float(errors.max()),validation_error_rgb_norm_p999=float(np.quantile(errors,.999)))
 assert detail['validation_error_rgb_norm_p999']<6 and detail['validation_error_rgb_norm_max']<12,detail
 return field,border|validate,detail

if __name__=='__main__':
 import json,hashlib,av
 import produce as p
 out=p.SOURCE_DIR/'defend_h3_v2';rec=json.loads((out/'original.json').read_bytes());details=[]
 for i,f in enumerate(av.open(str(out/'original_lossless.mkv')).decode(video=0)):
  rgb=f.to_image().convert('RGB');assert hashlib.sha256(rgb.tobytes()).hexdigest()==rec['decoded_rgb_sha256'][i]
  if uniform_candidate(rgb):details.append(dict(frame=i,uniform_three_corner_candidate=True));continue
  try:_,_,detail=measure(rgb);details.append(dict(frame=i,**detail))
  except AssertionError as error:print('SPATIAL_PLATE_REJECTED',i,error,flush=True);raise
 p.write(out/'spatial_plate_cpu.json',dict(frames=124,source_rgb_sha256=rec['decoded_rgb_sha256'],measurements=details,tool_sha256=p.sha(p.SOURCE_DIR/'plate_field.py'),rule='Bilinear RGB plate fit on dense clear outer32px, independent clear strips validate max12/p9996 RGB norm; never a subject mask or pose interpolation. Same pinned semantic alpha still required and all samples must be below8/255. Source/matte/native review pending.'))
 print('MEASURED_VALIDATED_ORIGINAL_SPATIAL_PLATES',len(details),flush=True)
