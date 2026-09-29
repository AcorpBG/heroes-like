"""Replace the failed sweep interval using an original clean intermediate pose."""
import json
from PIL import Image
import produce as p
from prepare import IDENTITY,PLATE,ref

if __name__=='__main__':
 out=p.SOURCE_DIR/'attack_strike_h3_v3';out.mkdir(exist_ok=False)
 p.write(p.SOURCE_DIR/'attack_h3_v2/rejection.json',dict(status='rejected',frames=list(range(36,50)),defect='White motion trail instead of removed cyan trail. Prompt-only correction did not establish a clean solid-blade strike.',correction='Reassess guidance: new original bent-elbow midpoint and a dedicated windup-to-contact video. Preserve valid anticipation/recovery from v1; do not erase any trail pixels.'))
 source=p.SOURCE_DIR/'keypose/attack_midarc_rgba.png';w,h=Image.open(source).size
 middle=dict(source=source.relative_to(p.ROOT).as_posix(),rects=[[0,0,w,h]],anchor=[720,874],scale=.32,alpha_noise_cutoff=0)
 c=json.loads((p.SOURCE_DIR/'attack_h3_v1/config.json').read_bytes())
 c.update(seed=2026092911,references=[ref(5),middle,ref(6)],guides=[[56,1]],last=2)
 c['prompt']=IDENTITY+(
  'A slow controlled arm-position demonstration from the first pose to the last pose, with no return or extra movement. '
  'At first the right elbow is raised and bent with the short hook above the shoulder. '
  'Lower the right wrist slightly across the chest into the middle reference pose, keeping the right elbow bent. '
  'Then extend that right elbow forward toward screen right and lower the hand to chest height into the final reference pose. '
  'The left hand and forearm keep the wooden buckler at the ribs. Both boots remain planted while the front knee loads slightly. '
  'The small curved steel hook and brown handle are rigid physical objects. Only their physical position changes, at an unhurried demonstration pace. '
  'Every moment shows one sharply painted short hooked knife and clean empty blue space around it. '
  'No motion effect of any kind, no trail, arc, sweep graphic, light, white streak, cyan glow, ribbon, blur, enlargement or duplicate outline. '
  'Finish holding the forward extended knife exactly like the last reference.'
 )+PLATE
 p.prepare(out,c);p.write(out/'config.json',c)
