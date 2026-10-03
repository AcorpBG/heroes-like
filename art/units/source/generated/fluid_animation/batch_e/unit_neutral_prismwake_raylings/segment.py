"""Pinned local BiRefNet soft matte of original H3 RGB, no motion synthesis."""
import os,sys,json,time,hashlib,argparse
from pathlib import Path
BASE=Path(os.environ.get('HEROES_MATTING_ROOT','H:/ai/minimax-h3/matting' if os.name=='nt' else '~/.cache/heroes-like/matting')).expanduser()
os.environ['HF_HOME']=str(BASE/'hf-cache')
os.environ['HF_MODULES_CACHE']=str(BASE/'hf-modules')
os.environ['HF_HUB_OFFLINE']='1'
sys.path.insert(0,str(next((BASE/'dependencies').glob('timm-1.0.30-*.whl'))))
import torch,av,numpy as np
from PIL import Image
from scipy.ndimage import label
from transformers import AutoModelForImageSegmentation
import produce as p

def model():
 import stage_video
 stage_video.release_models()
 manifest=json.loads((BASE/'model_manifest.json').read_bytes())
 for name,record in manifest['files'].items():
  file=BASE/('dependencies' if name.endswith('.whl') else 'BiRefNet-matting')/name
  assert file.stat().st_size==record['bytes'] and hashlib.file_digest(file.open('rb'),'sha256').hexdigest()==record['sha256'],name
 torch.set_num_threads(8)
 return AutoModelForImageSegmentation.from_pretrained(BASE/'BiRefNet-matting',trust_remote_code=True,local_files_only=True,use_safetensors=True).eval().to('cuda',dtype=torch.float16)

def extract(net,rgb):
 a=np.asarray(rgb).astype(np.float32)
 image=rgb.resize((1024,1024),Image.Resampling.BICUBIC)
 tensor=torch.from_numpy(np.array(image)).permute(2,0,1).float().div(255)
 tensor=(tensor-torch.tensor([.485,.456,.406])[:,None,None])/torch.tensor([.229,.224,.225])[:,None,None]
 with torch.inference_mode():
  prediction=net(tensor[None].to('cuda',dtype=torch.float16))[-1].sigmoid().float()
  alpha=torch.nn.functional.interpolate(prediction,size=(rgb.height,rgb.width),mode='bilinear',align_corners=False)[0,0].cpu().numpy()
 corners=[a[:24,:24],a[:24,-24:],a[-24:,:24],a[-24:,-24:]]
 medians=np.array([np.median(c.reshape(-1,3),axis=0) for c in corners]);bg=np.median(medians,axis=0)
 spread=float(np.linalg.norm(medians-bg,axis=1).max());excluded=[]
 if spread>=10:
  # A distant background corner can differ from the other three samples.
  # Require three agreeing corners and prove the semantic mask excludes the
  # fourth completely; never treat subject pixels as a background sample.
  distance=np.linalg.norm(medians[:,None]-medians[None,:],axis=2)
  center=int(np.sum(distance<10,axis=1).argmax());valid=distance[center]<10
  assert valid.sum()>=3,'No reliable uniform plate samples'
  masks=[alpha[:24,:24],alpha[:24,-24:],alpha[-24:,:24],alpha[-24:,-24:]]
  excluded=np.flatnonzero(~valid).tolist()
  assert all(float(masks[k].max())<8/255 for k in excluded),'Outlier corner contains foreground; review'
  bg=np.median(medians[valid],axis=0)
 # Restore only soft edge colors mixed with the measured plate; opaque source
 # colors and all source-frame coordinates remain unchanged.
 alpha[alpha>=.98]=1
 color=np.clip((a-(1-alpha[:,:,None])*bg)/np.maximum(alpha[:,:,None],.001),0,255)
 out=np.dstack([color,alpha*255]).astype('uint8');out[out[:,:,3]<8]=0
 labels,n=label(out[:,:,3]>=8,structure=np.ones((3,3),dtype=np.uint8))
 solid=np.unique(labels[out[:,:,3]>=128]);keep=np.zeros(n+1,dtype=bool);keep[solid]=True;keep[0]=False;out[~keep[labels]]=0
 return Image.fromarray(out),dict(background_rgb=bg.tolist(),mode='birefnet_semantic_soft_alpha_plate_unmix',corner_median_spread=spread,excluded_background_corner_indices=excluded,excluded_corner_semantic_alpha_max_below=8/255)

def run(net,take,indices=None):
 out=p.SOURCE_DIR/take;rec=json.loads((out/'original.json').read_bytes())
 assert p.sha(out/'original_lossless.mkv')==rec['sha256']
 target=out/('segment_probe' if indices else 'matte');target.mkdir(exist_ok=True)
 prior=json.loads((out/'matte.json').read_bytes()) if (out/'matte.json').exists() else None
 hashes=[];details=[];start=time.time()
 with av.open(str(out/'original_lossless.mkv')) as video:
  for i,frame in enumerate(video.decode(video=0)):
   if indices is not None and i not in indices:continue
   rgb=frame.to_image().convert('RGB');assert hashlib.sha256(rgb.tobytes()).hexdigest()==rec['decoded_rgb_sha256'][i]
   im,detail=extract(net,rgb);f=target/f'rgba_{i:03}.png'
   if prior and prior.get('boundary_despill_source_pixels')==0:
    from edge_despill import apply
    im=apply(im)
   if f.exists() and not indices:
    if prior:
     assert p.sha(f)==prior['rgba_sha256'][i],'Existing accepted extraction changed'
     assert Image.open(f).convert('RGBA').tobytes()==im.tobytes(),'Rebuilt semantic matte differs; preserve prior extraction'
    else:
    # A failed key trial is a disposable extraction, not original video/art.
     existing=Image.open(f).convert('RGBA').tobytes()
     if existing!=im.tobytes():
      old=p.key(rgb,json.loads((out/'config.json').read_bytes()))[0]
      assert existing==old.tobytes(),'Unknown pre-existing matte'
   im.save(f);hashes.append(p.sha(f));details.append(detail)
   if i%24==0:print(take,i,round(time.time()-start,1),flush=True)
 if indices is None:
  assert len(hashes)==124
  recipe=dict(frames=124,fps=24,rgba_sha256=hashes,background_frames=details,recipe='Pinned BiRefNet-matting: 1024 input only for mask inference, soft mask resized to unchanged original RGB dimensions. Opaque alpha>=.98 retains original RGB; soft edges unmix measured uniform plate. Alpha<8 removed; connected regions retained when containing alpha>=128. Fixed anatomical scale/anchor, no stabilization or interpolation.',model_manifest=json.loads((BASE/'model_manifest.json').read_bytes()),inference_precision='float16',torch_version=torch.__version__,gpu=torch.cuda.get_device_name(),elapsed_seconds=round(time.time()-start,3),tool_sha256=p.sha(Path(__file__)))
  if prior and prior.get('boundary_despill_source_pixels')==0:
   for key in ['boundary_despill_source_pixels','edge_despill_recipe','edge_despill_tool_sha256','semantic_matte_initial_sha256']:recipe[key]=prior[key]
  p.write(out/'matte.json',recipe);p.write(out/'segmentation_recipe.json',dict(recipe=recipe['recipe'],model_manifest=recipe['model_manifest'],tool_sha256=recipe['tool_sha256'],inference_precision='float16'))
  p.review(out,json.loads((out/'config.json').read_bytes()))
 print('SEGMENTED',take,len(hashes),flush=True)

def prepare_guides(net):
 request=p.SOURCE_DIR/'guides/semantic_guides.json'
 if not request.exists():return
 for item in json.loads(request.read_bytes()):
  original=p.SOURCE_DIR/item['original'];target=p.SOURCE_DIR/item['target'];recipe=p.SOURCE_DIR/item['recipe']
  assert original.resolve().is_relative_to(p.SOURCE_DIR.resolve()) and target.resolve().is_relative_to(p.SOURCE_DIR.resolve())
  if target.exists():
   prior=json.loads(recipe.read_bytes());assert p.sha(original)==prior['original_sha256'] and p.sha(target)==prior['output_sha256'];continue
  rgba,detail=extract(net,Image.open(original).convert('RGB'));rgba.save(target)
  p.write(recipe,dict(original_sha256=p.sha(original),output_sha256=p.sha(target),original_dimensions=list(Image.open(original).size),output_dimensions=list(rgba.size),alpha_extrema=list(rgba.getchannel('A').getextrema()),recipe='Pinned semantic soft alpha extraction, unchanged original pixel coordinates and opaque RGB, no anatomy or pose edits.',detail=detail,model_manifest=json.loads((BASE/'model_manifest.json').read_bytes()),tool_sha256=p.sha(Path(__file__)),inference_precision='float16'))
  p.write(target.with_suffix('.generation.json'),dict(image=dict(path=target.relative_to(p.ROOT).as_posix(),sha256=p.sha(target)),prompt=dict(path=(p.SOURCE_DIR/item['prompt']).relative_to(p.ROOT).as_posix(),sha256=p.sha(p.SOURCE_DIR/item['prompt'])),original_image=dict(path=original.relative_to(p.ROOT).as_posix(),sha256=p.sha(original)),matte_recipe=dict(path=recipe.relative_to(p.ROOT).as_posix(),sha256=p.sha(recipe)),references=[dict(path=original.relative_to(p.ROOT).as_posix(),sha256=p.sha(original))]))
  print('SEMANTIC_GUIDE',target.name,flush=True)

if __name__=='__main__':
 a=argparse.ArgumentParser();a.add_argument('takes',nargs='+');a.add_argument('--probe',action='store_true');args=a.parse_args()
 net=model()
 if not args.probe:prepare_guides(net)
 for take in args.takes:
  try:run(net,take,[0,8,24,64,96,123] if args.probe else None)
  except Exception as error:
   if not args.probe:
    out=p.SOURCE_DIR/take
    files=sorted((out/'matte').glob('rgba_*.png'))
    hashes=[None]*124
    for file in files:hashes[int(file.stem.split('_')[-1])]=p.sha(file)
    p.write(out/'failed_matte.json',dict(status='failed_requires_source_and_plate_review',error=repr(error),frames_written=len(files),rgba_sha256=hashes,tool_sha256=p.sha(Path(__file__)),model_manifest=json.loads((BASE/'model_manifest.json').read_bytes()),rule='Preserve original source and actual partial alpha hashes; do not silently relax extraction or acceptance.'))
   raise
