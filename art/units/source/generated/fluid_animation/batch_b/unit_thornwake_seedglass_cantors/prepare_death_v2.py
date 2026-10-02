"""Correct abrupt v1 death guide jumps using original start/end guidance only."""
import json
import numpy as np
from PIL import Image
import produce as p
from prepare import ref,IDENTITY,PLATE
out=p.SOURCE_DIR/'death_h3_v2';out.mkdir(exist_ok=True)
assert not (out/'submission.json').exists()
c=json.loads((p.SOURCE_DIR/'death_h3_v1/config.json').read_bytes())
c.update(seed=2026102807,references=[ref(18),ref(17)],guides=[],last=1)
c['prompt']=(IDENTITY+'One smooth slow collapse through continuously moving joints. Start lowering hips and bending BOTH knees immediately, with the same body size. Sink onto bent knees, lose balance and roll forward onto the right side. Continuously lower and turn the original LEFT-hand bow with the falling arm until the bow lies horizontally on the ground in front of the chest. HEAD and antlers finish SCREEN RIGHT, both root feet extend SCREEN LEFT. Right free hand helps brace the descent then rests against body. Original feet, hips, knees, chest and head traverse every intermediate height and angle with clear weight transfer; leaf layers follow the body and settle. No sudden pose cuts, freezing then teleporting, shrinking body, hovering upright bow, detached hand or extra limbs. Finish fully grounded with original equipment; final second is still. '+PLATE).strip()
p.prepare(out,c)
values=[]
for i in range(2):
 a=np.asarray(Image.open(out/f'guide_{i}_rgba.png')).astype(int);values.append(int((a[:,:,2]-np.maximum(a[:,:,0],a[:,:,1]))[a[:,:,3]>=245].max()))
c['protected_foreground_chroma']=max(values)+2;p.write(out/'config.json',c);p.verify(out,c)
p.write(out/'foreground_measurement.json',dict(blue_minus_max_red_green=values,opaque_alpha_minimum=245,margin=2,protected_foreground_chroma=c['protected_foreground_chroma']))
p.write(p.SOURCE_DIR/'death_h3_v1/review.json',dict(status='rejected',reason='Original frames22->23 jump directly from upright to kneeling;45->46 jump from supported forward tilt to prone. Final corpse/equipment are correct, but intermediate descent is not continuous.',correction='Use original ready/corpse references and continuous-action prompt without intermediate temporal guides; preserve rejected original footage.'))
print('death_h3_v2 prepared; first take retained and rejected')
