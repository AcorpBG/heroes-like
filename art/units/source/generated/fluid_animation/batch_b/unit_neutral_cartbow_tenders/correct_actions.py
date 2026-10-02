"""Repair missing opposed walking control and unwanted recoil effects."""
import json,copy
import numpy as np
from PIL import Image
import prepare as base
import produce as p

def main():
 master=p.SOURCE_DIR/'move-opposed-v1.png';prompt=master.with_suffix('.prompt.txt')
 references=[p.SOURCE_DIR/'move_h3_v1/guide_0_rgba.png',p.ROOT/'art/units/source/curated/unit_neutral_cartbow_tenders.png']
 p.write(master.with_suffix('.generation.json'),dict(image=master.relative_to(p.ROOT).as_posix(),image_sha256=p.sha(master),prompt_file=prompt.relative_to(p.ROOT).as_posix(),prompt_sha256=p.sha(prompt),tool='built-in image_gen',original_output='C:/Users/acorp/.codex/generated_images/01a0965d-a98e-7560-8e9d-802269b3760b/exec-d1c7757c-5f1f-46bd-8ce1-2da294d770cb.png',references=[dict(path=f.relative_to(p.ROOT).as_posix(),sha256=p.sha(f)) for f in references],review='Two independently painted opposite-leg contact/passing guides, two human arms and legs, intact two-wheel loaded cart and original camera/costume. One fixed .275 source scale; no warped or fabricated articulation.'))
 # Wheel ground728/731 and operator hip columns550/1386 correspond to the
 # original shared anchor. Only placement/whole-image scale, no pose warps.
 new=[]
 for name,rect,anchor in [('near_contact',[300,20,993,744],[550,730]),('near_passing',[1135,20,1850,748],[1386,730])]:
  new.append(dict(name=name,source=master.relative_to(p.ROOT).as_posix(),rects=[rect],anchor=anchor,scale=.275,alpha_noise_cutoff=8,crop_recipe=dict(kind='original_two_cutout_guides',reason='Separate observed opaque figures across empty central gap; preserve complete hands, boots, bow tips and wheels.')))
 c=copy.deepcopy(json.loads((p.SOURCE_DIR/'move_h3_v1/config.json').read_bytes()));c['seed']=2026101011;c['references']=[base.ref(17),base.ref(3),new[1],new[0]];c['guides']=[[24,1],[48,2],[72,3],[96,1]];c['last']=0
 c['prompt']=(base.IDENTITY+' One slow complete reciprocal walking cycle in place, explicitly follow original opposed-leg guides24,48,72,96. From ready, near prominent-kneepad leg lifts backward24 then swings FORWARD with knee flexed48 while far foot supports. Near boot PLANTS forward72 while FAR leg is lifted behind, then far boot swings forward and plants96 as near leg moves back into original ready. BOTH feet must alternate contact, toe-off, passing and landing. No one-leg hopping or permanently planted far foot. Both hands keep original cart grips; two spoked wheels roll forward on their fixed centered axle, bow stays loaded. Camera/root and human proportions fixed. End exact original ready.'+base.PLATE).strip();prepare_take('move_h3_v2',c)
 c=copy.deepcopy(json.loads((p.SOURCE_DIR/'hit_h3_v1/config.json').read_bytes()));c['seed']=2026101012
 c['prompt']=(base.IDENTITY+' One deliberate balance-and-knee-flex exercise with all equipment safely stationary. Slowly flex both knees, lean chest BACK as supplied34 pose, keep elbows bent and both hands firmly on original cart handles, then straighten knees and return naturally to ready. Clear torso lean and recovery with boots supported, exact original loaded bow/string/bolt throughout. The only visible elements are this man and his unchanged wooden cart. Plain isolated sprite motion, no additional visible objects, lines, flashes, smoke, particles, striking weapons or light effects. Two arms, two legs, two wheels, unchanged original face.'+base.PLATE).strip();prepare_take('hit_h3_v2',c)
 p.write(p.SOURCE_DIR/'rejected_takes.json',dict(move_h3_v1='Only near/rear leg swings; far leg never completes opposing swing. Replace with explicit two painted opposed-leg controls.',hit_h3_v1='Incoming red arrow15-18 and invented flash/purple swirls18-28 contaminate recoil transition. Regenerate as plain balance/knee motion, all equipment stationary.',attack_h3_v1_tail='Retain complete original loaded-cart anticipation/shove/recovery0-88 only; unwanted separate shot89-101 occurs after recovery and is excluded, no erased projectile or invented frames.',death_h3_v1_flash='Brief unwanted bow flash around50-51 under enlarged review; select only continuous original unaffected collapse poses.'))

def prepare_take(name,c):
 out=p.SOURCE_DIR/name;out.mkdir(exist_ok=True);assert not (out/'submission.json').exists();p.write(out/'config.json',c);p.prepare(out,c)
 maxima=[]
 for i in range(len(c['references'])):
  a=np.asarray(Image.open(out/f'guide_{i}_rgba.png')).astype(int);mask=a[:,:,3]>=245;maxima.append(int((a[:,:,1]-np.maximum(a[:,:,0],a[:,:,2]))[mask].max()))
 c['protected_foreground_chroma']=max(maxima)+2;p.write(out/'config.json',c);p.verify(out,c);p.write(out/'foreground_measurement.json',dict(opaque_alpha_minimum=245,original_guide_green_minus_max_red_blue=maxima,margin=2,protected_foreground_chroma=c['protected_foreground_chroma']))

if __name__=='__main__':main()
