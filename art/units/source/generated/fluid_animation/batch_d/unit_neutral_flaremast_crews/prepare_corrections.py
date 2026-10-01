"""Prepare finite first action corrections without touching the shared GPU."""
import json
from pathlib import Path
import numpy as np
from PIL import Image,ImageDraw
from scipy.ndimage import binary_erosion,distance_transform_edt
import produce as p
import prepare_h3 as original

S=p.SOURCE_DIR
GUIDES={
 'support_signal_v1':('exec-ea65cb89-9360-47c3-9fa4-900d0f3f7fd1.png',['move_h3_v1/guide_0_rgba.png'],'pending_h3_motion'),
 'death_corpse_v1':('exec-32cd9196-965f-4456-a085-7e6761d5ec3b.png',['move_h3_v1/guide_0_rgba.png'],'rejected_oversized_mast'),
 'death_corpse_v2':('exec-4134c1d3-38ef-4629-b328-a4ec97c6fb37.png',['death_corpse_v1.png'],'pending_h3_motion'),
 'death_kneel_v1':('exec-7856fa76-dee8-4a8e-a9a2-be6172ba490e.png',['move_h3_v1/guide_0_rgba.png','death_corpse_v2.png'],'rejected_added_wooden_stock_and_floating_tripod')}

def provenance():
 for name,(output,refs,status) in GUIDES.items():
  if not (S/(name+'.png')).exists():continue
  p.write(S/(name+'.generation.json'),dict(tool='built_in_image_gen',image=dict(path=(S/(name+'.png')).relative_to(p.ROOT).as_posix(),sha256=p.sha(S/(name+'.png'))),prompt=dict(path=(S/(name+'.prompt.txt')).relative_to(p.ROOT).as_posix(),sha256=p.sha(S/(name+'.prompt.txt'))),references=[dict(path=(S/f).relative_to(p.ROOT).as_posix(),sha256=p.sha(S/f)) for f in refs],tool_output_path='C:/Users/acorp/.codex/generated_images/01a0f615-12f8-7b30-9f1c-efd795ebd397/'+output,review_status=status))

def guide_matte(name):
 """Uniform green unmix, then remove measured excess spill near alpha boundary."""
 path=S/(name+'.png');im=Image.open(path).convert('RGB')
 rgba,detail=p.key(im,dict(key_rgb=[0,255,0],protected_foreground_chroma=24))
 a=np.asarray(rgba).copy();rgb=a[:,:,:3].astype(float)
 # Original eroded opaque ready palette has green-max(R,B)<=14. Any excess
 # green in a six-source-pixel silhouette band is chroma plate spill. Geometry
 # and original alpha remain untouched; opaque costume interior is protected.
 boundary=distance_transform_edt(a[:,:,3]>=250)<=6
 excess=np.maximum(rgb[:,:,1]-np.maximum(rgb[:,:,0],rgb[:,:,2])-14,0)*boundary
 rgb[:,:,1]-=excess;a[:,:,:3]=np.clip(rgb,0,255).astype('uint8')
 target=S/(name+'_matte.png');Image.fromarray(a,'RGBA').save(target)
 recipe=dict(original=dict(path=path.relative_to(p.ROOT).as_posix(),sha256=p.sha(path)),rgba=dict(path=target.relative_to(p.ROOT).as_posix(),sha256=p.sha(target)),protected_foreground_chroma=24,original_ready_green_max=14,boundary_despill_source_pixels=6,spill_rule='Only green excess above measured original band14 near silhouette. Alpha and geometry unchanged.',changed_spill_pixels=int(np.count_nonzero(excess)),matte=detail,rebuild='H:/ai/envs/minimax-h3/python.exe '+(S/'prepare_corrections.py').relative_to(p.ROOT).as_posix())
 p.write(S/(name+'_matte.json'),recipe)
 raw=json.loads((S/(name+'.generation.json')).read_bytes())
 raw['image']=recipe['rgba'];raw['matte_recipe']=dict(path=(S/(name+'_matte.json')).relative_to(p.ROOT).as_posix(),sha256=p.sha(S/(name+'_matte.json')));raw['original_image']=recipe['original']
 p.write(S/(name+'_matte.generation.json'),raw)

def master(name,anchor,scale):
 path=S/(name+'.png');w,h=Image.open(path).size
 return dict(name=name,source=path.relative_to(p.ROOT).as_posix(),rects=[[0,0,w,h]],anchor=anchor,scale=scale,alpha_noise_cutoff=8)

def prepare():
 corrections={}
 for clip in ['move','attack','ranged']:
  c=json.loads((S/(clip+'_h3_v2')/'config.json').read_bytes())
  c['prompt']=c['prompt'].replace('pure blue RGB0,0,255','pure green RGB0,255,0')
  corrections[clip]=c
 common=json.loads((S/'hit_h3_v1/config.json').read_bytes())
 for clip in ['hit','defend','cast','death']:
  c=dict(common,clip=clip,seed=2026100210+['move','attack','ranged','hit','defend','cast','death'].index(clip),references=[original.ref(0)],guides=[],last=0)
  action=''
  if clip=='hit':
   c['references'].append(master('hit_recoil_v4_matte',[740,920],.247))
   c['guides']=[[35,1],[52,1]]
   action='The mast stays deployed upright and stationary at screen left. Recoil once from an outside impact: head and shoulders tilt backward, both elbows bend, knees flex and the launcher stays lowered toward the ground throughout. Match supplied backward recoil midpoint, maintain both hand grips. Boots stay planted. Recover to ready. This is being struck, no aim, firing, flash, recoil from shooting, smoke or projectile.'
  elif clip=='defend':
   c['last']=None
   action=original.TAKES['defend_h3_v1'][3]+' Keep the one launcher brass with its red chamber attached; do not turn it into a rifle.'
  elif clip=='cast':
   c['references'].append(master('support_signal_v1_matte',[740,910],.312))
   c['guides']=[[38,1],[64,1]]
   action='The mast stays stationary at screen left. Make one practical ready signal: LEFT hand firmly supports the same brass launcher low, RIGHT hand releases its trigger grip and lifts an EMPTY OPEN palm beside the head, matching midpoint. Hold signal briefly then lower the right hand and restore its trigger grip. Do not check or remove ammunition. RED CHAMBER remains attached to launcher throughout, brass geometry unchanged, no wooden stock, no cylinder in the empty hand, no firing or magic.'
  else:
   c['references'].append(master('death_corpse_v2_matte',[592,675],.212))
   c['last']=1
   action='Slow continuous physical collapse into the supplied grounded corpse. Knees buckle and lower to the ground, torso slumps to screen-left, left elbow supports the body then shoulder and hip lower directly onto the same ground, finally both legs rest. No jump or roll in midair. Keep face, cap, goggles, two arms/two legs and brass RED CHAMBER launcher unchanged. The ONE deployed mast falls RIGHTWARD with gravity, rotating rigidly about its screen-left tripod ground contact until it lies horizontally BEHIND the body, tripod LEFT and finial RIGHT as in endpoint. Its red orange blue canisters stay attached with their original size/order; no detached pieces. Mast stays full original length. End motionless on ground. Body and equipment never levitate, rise or slide sideways.'
  c['prompt']=(original.IDENTITY+action+original.PLATE.replace('pure magenta RGB255,0,255','pure green RGB0,255,0')).strip()
  corrections[clip]=c
 thumbs=[]
 for clip,c in corrections.items():
  c['key_rgb']=[0,255,0];out=S/(clip+'_h3_v2');out.mkdir(exist_ok=True)
  p.prepare(out,c);bands=[]
  for i in range(len(c['references'])):
   im=Image.open(out/f'guide_{i}_rgba.png');a=np.asarray(im).astype(float);mask=binary_erosion(a[:,:,3]>240,iterations=3)
   chroma=a[:,:,1]-np.maximum(a[:,:,0],a[:,:,2]);bands.append(float(chroma[mask].max()));thumbs.append((clip+':'+str(i),im.copy()))
  c['protected_foreground_chroma']=max(0,int(max(bands))+2)
  c['foreground_measurement']=dict(rule='Original green-minus-max(red,blue) eroded opaque maximum plus two.',per_guide_max=bands)
  assert c['protected_foreground_chroma']<80,(clip,bands)
  p.write(out/'config.json',c);p.verify(out,c)
 sheet=Image.new('RGB',(1440,((len(thumbs)+3)//4)*280),(38,42,40));d=ImageDraw.Draw(sheet)
 for j,(name,im) in enumerate(thumbs):
  im.thumbnail((356,253));x,y=j%4*360,j//4*280;sheet.paste(im,(x,y+24),im);d.text((x+4,y+4),name)
 sheet.save(p.ROOT/'.artifacts/flaremast_h3/correction_guides.png')
 p.write(S/'correction_queue.json',dict(unit_id=original.UID,takes=[clip+'_h3_v2' for clip in corrections],status='prepared_pending_coordinator_gpu_go',rebuild='prepare_corrections.py',rule='First finite action correction; preserve every rejected original. No GPU side effects while preparing.'))

if __name__=='__main__':
 provenance()
 for name in ['hit_recoil_v4','support_signal_v1','death_corpse_v2']:guide_matte(name)
 prepare()
