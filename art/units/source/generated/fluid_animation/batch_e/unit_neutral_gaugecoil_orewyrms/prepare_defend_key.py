"""Prepare original low-braced guard guide at one anatomical scale/ground anchor."""
import json
import numpy as np
from PIL import Image
import produce as p
O=p.SOURCE_DIR;R=p.ROOT
master=O/'defend_key_original_v1.png';im=Image.open(master).convert('RGBA');assert im.getchannel('A').getextrema()==(0,255)
def record(path):return dict(path=path.relative_to(R).as_posix(),sha256=p.sha(path))
ref=dict(name='grounded_four_leg_pressure_brace',source=master.relative_to(R).as_posix(),rects=[[0,0,*im.size]],anchor=[865,790],scale=.27,alpha_noise_cutoff=8)
p.write(O/'defend_reference.json',ref)
p.write(master.with_suffix('.generation.json'),dict(tool='built_in_imagegen',model='not exposed',date='2026-10-03',image=record(master),prompt=record(O/'defend_key_prompt_v1.txt'),references=[record(O/'move_h3_v1/guide_0_rgba.png')],review_status='Original full RGBA personally reviewed: all four low spread connected rock legs, original closed jaw and pressure hardware, compact original valve tail. Prepared guide review pending.',reference_scale_reason='One entire original painting at0.27 runtime anatomical scale, original lowest near-foot anchor790. No aspect changes, per-frame normalization, manual limb edits or transformed footage.'))
c=json.loads((O/'defend_h3_v1/config.json').read_bytes());c['seed']=2026110421;c['references']=[c['references'][0],ref];c['guides']=[[54,1]];c['last']=1
c['prompt']=('One original Gaugecoil Orewyrm SCREEN RIGHT in fixed three-quarter orthographic camera. Exactly FOUR connected short rock legs with original cleft wedge feet/brass ankle plates, segmented charcoal mineral cylindrical body/weathered brass bands/orange seams, THREE original amber pressure hardware positions and white gauges with copper/red tubing, LEFT tail with ONE original red valve wheel. No anatomical changes or new parts. Original pointed tooth-petal jaw remains fully CLOSED and opaque. '+
'From original ready smoothly bend ALL FOUR original knees outward and spread the wedge feet slightly. Keep their support contacts on the SAME fixed invisible ground plane throughout. Lower the connected mineral belly BETWEEN the planted legs, draw connected neck/head back into its armor rings, bring shoulders down close above floor, and curl original tail closer to the body without detaching its wheel. Clearly deliberate LOW and BROAD physical pressure-coil brace shown in second guide; gauges stay on original attached brackets. Finish fully crouched and HOLD that low brace to last frame. No rising, return to ready, stepping, floating, death, attack or breathing-only loop. Whole body joints move physically; same original anatomical sizes and fixed root, not a resized or shifted painting. '+
'Every foot, jaw, bulb/gauge and tail wheel remains complete inside960x544 generous margins. Entire background remains one flat magenta255,0,255 with unchanged constant light throughout. No background color changes, floor, shadow, scenery, zoom, camera motion, mouth opening, light, flash, spark, smoke, particle, projectile, beam or extra anatomy.').strip()
out=O/'defend_h3_v2';out.mkdir(exist_ok=True);assert not (out/'sampling_submission.json').exists();p.write(out/'config.json',c);p.prepare(out,c)
m=json.loads((O/'foreground_measurement.json').read_bytes());yellow=[]
for f in out.glob('guide_*_rgba.png'):
 a=np.asarray(Image.open(f).convert('RGBA')).astype(np.int16);red,green,blue=a[:,:,:3][a[:,:,3]>=240].T
 bands=dict(magenta=np.minimum(red,blue)-green,green=green-np.maximum(red,blue),blue=blue-np.maximum(red,green),cyan=np.minimum(green,blue)-red)
 m['guides'].append(dict(path=f.relative_to(R).as_posix(),sha256=p.sha(f),opaque_pixels=len(red),maximum={k:int(v.max()) for k,v in bands.items()}));yellow.extend((np.minimum(red,green)-blue)[red-green<12].tolist())
m['protected_bands']={k:max(r['maximum'][k] for r in m['guides'])+2 for k in bands};m['protected_neutral_yellow_band']=max(m['protected_neutral_yellow_band'],max(yellow)+2);p.write(O/'foreground_measurement.json',m)
d=json.loads((O/'unit_brief.json').read_bytes());d['action_guides']['defend']=['idle_hands_0',ref['name']];d['defend_key_status']='First full H3 take rejected for weak/floating guard. New original low broad four-leg brace guide prepared and pending final fixed-canvas review.';d['attack_key_status']='Repaired original closed-jaw contact guide resolved baked flashes; full attack v3 source/both-facing review passed provisionally, actual Godot acceptance pending.';p.write(O/'unit_brief.json',d)
print('ORIGINAL_GROUNDED_GUARD_PREPARED',im.size,flush=True)
