"""Retain rejected rifle recovery and add one original forward-held return guide."""
import json
from PIL import Image
import produce as p

if __name__=='__main__':
 old=p.SOURCE_DIR/'attack_h3_v1';out=p.SOURCE_DIR/'attack_h3_v2';out.mkdir(exist_ok=True)
 assert not (out/'sampling_submission.json').exists(),'Submitted original is immutable'
 master=p.SOURCE_DIR/'attack_return_v1.png';im=Image.open(master);assert im.mode=='RGBA' and im.size==(1536,1024)
 f=dict(name='forward_held_rifle_recovery',source=master.relative_to(p.ROOT).as_posix(),rects=[[0,0,*im.size]],anchor=[772,929],scale=.238,alpha_noise_cutoff=8)
 c=json.loads((old/'config.json').read_bytes());c['seed']=2026108712;c['references'].append(f);c['guides']=[[34,1],[60,2],[94,3]]
 c['prompt']=c['prompt'].replace('Near right hand keeps stock/trigger grip; far left hand supports forward barrel.','Two visible gloves remain attached to the single rifle throughout; at ready/recovery the near hand grips stock/trigger and the far hand supports the forward barrel. Both hands turn and, where necessary, make a short controlled regrip along this same rifle through the original windup/contact poses.').replace('exact two grips','two visible attached hands and original endpoint grips')
 c['prompt']=c['prompt'].replace('Lift the ONE rifle sideways across chest into original windup, keeping both grips.','Turn the ONE rifle at chest height directly into the original windup, with both gloves visibly attached. Keep its entire rotation in front of the torso, never above or behind the head.').replace('then draw same rifle back and recover exact ready.','then immediately retract the same rifle while both hands visibly hold it. Turn into the forward-held diagonal-up-right recovery guide and lower smoothly to exact ready. The near trigger glove and far barrel-support glove remain visibly connected to the rifle, including the entire recovery. Never raise it behind the head or leave hands settled while the rifle floats.').replace('No firing and no repeated strike.','The wooden stock delivers only one blunt physical shove; no trigger pull, firing gesture, flash, projectile, sparks, impact star, blast ring or illuminated costume. No repeated strike.')
 record=lambda path:dict(path=path.relative_to(p.ROOT).as_posix(),sha256=p.sha(path))
 p.write(master.with_suffix('.generation.json'),dict(image=record(master),prompt=record(p.SOURCE_DIR/'attack_return_v1.prompt.txt'),references=[record(old/f'guide_{i}_rgba.png') for i in range(3)],tool='built-in image_gen',original_tool_path='C:/Users/acorp/.codex/generated_images/01a0fd4e-7754-7a91-8e06-2b328cba8526/exec-d715c462-1745-4598-9a4f-22929d97b668.png',registration=f,review='Personally inspected full original master: exactly two gloves attached at stock/trigger and forward barrel, one rifle in front of chest pointing up/right, original two planted legs/face/court coat/hair/knee guards/boots. Alpha noise below8 excluded only by source extraction; intact master retained. One .238 whole-source anatomical scale with[772,929] original near-boot ground, never frame normalization.'))
 rejected=json.loads((p.SOURCE_DIR/'rejected_takes.json').read_bytes())
 if not any(r['take']=='attack_h3_v1' for r in rejected['takes']):
  rejected['takes'].append(dict(take='attack_h3_v1',reason='Personally inspected all124 RGB and124RGBA chronologically plus enlarged rotation/contact/recovery. Frame22 duplicates orange muzzle;72-83 invent firing effects during a stock shove. Recovery110-113 raises rifle behind head while hands settle early, breaking grip continuity. Reject full action rather than conceal its recovery with a frame jump; preserve originals/latent/matte recipe.',correction='attack_return_v1.png original two-grip forward-held recovery guide and full attack_h3_v2 with34windup/60contact/94return'))
 p.write(p.SOURCE_DIR/'rejected_takes.json',rejected)
 delivery=json.loads((p.SOURCE_DIR/'delivery.json').read_bytes());delivery['takes']=['attack_h3_v2' if t=='attack_h3_v1' else t for t in delivery['takes']]
 p.write(p.SOURCE_DIR/'delivery.json',delivery);p.write(out/'config.json',c);p.prepare(out,c);p.verify(out,c)
