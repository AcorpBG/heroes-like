"""Reproducible one-action-at-a-time MiniMax H3 candidate producer."""
from __future__ import annotations
import argparse, hashlib, io, json, time, urllib.request, urllib.parse
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw

ROOT=Path(__file__).resolve().parents[6]
OUT=Path(__file__).resolve().parent
UNIT='unit_thornwake_stagknot_runners_veteran'
URL='http://127.0.0.1:8189'
W,H=960,544
INPUT_SCALE=.5
INPUT_ANCHOR=(480,492)
REFERENCE_HEIGHT=256
RUNTIME_SCALE=.4453125/INPUT_SCALE
SOURCES=ROOT/'art/animation/source/poses'/UNIT
POSE=Image.open(SOURCES/f'{UNIT}-alpha.png').convert('RGBA')
ACT=Image.open(SOURCES/f'{UNIT}_actions-alpha.png').convert('RGBA')
PACK=json.loads((SOURCES/'packing.json').read_text(encoding='utf-8-sig'))
GEN=OUT/'key_guides'

POSE_RECTS=[(0,0,648,599),(648,0,1305,599),(0,599,662,1205),(662,599,1305,1205)]
POSE_ANCHORS=[(349,542),(938,543),(354.5,1166),(971,1167)]
ACT_RECTS={'attack_windup':(0,0,625,612),'attack_release':(625,0,1306,612),'hit_recoil':(0,612,603,1205),'fallen':(603,612,1306,1205)}
ACT_ANCHORS={'attack_windup':(252,599),'attack_release':(943.5,595),'hit_recoil':(276.5,1158),'fallen':(950,1146)}
GUIDE_FILES={
 'move':'antlerloom_move_stride.png', 'defend':'antlerloom_defend_brace.png', 'cast':'antlerloom_support_rally.png'
}
PROMPTS={
 'idle':('A locked-camera fantasy strategy battle idle loop of this exact Antlerloom Strider. Preserve the four-legged wooden stag, ivory bark face and armor, branching antlers with rounded green foliage and white blossoms, amber chest gem, pale-green hanging leaf panels, dark wood/vine legs and hooves, right-facing three-quarter camera and exact scale. All FOUR legs remain grounded at their same hoof spots. Make clearly visible anatomical idle articulation: slow neck/head raise and lower, jaw opens slightly once, subtle chest breathing, small antler foliage/leaves settle; no root translation. Return smoothly to the exact starting pose at the end. No walking or turning.'),
 'move':('Animate a reciprocal quadruped walk-in-place cycle for the exact four-legged Antlerloom Strider. Keep body centered, same size and right-facing camera; do not translate the root. Precisely four legs: alternate near/far foreleg support and extension against opposing hind-leg push-off, with real loading, passing, hoof lift and contact, while torso/head stay coherent. Preserve antlers, blossoms, ivory bark, amber chest gem and hanging leaves. Finish at the same gait phase as the first frame.'),
 'attack':('The melee Antlerloom Strider attacks with its body and antlers. Preserve the exact four-legged stag and equipment, same scale/camera. Show readable anticipation: braces rear legs and draws head/antlers back; then pushes forward with a controlled head-and-antler jab toward an imaginary nearby target; contact; then recoil and settle back to ready. Four legs remain anatomically correct and support the body. No weapon, projectile, magic, extra creature, root translation or turn. Preserve full antlers.'),
 'hit':('The exact four-legged Antlerloom Strider takes one brief physical impact to the shoulder/chest. Show a compact torso recoil and slight neck-base flex; the head moves only a little and the entire branching antler structure, every green foliage pad and white blossom remain rigid and unchanged in shape and count. Near foreleg lifts briefly while the other three limbs support, hoof returns, and it recovers to the exact ready proportions. Keep torso/head size, legs and root fixed; no skull elongation, antler growth, branch rearrangement, collapse, attacker, effects or root translation.'),
 'defend':('The exact four-legged Antlerloom Strider braces defensively: lowers its body by flexing its real four legs, plants all four hooves, lowers head/antlers forward protectively, and holds the guard clearly through the final frame. Preserve its original face, antlers, leaves, chest gem, colors, camera and scale. No weapon, shield, magic, opponent, turning, hoof sliding or extra anatomy.'),
 'cast':('The melee Antlerloom Strider gives a physical ally-rally support gesture, not a spell: gently lift chest and head a little, proudly angle the branching antlers slightly upward, hold briefly, then return to ready. All four hooves stay planted. Preserve exact identity, body scale and camera. No projectile, glow, ranged magic, weapon, other character or root translation.'),
 'death':('A continuous grounded death of the exact four-legged wooden Antlerloom Strider. It loses support, knees buckle, front half sinks and rotates to its side, antlers lower to ground without detaching, torso and all four legs collapse with physical weight, then it rests motionless as a corpse. Preserve identity, scale, antlers, blossoms, foliage, amber gem and all four limbs. The last frame is the grounded dead body. No recovery, disappearing, camera motion, extra anatomy or effects.')}

def write(p,o): p.write_text(json.dumps(o,indent=2)+'\n',encoding='utf-8')
def sha(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def node(kind,**inputs): return {'class_type':kind,'inputs':inputs}
def request(route,data=None):
 body=json.dumps(data).encode() if data is not None else None
 req=urllib.request.Request(URL+route,data=body,headers={'Content-Type':'application/json'})
 try:
  with urllib.request.urlopen(req,timeout=120) as r:return json.load(r)
 except urllib.error.HTTPError as e:
  raise RuntimeError(f'HTTP {e.code} {route}: {e.read().decode("utf-8",errors="replace")}') from e
def crop_original(which):
 if isinstance(which,int): im=POSE; rect=POSE_RECTS[which]; ax,ay=POSE_ANCHORS[which]; name=f'idle_{which}'
 else: im=ACT; rect=ACT_RECTS[which]; ax,ay=ACT_ANCHORS[which]; name=which
 cut=im.crop(rect)
 return cut, (ax-rect[0],ay-rect[1]), name, f'art/animation/source/poses/{UNIT}/{UNIT+"-alpha.png" if isinstance(which,int) else UNIT+"_actions-alpha.png"}'
def guide(which,folder,name):
 if isinstance(which,str) and which.endswith('.png'):
  src=Image.open(GEN/which).convert('RGBA')
  if src.getchannel('A').getextrema()[0] != 0:
   # Built-in output has a black display canvas; trim via alpha only when it is genuinely present.
   raise ValueError(f'key guide must retain transparency: {which}')
  bounds=src.getchannel('A').getbbox(); src=src.crop(bounds)
  # The generated masters use the original pose-sheet canvas, about 2x the single pose crop.
  # One fixed source-specific scale (not per-pose bounding-box normalization) gives the
  # same body size as the original poses at INPUT_SCALE.
  scale=INPUT_SCALE*.40
  px=src.resize((round(src.width*scale),round(src.height*scale)),Image.Resampling.LANCZOS)
  comp=Image.new('RGBA',(W,H),(255,0,255,255)); comp.alpha_composite(px,(INPUT_ANCHOR[0]-px.width//2,INPUT_ANCHOR[1]-px.height))
  meta={'kind':'imagegen_key_pose','file':which,'source_sha256':sha(GEN/which),'placement_scale':scale}
 else:
  src,anchor,frame_name,source=crop_original(which)
  px=src.resize((round(src.width*INPUT_SCALE),round(src.height*INPUT_SCALE)),Image.Resampling.LANCZOS)
  comp=Image.new('RGBA',(W,H),(255,0,255,255)); comp.alpha_composite(px,(round(INPUT_ANCHOR[0]-anchor[0]*INPUT_SCALE),round(INPUT_ANCHOR[1]-anchor[1]*INPUT_SCALE)))
  meta={'kind':'original_pose_guide','source':source,'frame':frame_name,'rect':list(src.getbbox() or (0,0,*src.size)),'source_sha256':sha(ROOT/source),'source_scale':INPUT_SCALE,'source_anchor':list(anchor)}
 path=folder/f'{name}_guide.png'; comp.convert('RGB').save(path)
 meta.update(path=path.relative_to(ROOT).as_posix(),sha256=sha(path),canvas=[W,H],background='flat magenta RGB 255,0,255',ground_anchor=list(INPUT_ANCHOR))
 return path,meta
def base_action(action):
 for suffix in ('_v2','_v3'):
  if action.endswith(suffix): return action[:-len(suffix)]
 return action
def guide_plan(action):
 base=base_action(action)
 if action=='attack_v2': return (0,'attack_release',0)
 if action in ('cast_v2','cast_v3'): return (0,0)
 return {
 'idle':(0,2,0), 'move':(0,GUIDE_FILES['move'],0), 'attack':(0,'attack_windup','attack_release',0),
 'hit':(0,'hit_recoil',0), 'defend':(0,GUIDE_FILES['defend'],GUIDE_FILES['defend']),
 'cast':(0,GUIDE_FILES['cast'],0), 'death':(0,'hit_recoil','fallen')
 }[base]
def verify_prepared(action):
 folder=OUT/action
 guides=json.loads((folder/'guides.json').read_text(encoding='utf-8'))
 expected=[str(x) for x in guide_plan(action)]
 if guides.get('guide_plan')!=expected:
  raise RuntimeError(f'{action}: recorded guide plan {guides.get("guide_plan")} != intended {expected}')
 graph=json.loads((folder/'workflow_api.json').read_text(encoding='utf-8'))
 metas=guides['guides']; ids=[str(4+i) for i in range(len(metas))]
 sub_path=folder/'submission.json'; uploaded=json.loads(sub_path.read_text(encoding='utf-8')).get('uploaded',[]) if sub_path.exists() else []
 for i,(node_id,meta) in enumerate(zip(ids,metas)):
  node=graph.get(node_id,{})
  if node.get('class_type')!='LoadImage': raise RuntimeError(f'{action}: missing LoadImage {node_id}')
  actual=Path(node['inputs']['image']).name
  expected_file=uploaded[i]['name'] if i<len(uploaded) else Path(meta['path']).name
  if actual!=expected_file: raise RuntimeError(f'{action}: guide {node_id} uses {actual}, expected {expected_file}')
 i2v=graph.get('20',{}).get('inputs',{})
 if i2v.get('first_frame')!=[ids[0],0] or i2v.get('last_frame')!=[ids[-1],0]:
  raise RuntimeError(f'{action}: I2V endpoint guide wiring differs from plan')
 added=sorted((int(k),v) for k,v in graph.items() if v.get('class_type')=='MiniMaxH3AddGuide')
 if len(added)!=len(metas)-2: raise RuntimeError(f'{action}: expected {len(metas)-2} intermediate guides, found {len(added)}')
 for (_,node),guide_id in zip(added,ids[1:-1]):
  if node.get('inputs',{}).get('image')!=[guide_id,0]: raise RuntimeError(f'{action}: intermediate guide wiring differs for {guide_id}')
 prompt=(folder/'prompt.txt').read_text(encoding='utf-8').strip()
 if i2v.get('prompt')!=prompt: raise RuntimeError(f'{action}: workflow prompt does not match prompt.txt')
 return True

def prepare(action,seed):
 base=base_action(action)
 folder=OUT/action; folder.mkdir(parents=True,exist_ok=True); GEN.mkdir(parents=True,exist_ok=True)
 if (folder/'submission.json').exists(): raise RuntimeError('already submitted; never enqueue a duplicate')
 plan=guide_plan(action); paths=[]; meta=[]
 names=['first','windup','contact','last'] if len(plan)==4 else (['first','last'] if len(plan)==2 else ['first','middle','last'])
 for i,source in enumerate(plan):
  p,m=guide(source,folder,names[i]); paths.append(p); meta.append(m)
 prompt=('Locked three-quarter right-facing orthographic camera. Every pixel outside the creature must remain the same perfectly flat pure magenta RGB(255,0,255) in every frame. Do not tint, animate, shade, gradient, relight or replace this background. No ground or shadow. '+PROMPTS[base]+' The supplied first, intermediate and last frames are the same original creature at one anatomical scale and ground reference. Preserve the guide proportions and interpolate only physically coherent motion between them. Keep full antlers and all four hooves inside frame. No scenery, text, haze or unrelated effects.')
 if action in ('cast_v2','cast_v3'): prompt+=' Keep the pale ivory face and pointed muzzle continuously clear and identical; move only the neck base and chest slightly, without a deep bow or low-leg crouch. Keep every antler branch, rounded leafy pad and white blossom in exactly the same shape, size and count; do not lengthen branches or stretch foliage into blades. Preserve head and torso scale and all four planted legs.'
 if base=='move': prompt+=' Keep the original torso-to-head size and antler-to-shoulder size constant throughout. Root center stays at x=480 and planted support hoof baseline at y=492; no camera zoom, subject growth, whole-body widening or root drift. Show true reciprocal gait: near foreleg contacts while far foreleg passes, then far foreleg contacts while near foreleg passes; alternate hind-leg support in opposition.'
 (folder/'prompt.txt').write_text(prompt+'\n',encoding='utf-8')
 write(folder/'guides.json',dict(action=action,guides=meta,guide_plan=list(map(str,plan)),input_scale=INPUT_SCALE,runtime_scale=RUNTIME_SCALE,source_reference=f'art/animation/source/poses/{UNIT}/{UNIT}-alpha.png',source_sha256=sha(SOURCES/f'{UNIT}-alpha.png'),seed=seed))
 graph={'1':node('UNETLoader',unet_name='minimax_h3_fl2va_pruned_int8_convrot.safetensors',weight_dtype='default'),'2':node('CLIPLoader',clip_name='qwen3vl_32b_minimax_h3_nvfp4_awq.safetensors',type='minimax',device='default'),'3':node('VAELoader',vae_name='minimax_h3_video_vae_int8_convrot.safetensors')}
 for i,p in enumerate(paths,4): graph[str(i)]=node('LoadImage',image=p.name)
 graph['20']=node('MiniMaxH3ImageToVideo',clip=['2',0],vae=['3',0],prompt=prompt,width=W,height=H,length=124,first_frame=['4',0],last_frame=[str(4+len(paths)-1),0])
 previous='20'
 for idx in range(1,len(paths)-1):
  node_id=str(21+idx-1)
  graph[node_id]=node('MiniMaxH3AddGuide',positive=[previous,0],latent=['20',1],vae=['3',0],frame_idx=([36,76][idx-1] if base=='attack' else 61),image=[str(4+idx),0])
  previous=node_id
 graph['25']=node('BasicGuider',model=['1',0],conditioning=[previous,0]); graph['26']=node('RandomNoise',noise_seed=int(seed)); graph['27']=node('KSamplerSelect',sampler_name='res_multistep'); graph['28']=node('BasicScheduler',model=['1',0],scheduler='simple',steps=20,denoise=1.0); graph['29']=node('SamplerCustomAdvanced',noise=['26',0],guider=['25',0],sampler=['27',0],sigmas=['28',0],latent_image=['20',1]); graph['30']=node('VAEDecode',samples=['29',0],vae=['3',0]); graph['31']=node('CreateVideo',images=['30',0],fps=24,bit_depth=8); graph['32']=node('SaveVideo',video=['31',0],filename_prefix=f'luna_antlerloom_full/{action}/original',format='mp4',**{'format.codec':'h264'}); graph['33']=node('SaveImage',images=['30',0],filename_prefix=f'luna_antlerloom_full/{action}/frames/decoded')
 write(folder/'workflow_api.json',graph); verify_prepared(action); return folder
def submit(action):
 folder=OUT/action; verify_prepared(action); q=request('/queue')
 if q['queue_running'] or q['queue_pending']: raise RuntimeError('queue busy; leave other jobs untouched')
 graph=json.loads((folder/'workflow_api.json').read_text(encoding='utf-8'))
 uploaded=[]
 guide_names=json.loads((folder/'guides.json').read_text(encoding='utf-8'))['guides']
 for i,guide_info in zip(range(4,4+len(guide_names)),guide_names):
  name=Path(guide_info['path']).stem.replace('_guide','')
  path=folder/f'{name}_guide.png'; boundary='----LunaAntlerloomH3'
  payload=(f'--{boundary}\r\nContent-Disposition: form-data; name="image"; filename="{path.name}"\r\nContent-Type: image/png\r\n\r\n'.encode()+path.read_bytes()+f'\r\n--{boundary}--\r\n'.encode())
  req=urllib.request.Request(URL+'/upload/image',data=payload,headers={'Content-Type':'multipart/form-data; boundary='+boundary})
  with urllib.request.urlopen(req,timeout=60) as r:u=json.load(r)
  uploaded.append(u); graph[str(i)]['inputs']['image']='/'.join(x for x in (u.get('subfolder',''),u['name']) if x)
 write(folder/'workflow_api.json',graph); started=time.time(); result=request('/prompt',{'prompt':graph,'client_id':'luna_antlerloom_full'})
 write(folder/'submission.json',dict(**result,started_unix=started,uploaded=uploaded,url=URL)); print(json.dumps(result))
def status(action):
 folder=OUT/action; sub=json.loads((folder/'submission.json').read_text()); pid=sub['prompt_id']; h=request('/history/'+pid)
 if pid not in h: print(json.dumps({'state':'running','elapsed_seconds':round(time.time()-sub['started_unix'])})); return
 write(folder/'generation_history.json',h[pid]); print(json.dumps({'status':h[pid]['status'],'outputs':list(h[pid].get('outputs',{}))}))
def fetch(item):
 with urllib.request.urlopen(URL+'/view?'+urllib.parse.urlencode({k:item[k] for k in ('filename','subfolder','type') if k in item}),timeout=120) as r:return r.read()
def collect(action):
 import av
 folder=OUT/action; result=json.loads((folder/'generation_history.json').read_text())
 if result['status']['status_str']!='success': raise RuntimeError('H3 generation did not succeed')
 images=result['outputs']['33']['images']; assert len(images)==124
 video=folder/'original_lossless.mkv'; decoded=[]
 with av.open(str(video),'w') as c:
  stream=c.add_stream('ffv1',rate=24);stream.width=W;stream.height=H;stream.pix_fmt='bgr0'
  for item in images:
   im=Image.open(io.BytesIO(fetch(item))).convert('RGB'); decoded.append(hashlib.sha256(im.tobytes()).hexdigest())
   for pkt in stream.encode(av.VideoFrame.from_image(im)):c.mux(pkt)
  for pkt in stream.encode():c.mux(pkt)
 for items in result['outputs'].get('32',{}).values():
  if isinstance(items,list):
   for item in items:
    if isinstance(item,dict) and item.get('filename','').endswith('.mp4'):(folder/'original.mp4').write_bytes(fetch(item))
 write(folder/'original.json',dict(frame_count=len(decoded),fps=24,size=[W,H],codec='FFV1/bgr0',source_frames_rgb_sha256=decoded,lossless_sha256=sha(video),workflow_sha256=sha(folder/'workflow_api.json'),collected_unix=time.time()))
 print(f'Collected {len(decoded)} lossless source frames for {action}')
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('verb',choices=['prepare','submit','status','collect','verify']);p.add_argument('action',choices=['idle','move','move_v2','attack','attack_v2','hit','hit_v2','defend','defend_v2','cast','cast_v2','cast_v3','death','death_v2']);p.add_argument('--seed',type=int,default=20260924)
 a=p.parse_args(); folder=prepare(a.action,a.seed) if a.verb=='prepare' else None
 if a.verb=='verify': print(json.dumps({'action':a.action,'valid':verify_prepared(a.action)}))
 if a.verb=='submit':submit(a.action)
 elif a.verb=='status':status(a.action)
 elif a.verb=='collect':collect(a.action)
