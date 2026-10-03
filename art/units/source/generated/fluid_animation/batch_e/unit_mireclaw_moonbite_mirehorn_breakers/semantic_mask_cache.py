"""Preserve all pinned NN float alpha once; CPU edge analysis must not reload GPU."""
import json,hashlib,time
from pathlib import Path
import av,numpy as np,torch
from PIL import Image
import produce as p
import segment
if __name__=='__main__':
 out=p.SOURCE_DIR/'defend_h3_v2';rec=json.loads((out/'original.json').read_bytes());assert p.sha(out/'original_lossless.mkv')==rec['sha256']
 target=out/'semantic_mask_cache';assert not target.exists();target.mkdir()
 net=segment.model();records=[];start=time.time()
 try:
  for i,f in enumerate(av.open(str(out/'original_lossless.mkv')).decode(video=0)):
   rgb=f.to_image().convert('RGB');assert hashlib.sha256(rgb.tobytes()).hexdigest()==rec['decoded_rgb_sha256'][i]
   image=rgb.resize((1024,1024),Image.Resampling.BICUBIC)
   tensor=torch.from_numpy(np.array(image)).permute(2,0,1).float().div(255)
   tensor=(tensor-torch.tensor([.485,.456,.406])[:,None,None])/torch.tensor([.229,.224,.225])[:,None,None]
   with torch.inference_mode():
    prediction=net(tensor[None].to('cuda',dtype=torch.float16))[-1].sigmoid().float()
    alpha=torch.nn.functional.interpolate(prediction,size=(rgb.height,rgb.width),mode='bilinear',align_corners=False)[0,0].cpu().numpy()
   file=target/f'alpha_{i:03}.npy';np.save(file,alpha,allow_pickle=False);records.append(dict(file=file.name,sha256=p.sha(file)))
   if i%24==0:print('PINNED_SEMANTIC_MASK_CACHED',i,flush=True)
  assert len(records)==124
  p.write(out/'semantic_mask_cache.json',dict(frames=124,source_rgb_sha256=rec['decoded_rgb_sha256'],masks=records,model_manifest=json.loads((segment.BASE/'model_manifest.json').read_bytes()),inference_precision='float16',torch_version=torch.__version__,gpu=torch.cuda.get_device_name(),tool_sha256=p.sha(Path(__file__)),elapsed_seconds=round(time.time()-start,3),rule='Lossless float32 original-size NN output from unchanged pinned1024/FP16 inference. Preserve for CPU-only matting analysis; no mask refinement, source geometry, poses or RGB changed.'))
 finally:
  del net;torch.cuda.empty_cache()
 print('ALL124_SEMANTIC_MASKS_PRESERVED_GPU_RELEASE_READY',flush=True)
