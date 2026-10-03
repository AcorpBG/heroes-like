"""Rebuild original Heliograph Ballista H3 takes and reviewed candidates."""
import argparse
import hashlib
import io
import json
import sys
import time
import urllib.request
import urllib.error
import urllib.parse
from pathlib import Path
import av
import numpy as np
from PIL import Image, ImageDraw
from scipy.ndimage import label, distance_transform_edt

ROOT=next(p for p in Path(__file__).resolve().parents if (p/'project.godot').exists())
SOURCE_DIR=Path(__file__).resolve().parent
sys.path.insert(0,str(ROOT/'tools'))
from trial_video_creature_animation import fetch_bytes,request,status,node,write
from integrate_fluid_creature_animation import source_pose
from publish_fluid_creature_animation import combine
URL='http://127.0.0.1:8189'

def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()

def collect(out,url):
 """Preserve decoded original dimensions and prove every FFV1 RGB frame."""
 result=json.loads((out/'generation_history.json').read_bytes())
 assert result['status']['status_str']=='success'
 images=result['outputs']['15']['images'];assert len(images)==124
 size=tuple(json.loads((out/'config.json').read_bytes()).get('canvas',[960,544]))
 target=out/'original_lossless.mkv'
 if target.exists():raise RuntimeError('Original already collected; use process')
 hashes=[]
 with av.open(str(target),'w') as container:
  stream=container.add_stream('ffv1',rate=24);stream.width,stream.height=size;stream.pix_fmt='bgr0'
  for item in images:
   im=Image.open(io.BytesIO(fetch_bytes(url,item))).convert('RGB');assert im.size==size
   hashes.append(hashlib.sha256(im.tobytes()).hexdigest())
   for packet in stream.encode(av.VideoFrame.from_image(im)):container.mux(packet)
  for packet in stream.encode():container.mux(packet)
 with av.open(str(target)) as container:
  actual=[hashlib.sha256(f.to_image().convert('RGB').tobytes()).hexdigest() for f in container.decode(video=0)]
 assert actual==hashes,'Collected original RGB changed'
 for items in result['outputs'].get('14',{}).values():
  if isinstance(items,list):
   for item in items:
    if isinstance(item,dict) and str(item.get('filename','')).endswith('.mp4'):(out/'original.mp4').write_bytes(fetch_bytes(url,item))
 write(out/'original.json',dict(frames=124,fps=24,size=list(size),lossless_codec='ffv1/bgr0',sha256=sha(target),decoded_rgb_sha256=hashes,workflow_sha256=sha(out/'workflow_api.json'),source='ComfyUI decoded PNG frames, encoded losslessly; all decoded RGB hashes verified'))
 print('Collected and pixel-verified 124 original frames losslessly',flush=True)

def prepare(out,c):
 if (out/'submission.json').exists():raise RuntimeError('Submitted original is immutable; choose another take')
 width,height=c.get('canvas',[960,544])
 refs=[]
 for i,original in enumerate(c['references']):
  f=original.copy();f['scale']=original['scale']/c['scale']
  # Video guides may magnify an original to expose small painted details to
  # the model. This is a fixed whole-reference resize, never authored motion or
  # per-frame normalization; final extracted frames retain the runtime scale.
  guide_magnification=max(1.0,f['scale']);sampling=dict(f,scale=f['scale']/guide_magnification)
  pose,(x,y)=source_pose(sampling,f.get('alpha_noise_cutoff',8))
  if guide_magnification>1:
   pose=pose.resize((round(pose.width*guide_magnification),round(pose.height*guide_magnification)),Image.Resampling.LANCZOS)
   x,y=round(x*guide_magnification),round(y*guide_magnification)
  offset=original.get('guide_offset',[0,0])
  rgba=Image.new('RGBA',(width,height));rgba.alpha_composite(pose,(c['anchor'][0]+x+offset[0],c['anchor'][1]+y+offset[1]))
  bounds=rgba.getchannel('A').point(lambda a:255 if a>127 else 0).getbbox()
  assert bounds and min(bounds)>0 and bounds[2]<width-1 and bounds[3]<height-1,(i,bounds)
  rgba.save(out/f'guide_{i}_rgba.png');back=Image.new('RGBA',rgba.size,tuple(c.get('key_rgb',[255,0,255]))+(255,));back.alpha_composite(rgba);back.convert('RGB').save(out/f'guide_{i}_chroma.png')
  refs.append(dict(source_frame=f,source_sha256=sha(ROOT/f['source']),input_file=f'guide_{i}_chroma.png',input_sha256=sha(out/f'guide_{i}_chroma.png'),runtime_source_scale=original['scale']))
 write(out/'reference.json',dict(unit_id=c['unit_id'],guides=refs,canvas=[width,height],ground_anchor=c['anchor'],output_scale=c['scale'],rule='One original anatomical scale per painting divided by fixed extraction scale; no per-frame normalization.'))
 # This unit's immutable baseline was captured before generation. Do not read
 # concurrently published catalogs while holding the GPU lease.
 row=json.loads((SOURCE_DIR/'original_unit_baseline.json').read_bytes())
 assert row['unit_id']==c['unit_id'];write(out/'accepted_baseline.json',row)
 (out/'prompt.txt').write_text(c['prompt']+'\n',encoding='utf-8')
 graph={
  '1':node('UNETLoader',unet_name='minimax_h3_fl2va_pruned_int8_convrot.safetensors',weight_dtype='default'),
  '2':node('CLIPLoader',clip_name='qwen3vl_32b_minimax_h3_nvfp4_awq.safetensors',type='minimax',device='default'),
  '3':node('VAELoader',vae_name='minimax_h3_video_vae_int8_convrot.safetensors'),
  '5':node('MiniMaxH3ImageToVideo',clip=['2',0],vae=['3',0],prompt=c['prompt'],width=width,height=height,length=124,first_frame=['30',0]),
  '7':node('RandomNoise',noise_seed=c['seed']),
  '8':node('KSamplerSelect',sampler_name='res_multistep'),
  '9':node('BasicScheduler',model=['1',0],scheduler='simple',steps=20,denoise=1.0),
  '10':node('SamplerCustomAdvanced',noise=['7',0],guider=['6',0],sampler=['8',0],sigmas=['9',0],latent_image=['5',1]),
  '11':node('VAEDecode',samples=['10',0],vae=['3',0]),
  '13':node('CreateVideo',images=['11',0],fps=24,bit_depth=8),
  '14':node('SaveVideo',video=['13',0],filename_prefix=f'heliograph_ballista_h3/{out.name}/original',**{'format':'mp4','format.codec':'h264'}),
  '15':node('SaveImage',images=['11',0],filename_prefix=f'heliograph_ballista_h3/{out.name}/frames/decoded')}
 if c['last'] is not None:
  graph['5']['inputs']['last_frame']=[str(30+c['last']),0]
 if c.get('tiled_decode'):
  graph['11']=node('VAEDecodeTiled',samples=['10',0],vae=['3',0],**c['tiled_decode'])
 for i in range(len(refs)):graph[str(30+i)]=node('LoadImage',image=f'heliograph_ballista_{out.name}_guide_{i}.png')
 previous='5'
 for i,(frame,ref) in enumerate(c['guides']):
  k=str(40+i);graph[k]=node('MiniMaxH3AddGuide',positive=[previous,0],latent=['5',1],frame_idx=frame,vae=['3',0],image=[str(30+ref),0]);previous=k
 graph['6']=node('BasicGuider',model=['1',0],conditioning=[previous,0]);write(out/'workflow_api.json',graph)

def verify(out,c):
 g=json.loads((out/'workflow_api.json').read_bytes());assert g['5']['inputs']['prompt']==(out/'prompt.txt').read_text(encoding='utf-8').strip()==c['prompt']
 assert g['5']['inputs'].get('last_frame')==([str(30+c['last']),0] if c['last'] is not None else None)
 for ref in json.loads((out/'reference.json').read_bytes())['guides']:
  assert sha(out/ref['input_file'])==ref['input_sha256'];assert sha(ROOT/ref['source_frame']['source'])==ref['source_sha256']

def submit(out,c):
 verify(out,c)
 if (out/'submission.json').exists():raise RuntimeError('Already submitted; inspect the exact job')
 q=request(URL,'/queue');assert not q['queue_running'] and not q['queue_pending'],'Server busy; queue untouched'
 g=json.loads((out/'workflow_api.json').read_bytes());uploaded={}
 for i in range(len(c['references'])):
  name=f'heliograph_ballista_{out.name}_guide_{i}.png'
  if c.get('reuse_uploaded_guides'):
   # A decode-only retry retains the exact loader inputs so ComfyUI can reuse
   # its completed sampling cache. Restore cleaned inputs on later rebuilds.
   item=c['reuse_uploaded_guides'][str(30+i)];name=item['name']
   assert not item.get('subfolder') and name.startswith('heliograph_ballista_') and '/' not in name and '\\' not in name
   query=urllib.parse.urlencode(dict(filename=name,type='input'))
   try:
    with urllib.request.urlopen(URL+'/view?'+query,timeout=30) as response:existing=response.read()
   except urllib.error.HTTPError as error:
    if error.code!=404:raise
   else:
    assert hashlib.sha256(existing).hexdigest()==sha(out/f'guide_{i}_chroma.png'),'Uploaded guide changed; do not overwrite it'
    uploaded[str(30+i)]=item;g[str(30+i)]['inputs']['image']=name;continue
  boundary='----HeliographBallistaH3'
  data=(f'--{boundary}\r\nContent-Disposition: form-data; name="image"; filename="{name}"\r\nContent-Type: image/png\r\n\r\n'.encode()+(out/f'guide_{i}_chroma.png').read_bytes()+f'\r\n--{boundary}--\r\n'.encode())
  req=urllib.request.Request(URL+'/upload/image',data=data,headers={'Content-Type':'multipart/form-data; boundary='+boundary})
  with urllib.request.urlopen(req,timeout=60) as r:item=json.load(r)
  uploaded[str(30+i)]=item;g[str(30+i)]['inputs']['image']='/'.join(v for v in [item.get('subfolder',''),item['name']] if v)
 write(out/'workflow_api.json',g);start=time.time();r=request(URL,'/prompt',dict(prompt=g,client_id='heliograph_ballista_h3'))
 write(out/'submission.json',dict(**r,started_unix=start,url=URL,uploaded=uploaded));print(json.dumps(r))

def key(rgb,c):
 a=np.asarray(rgb,dtype=np.float32)
 corner_tiles=[a[:24,:24],a[:24,-24:],a[-24:,:24],a[-24:,-24:]]
 corner_medians=np.array([np.median(tile.reshape(-1,3),axis=0) for tile in corner_tiles])
 bg=np.median(corner_medians,axis=0)
 spread=float(np.max(np.linalg.norm(corner_medians-bg,axis=1)))
 if spread>10:raise ValueError(f'unsafe spatially varying corner plate {bg}; median spread={spread:.2f}')
 if c.get('key_rgb')==[0,0,255]:
  # Optional blue-key support requires a reviewed foreground-color measurement.
  # Blue keys require a separately reviewed foreground palette.
  # A reviewed blue/cyan plate can use the blue-red axis when the complete
  # original foreground palette is separated on that axis. This retains teal
  # cloth rather than treating it as a cyan background by hue alone.
  blue_red=c.get('blue_chroma_axis')=='blue_minus_red'
  bgc=bg[2]-(bg[0] if blue_red else max(bg[0],bg[1]))
  if bgc<80:raise ValueError(f'unsafe blue backdrop {bg}')
  chroma=a[:,:,2]-(a[:,:,0] if blue_red else np.maximum(a[:,:,0],a[:,:,1]));protected=float(c.get('protected_foreground_chroma',20))
  alpha=np.clip((bgc-chroma)/(bgc-protected),0,1);alpha[np.linalg.norm(a-bg,axis=2)<12]=0
  color=np.clip((a-(1-alpha[:,:,None])*bg)/np.maximum(alpha[:,:,None],.001),0,255)
  boundary=distance_transform_edt(alpha>=.98)<=2
  color[:,:,2]-=np.maximum(color[:,:,2]-np.maximum(color[:,:,0],color[:,:,1]),0)*boundary
  if blue_red:
   # Remove only boundary cyan spill above the measured opaque palette band;
   # preserve the teal cloth and every opaque original pixel.
   spill=np.maximum(np.minimum(color[:,:,1],color[:,:,2])-color[:,:,0]-protected,0)*(alpha<.98)
   color[:,:,1]-=spill;color[:,:,2]-=spill
  out=np.dstack([color,alpha*255]).astype('uint8');out[out[:,:,3]<8]=0
  labels,n=label(out[:,:,3]>=8,structure=np.ones((3,3),dtype=np.uint8));solid=np.unique(labels[out[:,:,3]>=128]);keep=np.zeros(n+1,dtype=bool);keep[solid]=True;keep[0]=False;out[~keep[labels]]=0
  return Image.fromarray(out,'RGBA'),dict(background_rgb=[round(float(v),3) for v in bg],corner_median_spread=round(float(spread),3),mode='flat_blue_chroma_unmix',component_rule='alpha>=8 components retained only when they contain alpha>=128 source pixels')
 if c.get('key_rgb')==[255,255,0]:
  bgc=min(bg[0],bg[1])-bg[2]
  if bgc<80:raise ValueError(f'unsafe yellow backdrop {bg}')
  protected=float(c['protected_foreground_chroma'])
  assert bgc-protected>=80,'Yellow plate too close to measured costume'
  chroma=np.minimum(a[:,:,0],a[:,:,1])-a[:,:,2]
  alpha=np.clip((bgc-chroma)/(bgc-protected),0,1)
  alpha[np.linalg.norm(a-bg,axis=2)<12]=0
  color=np.clip((a-(1-alpha[:,:,None])*bg)/np.maximum(alpha[:,:,None],.001),0,255)
  spill=np.maximum(np.minimum(color[:,:,0],color[:,:,1])-color[:,:,2],0)*(alpha<.98)
  color[:,:,0]-=spill;color[:,:,1]-=spill
  out=np.dstack([color,alpha*255]).astype('uint8');out[out[:,:,3]<8]=0
  labels,n=label(out[:,:,3]>=8,structure=np.ones((3,3),dtype=np.uint8));solid=np.unique(labels[out[:,:,3]>=128]);keep=np.zeros(n+1,dtype=bool);keep[solid]=True;keep[0]=False;out[~keep[labels]]=0
  return Image.fromarray(out,'RGBA'),dict(background_rgb=[round(float(v),3) for v in bg],corner_median_spread=round(float(spread),3),mode='flat_yellow_chroma_unmix',component_rule='alpha>=8 components retained only when they contain alpha>=128 source pixels')
 magenta=min(bg[0],bg[2])-bg[1]
 green=bg[1]-max(bg[0],bg[2])
 is_green=green>magenta
 bgc=green if is_green else magenta
 if bgc<80:raise ValueError(f'unsafe insufficiently separated chroma backdrop {bg}')
 # Measure the actual cloth, leather, skin and metal foreground and
 # uniform source plate and preserve its measured foreground band; never
 # infer opaque subject geometry or accept spatially varying backgrounds.
 chroma=a[:,:,1]-np.maximum(a[:,:,0],a[:,:,2]) if is_green else np.minimum(a[:,:,0],a[:,:,2])-a[:,:,1]
 # The protected foreground chroma band preserves muted painted colors. The
 # unit-specific foreground band removes green plate spill from fine edges while
 # removing the saturated green plate and unmixing only boundary pixels.
 protected=float(c.get('protected_foreground_chroma',0))
 alpha=np.clip((bgc-chroma)/(bgc-protected),0,1)
 alpha[np.linalg.norm(a-bg,axis=2)<12]=0
 color=np.clip((a-(1-alpha[:,:,None])*bg)/np.maximum(alpha[:,:,None],.001),0,255)
 if is_green:
  # A two-source-pixel boundary band removes opaque green ringing from the
  # generated chroma plate. Alpha/geometry stay unchanged and interior teal
  # cloth remains protected by the measured original foreground palette.
  boundary=distance_transform_edt(alpha>=.98)<=2
  spill=np.maximum(color[:,:,1]-np.maximum(color[:,:,0],color[:,:,2]),0)*boundary
  color[:,:,1]-=spill
 else:
  boundary=distance_transform_edt(alpha>=.98)<=2
  spill=np.maximum(np.minimum(color[:,:,0],color[:,:,2])-color[:,:,1],0)*boundary
  color[:,:,0]-=spill; color[:,:,2]-=spill
 mode='flat_green_chroma_unmix' if is_green else 'flat_magenta_chroma_unmix'
 out=np.dstack([color,alpha*255]).astype('uint8');out[out[:,:,3]<8]=0
 # Retain every >8-alpha connected creature component that contains at least
 # one confidently opaque pixel. This removes disconnected plate noise while
 # keeping fine cloth tips, shield details and separated fallen props attached
 # to their own solid pixels.
 mask=out[:,:,3]>=8; labels,n=label(mask,structure=np.ones((3,3),dtype=np.uint8))
 solid=np.unique(labels[out[:,:,3]>=128]); keep=np.zeros(n+1,dtype=bool);keep[solid]=True;keep[0]=False
 out[~keep[labels]]=0
 return Image.fromarray(out,'RGBA'),dict(background_rgb=[round(float(v),3) for v in bg],corner_median_spread=round(float(spread),3),mode=mode,component_rule='alpha>=8 components retained only when they contain alpha>=128 source pixels')


def process(out,c):
 if (out/'extraction_settings.json').exists():
  settings=json.loads((out/'extraction_settings.json').read_bytes())
  c=dict(c,protected_foreground_chroma=settings['protected_foreground_chroma'],reviewed_key_ranges=settings.get('reviewed_key_ranges',[]),blue_chroma_axis=settings.get('blue_chroma_axis','blue_minus_max_red_green'))
 (out/'matte').mkdir(exist_ok=True);hashes=[];details=[]
 intervals=json.loads((out/'extract_ranges.json').read_bytes())['inclusive_ranges'] if (out/'extract_ranges.json').exists() else [[0,123]]
 assert all(0<=a<=b<124 for a,b in intervals)
 with av.open(str(out/'original_lossless.mkv')) as video:
  for i,frame in enumerate(video.decode(video=0)):
   if not any(a<=i<=b for a,b in intervals):hashes.append(None);details.append(dict(excluded=True));continue
   frame_config=dict(c)
   for reviewed in c.get('reviewed_key_ranges',[]):
    if reviewed['start']<=i<=reviewed['end']:
     frame_config['key_rgb']=reviewed['key_rgb']
     if 'protected_foreground_chroma' in reviewed:frame_config['protected_foreground_chroma']=reviewed['protected_foreground_chroma']
   im,detail=key(frame.to_image().convert('RGB'),frame_config)
   expected={(0,0,255):'flat_blue_chroma_unmix',(0,255,0):'flat_green_chroma_unmix',(255,255,0):'flat_yellow_chroma_unmix',(255,0,255):'flat_magenta_chroma_unmix'}[tuple(frame_config.get('key_rgb',[255,0,255]))]
   if detail['mode']!=expected:raise ValueError('Backdrop changed outside the reviewed guide palette; reject this interval')
   p=out/'matte'/f'rgba_{i:03}.png';im.save(p);hashes.append(sha(p));details.append(detail)
 assert len(hashes)==124
 write(out/'matte.json',dict(frames=124,fps=24,rgba_sha256=hashes,background_frames=details,protected_foreground_chroma=c.get('protected_foreground_chroma',0),boundary_despill_source_pixels=2,recipe='Measured uniform guide plate; corner spread<=10, chroma separation>=80; protected foreground chroma band, color-specific alpha unmix and edge-only despill; alpha>=8 regions retained when containing alpha>=128 pixels. Original geometry unchanged.'))

def review(out,c):
 width,height=c.get('canvas',[960,544])
 target=ROOT/'.artifacts/heliograph_ballista_h3'/out.name;target.mkdir(parents=True,exist_ok=True)
 manifest='edge_matte' if (out/'edge_matte.json').exists() else 'matte'
 available=[i for i,h in enumerate(json.loads((out/(manifest+'.json')).read_bytes())['rgba_sha256']) if h]
 bounds=[Image.open(out/manifest/f'rgba_{i:03}.png').getbbox() for i in available]
 assert all(bounds),'Empty extracted creature frame'
 crop=(max(0,min(b[0] for b in bounds)-12),max(0,min(b[1] for b in bounds)-12),min(width,max(b[2] for b in bounds)+12),min(height,max(b[3] for b in bounds)+12))
 for part in range((len(available)+61)//62):
  sheet=Image.new('RGB',(1600,1760),(30,40,30));d=ImageDraw.Draw(sheet)
  for j,i in enumerate(available[part*62:(part+1)*62]):
   x,y=j%8*200,j//8*220
   if j%2:sheet.paste((218,211,193),(x,y,x+200,y+220))
   im=Image.open(out/manifest/f'rgba_{i:03}.png').crop(crop);im.thumbnail((196,195),Image.Resampling.LANCZOS);sheet.paste(im,(x+(200-im.width)//2,y+22),im);d.text((x+5,y+4),str(i),fill=(160,110,65))
  sheet.save(target/f'chronological_{part}.png')
