"""Rebuild original Sluicefire Lindworms H3 takes and pending candidates."""
import argparse
import hashlib
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
from scipy.ndimage import label

ROOT=next(p for p in Path(__file__).resolve().parents if (p/'project.godot').exists())
SOURCE_DIR=Path(__file__).resolve().parent
sys.path.insert(0,str(ROOT/'tools'))
from trial_video_creature_animation import collect,request,status,node,write
from integrate_fluid_creature_animation import source_pose
from publish_fluid_creature_animation import combine
URL='http://127.0.0.1:8189'

def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()

def prepare(out,c):
 if (out/'submission.json').exists():raise RuntimeError('Submitted original is immutable; choose another take')
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
  rgba=Image.new('RGBA',(960,544));rgba.alpha_composite(pose,(c['anchor'][0]+x+offset[0],c['anchor'][1]+y+offset[1]))
  bounds=rgba.getchannel('A').point(lambda a:255 if a>127 else 0).getbbox()
  assert bounds and min(bounds)>0 and bounds[2]<959 and bounds[3]<543,(i,bounds)
  rgba.save(out/f'guide_{i}_rgba.png');back=Image.new('RGBA',rgba.size,tuple(c.get('key_rgb',[255,0,255]))+(255,));back.alpha_composite(rgba);back.convert('RGB').save(out/f'guide_{i}_chroma.png')
  refs.append(dict(source_frame=f,source_sha256=sha(ROOT/f['source']),input_file=f'guide_{i}_chroma.png',input_sha256=sha(out/f'guide_{i}_chroma.png'),runtime_source_scale=original['scale']))
 write(out/'reference.json',dict(unit_id=c['unit_id'],guides=refs,canvas=[960,544],ground_anchor=c['anchor'],output_scale=c['scale'],rule='One original anatomical scale per painting divided by fixed extraction scale; no per-frame normalization.'))
 row=next(r for r in json.loads((ROOT/'content/unit_animation_manifest.json').read_bytes())['items'] if r['unit_id']==c['unit_id']);write(out/'accepted_baseline.json',row)
 (out/'prompt.txt').write_text(c['prompt']+'\n',encoding='utf-8')
 graph={
  '1':node('UNETLoader',unet_name='minimax_h3_fl2va_pruned_int8_convrot.safetensors',weight_dtype='default'),
  '2':node('CLIPLoader',clip_name='qwen3vl_32b_minimax_h3_nvfp4_awq.safetensors',type='minimax',device='default'),
  '3':node('VAELoader',vae_name='minimax_h3_video_vae_int8_convrot.safetensors'),
  '5':node('MiniMaxH3ImageToVideo',clip=['2',0],vae=['3',0],prompt=c['prompt'],width=960,height=544,length=124,first_frame=['30',0],last_frame=[str(30+c['last']),0]),
  '7':node('RandomNoise',noise_seed=c['seed']),
  '8':node('KSamplerSelect',sampler_name='res_multistep'),
  '9':node('BasicScheduler',model=['1',0],scheduler='simple',steps=20,denoise=1.0),
  '10':node('SamplerCustomAdvanced',noise=['7',0],guider=['6',0],sampler=['8',0],sigmas=['9',0],latent_image=['5',1]),
  '11':node('VAEDecode',samples=['10',0],vae=['3',0]),
  '13':node('CreateVideo',images=['11',0],fps=24,bit_depth=8),
  '14':node('SaveVideo',video=['13',0],filename_prefix=f'sluicefire_lindworms_h3/{out.name}/original',**{'format':'mp4','format.codec':'h264'}),
  '15':node('SaveImage',images=['11',0],filename_prefix=f'sluicefire_lindworms_h3/{out.name}/frames/decoded')}
 if c.get('tiled_decode'):
  graph['11']=node('VAEDecodeTiled',samples=['10',0],vae=['3',0],**c['tiled_decode'])
 for i in range(len(refs)):graph[str(30+i)]=node('LoadImage',image=f'sluicefire_lindworms_{out.name}_guide_{i}.png')
 previous='5'
 for i,(frame,ref) in enumerate(c['guides']):
  k=str(40+i);graph[k]=node('MiniMaxH3AddGuide',positive=[previous,0],latent=['5',1],frame_idx=frame,vae=['3',0],image=[str(30+ref),0]);previous=k
 graph['6']=node('BasicGuider',model=['1',0],conditioning=[previous,0]);write(out/'workflow_api.json',graph)

def verify(out,c):
 g=json.loads((out/'workflow_api.json').read_bytes());assert g['5']['inputs']['prompt']==(out/'prompt.txt').read_text().strip()==c['prompt']
 assert g['5']['inputs']['last_frame']==[str(30+c['last']),0]
 for ref in json.loads((out/'reference.json').read_bytes())['guides']:
  assert sha(out/ref['input_file'])==ref['input_sha256'];assert sha(ROOT/ref['source_frame']['source'])==ref['source_sha256']

def submit(out,c):
 verify(out,c)
 if (out/'submission.json').exists():raise RuntimeError('Already submitted; inspect the exact job')
 q=request(URL,'/queue');assert not q['queue_running'] and not q['queue_pending'],'Server busy; queue untouched'
 g=json.loads((out/'workflow_api.json').read_bytes());uploaded={}
 for i in range(len(c['references'])):
  name=f'sluicefire_lindworms_{out.name}_guide_{i}.png'
  if c.get('reuse_uploaded_guides'):
   # A decode-only retry retains the exact loader inputs so ComfyUI can reuse
   # its completed sampling cache. Restore cleaned inputs on later rebuilds.
   item=c['reuse_uploaded_guides'][str(30+i)];name=item['name']
   assert not item.get('subfolder') and name.startswith('sluicefire_lindworms_') and '/' not in name and '\\' not in name
   query=urllib.parse.urlencode(dict(filename=name,type='input'))
   try:
    with urllib.request.urlopen(URL+'/view?'+query,timeout=30) as response:existing=response.read()
   except urllib.error.HTTPError as error:
    if error.code!=404:raise
   else:
    assert hashlib.sha256(existing).hexdigest()==sha(out/f'guide_{i}_chroma.png'),'Uploaded guide changed; do not overwrite it'
    uploaded[str(30+i)]=item;g[str(30+i)]['inputs']['image']=name;continue
  boundary='----SluicefireLindwormsH3'
  data=(f'--{boundary}\r\nContent-Disposition: form-data; name="image"; filename="{name}"\r\nContent-Type: image/png\r\n\r\n'.encode()+(out/f'guide_{i}_chroma.png').read_bytes()+f'\r\n--{boundary}--\r\n'.encode())
  req=urllib.request.Request(URL+'/upload/image',data=data,headers={'Content-Type':'multipart/form-data; boundary='+boundary})
  with urllib.request.urlopen(req,timeout=60) as r:item=json.load(r)
  uploaded[str(30+i)]=item;g[str(30+i)]['inputs']['image']='/'.join(v for v in [item.get('subfolder',''),item['name']] if v)
 write(out/'workflow_api.json',g);start=time.time();r=request(URL,'/prompt',dict(prompt=g,client_id='sluicefire_lindworms_h3'))
 write(out/'submission.json',dict(**r,started_unix=start,url=URL,uploaded=uploaded));print(json.dumps(r))

def key(rgb):
 a=np.asarray(rgb,dtype=np.float32)
 corner_tiles=[a[:24,:24],a[:24,-24:],a[-24:,:24],a[-24:,-24:]]
 corner_medians=np.array([np.median(tile.reshape(-1,3),axis=0) for tile in corner_tiles])
 bg=np.median(corner_medians,axis=0)
 spread=float(np.max(np.linalg.norm(corner_medians-bg,axis=1)))
 if spread>10:raise ValueError(f'unsafe spatially varying corner plate {bg}; median spread={spread:.2f}')
 magenta=min(bg[0],bg[2])-bg[1]
 green=bg[1]-max(bg[0],bg[2])
 is_green=green>magenta
 bgc=green if is_green else magenta
 if bgc<80:raise ValueError(f'unsafe insufficiently separated chroma backdrop {bg}')
 # This serpent contains charcoal, ivory, iron and amber-orange but no green
 # material. Measure the actual uniform source plate; never
 # infer opaque subject geometry or accept spatially varying backgrounds.
 chroma=a[:,:,1]-np.maximum(a[:,:,0],a[:,:,2]) if is_green else np.minimum(a[:,:,0],a[:,:,2])-a[:,:,1]
 alpha=np.clip(1-chroma/bgc,0,1)
 alpha[np.linalg.norm(a-bg,axis=2)<12]=0
 color=np.clip((a-(1-alpha[:,:,None])*bg)/np.maximum(alpha[:,:,None],.001),0,255)
 if is_green:
  spill=np.maximum(color[:,:,1]-np.maximum(color[:,:,0],color[:,:,2]),0)*(alpha<.98)
  color[:,:,1]-=spill
 else:
  spill=np.maximum(np.minimum(color[:,:,0],color[:,:,2])-color[:,:,1],0)*(alpha<.98)
  color[:,:,0]-=spill; color[:,:,2]-=spill
 mode='flat_green_chroma_unmix' if is_green else 'flat_magenta_chroma_unmix'
 out=np.dstack([color,alpha*255]).astype('uint8');out[out[:,:,3]<8]=0
 # Retain every >8-alpha connected creature component that contains at least
 # one confidently opaque pixel. This removes disconnected plate noise while
 # keeping fine dorsal spines, hooked tail edges and iron harness loops attached
 # to their own solid pixels.
 mask=out[:,:,3]>=8; labels,n=label(mask,structure=np.ones((3,3),dtype=np.uint8))
 solid=np.unique(labels[out[:,:,3]>=128]); keep=np.zeros(n+1,dtype=bool);keep[solid]=True;keep[0]=False
 out[~keep[labels]]=0
 return Image.fromarray(out,'RGBA'),dict(background_rgb=[round(float(v),3) for v in bg],corner_median_spread=round(float(spread),3),mode=mode,component_rule='alpha>=8 components retained only when they contain alpha>=128 source pixels')


def process(out,c):
 (out/'matte').mkdir(exist_ok=True);hashes=[];details=[]
 intervals=json.loads((out/'extract_ranges.json').read_bytes())['inclusive_ranges'] if (out/'extract_ranges.json').exists() else [[0,123]]
 assert all(0<=a<=b<124 for a,b in intervals)
 with av.open(str(out/'original_lossless.mkv')) as video:
  for i,frame in enumerate(video.decode(video=0)):
   if not any(a<=i<=b for a,b in intervals):hashes.append(None);details.append(dict(excluded=True));continue
   im,detail=key(frame.to_image().convert('RGB'))
   if detail['mode']!='flat_green_chroma_unmix':raise ValueError('Backdrop changed to a color unsafe for charcoal scales, ivory dorsal plates, iron braces and amber-orange vents; reject this interval')
   p=out/'matte'/f'rgba_{i:03}.png';im.save(p);hashes.append(sha(p));details.append(detail)
 assert len(hashes)==124
 write(out/'matte.json',dict(frames=124,fps=24,rgba_sha256=hashes,background_frames=details,recipe='Measured uniform green plate absent from Sluicefire Lindworm palette; corner spread<=10, chroma separation>=80; color-specific alpha unmix and edge-only despill; alpha>=8 regions retained when containing alpha>=128 pixels. Original geometry unchanged.'))

def review(out,c):
 target=ROOT/'.artifacts/sluicefire_lindworms_h3'/out.name;target.mkdir(parents=True,exist_ok=True)
 for part in range(2):
  sheet=Image.new('RGB',(1600,1760),(30,40,30));d=ImageDraw.Draw(sheet)
  for j,i in enumerate(range(part*62,(part+1)*62)):
   x,y=j%8*200,j//8*220
   if j%2:sheet.paste((218,211,193),(x,y,x+200,y+220))
   im=Image.open(out/'matte'/f'rgba_{i:03}.png').crop((150,10,900,525));im.thumbnail((196,195),Image.Resampling.LANCZOS);sheet.paste(im,(x+(200-im.width)//2,y+22),im);d.text((x+5,y+4),str(i),fill=(160,110,65))
  sheet.save(target/f'chronological_{part}.png')

def build(out,c):
 s=json.loads((out/'selection.json').read_bytes());indices=s['source_frames'];assert len(indices)==len(set(indices))
 matte=json.loads((out/'matte.json').read_bytes());assert all(matte['rgba_sha256'][i] and sha(out/'matte'/f'rgba_{i:03}.png')==matte['rgba_sha256'][i] for i in indices)
 frames=[dict(name=f'{c["clip"]}_h3_{i:03}',clip=c['clip'],source=(out/'matte'/f'rgba_{i:03}.png').relative_to(ROOT).as_posix(),rects=[[0,0,960,544]],anchor=c['anchor'],scale=c['scale'],alpha_noise_cutoff=0,video_frame=i,video_time_seconds=i/24) for i in indices]
 clip=dict(indices=list(range(len(indices))),frame_msec=s['frame_msec'],loop=c['clip']=='move',static_frame=len(indices)-1 if c['clip'] in ['death','defend'] else 0)
 for k in ['contact_frame','frame_durations_msec']:
  if k in s:clip[k]=s[k]
 entry=dict(unit_id=c['unit_id'],reference_height=256,source_facing='right',frames=frames,clips={c['clip']:clip},alpha_noise_cutoff=0,source_scale_reason='One original anatomical scale per guide divided by fixed extraction scale; no frame normalization.',provenance={n:dict(path=(out/n).relative_to(ROOT).as_posix(),sha256=sha(out/n)) for n in ['original_lossless.mkv','original.json','workflow_api.json','prompt.txt','reference.json','matte.json']},visual_review=dict(status='pending',notes=s['review_note']))
 write(out/'handoff.json',dict(schema_version=1,units=[entry]))

def assemble():
 unit=None
 delivery=json.loads((SOURCE_DIR/'delivery.json').read_bytes())
 for take in delivery['takes']:
  unit=combine(unit,json.loads((SOURCE_DIR/take/'handoff.json').read_bytes())['units'][0])
 if delivery.get('attack_segments'):
  parts=[json.loads((SOURCE_DIR/t/'handoff.json').read_bytes())['units'][0] for t in delivery['attack_segments']]
  attack=dict(parts[0]);attack['frames']=[]
  for take,part in zip(delivery['attack_segments'],parts):
   attack['frames'].extend(dict(f,name=f'{take}_{f["name"]}') for f in part['frames'])
  attack['clips']={'attack':dict(indices=list(range(len(attack['frames']))),frame_msec=delivery['attack_frame_msec'],contact_frame=delivery['attack_contact_frame'],loop=False,static_frame=0)}
  attack['provenance']={f'{i}_{k}':v for i,part in enumerate(parts) for k,v in part['provenance'].items()}
  unit=combine(unit,attack)
 unit['preserved_accepted_clips']=['idle'];unit['visual_review']=dict(status='pending',notes='Selected Sluicefire Lindworm H3 actions; native review required. Preserve original accepted articulated idle.')
 write(SOURCE_DIR/'handoff.json',dict(schema_version=1,units=[unit]))

if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('verb',choices=['prepare','verify','submit','status','collect','process','review','build','assemble']);p.add_argument('take',nargs='?');a=p.parse_args()
 if a.verb=='assemble':assemble()
 else:
  out=SOURCE_DIR/a.take;c=json.loads((out/'config.json').read_bytes())
  if a.verb=='status':status(out,URL)
  elif a.verb=='collect':collect(out,URL)
  else:globals()[a.verb](out,c)
