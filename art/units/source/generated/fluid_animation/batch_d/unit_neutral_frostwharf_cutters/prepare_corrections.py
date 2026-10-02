"""Correct only first-take strike trail and incoming recoil projectile defects."""
import json
import numpy as np
from PIL import Image
import produce as p
import prepare as original

IDENTITY=original.IDENTITY.replace('One original Frostwharf Cutter,','One original dark-haired man,')
PLATE=(' Fixed elevated three-quarter orthographic camera,960x544, original body scale and centered ground root. The entire body, two boots and both short tools stay inside frame. Flat uniform saturated GREEN RGB0,255,0 fills all empty space every frame. Exactly one man and his original two metal tools on this empty chroma plate. Crisp individual painted sprite poses, sharply outlined finite opaque silver steel tools with brown grips and small curved tips throughout. ')

def config(clip,description,guides,seed):
 old=json.loads((p.SOURCE_DIR/(clip+'_h3_v1')/'config.json').read_bytes())
 c=dict(old,prompt=(IDENTITY+description+PLATE).strip(),guides=guides,seed=seed)
 out=p.SOURCE_DIR/(clip+'_h3_v2');out.mkdir(exist_ok=True);assert not (out/'submission.json').exists();p.write(out/'config.json',c);p.prepare(out,c)
 maxima=[]
 for i in range(len(c['references'])):
  a=np.asarray(Image.open(out/f'guide_{i}_rgba.png')).astype(int);mask=a[:,:,3]>=245;maxima.append(int((a[:,:,1]-np.maximum(a[:,:,0],a[:,:,2]))[mask].max()))
 c['protected_foreground_chroma']=max(maxima)+2;p.write(out/'config.json',c);p.verify(out,c)
 p.write(out/'foreground_measurement.json',dict(opaque_alpha_minimum=245,original_guide_green_minus_max_red_blue=maxima,margin=2,protected_foreground_chroma=c['protected_foreground_chroma']))
 p.write(out/'correction_brief.json',dict(original_take=clip+'_h3_v1',defect='Generated cyan sweep grew beyond original finite blade' if clip=='attack' else 'Invented projectile and impact markings before recoil',change='Plain human arm exercise with tightly supplied finite steel poses' if clip=='attack' else 'Plain solitary balance exercise; describe torso/knees without incoming event',rule='Regenerate only deficient original action; no erasing/repainting anatomy or equipment, original rejected take preserved.'))

if __name__=='__main__':
 config('attack','One continuous physical arm-and-knee exercise with two original SHORT hooked steel tools. Starting ready, smoothly raise screen-left gloved arm overhead26 while other hand holds its own hook low as guard. From26 to34 lower screen-left arm down and forward, bending elbow and rotating shoulder into supplied forward stance34. Both short steel tools retain SAME finite length, thickness and curve, each hand wraps its original brown grip. Hold the forward stance34-48. Then both arms recover through supplied upright guarded pose76 and return to original ready. Sharp crisp steel silhouette in each pose, clear separated hands, deliberate joint movement and planted boot weight transfer. The two physical tools are the only shapes moving around the hands.',[[26,1],[34,2],[48,2],[76,3]],2026102102)
 config('hit','One solitary balance exercise with ONLY the original man and his two tools. Starting ready, shoulders and head gently lean backward, knees bend and chest tilts upward toward supplied leaned posture34. Both hands keep their two short steel hooks, arms extend slightly for balance. Briefly hold backward posture, then flex waist, straighten knees and smoothly restore original upright ready. Two original feet provide sensible support; all empty space stays plain green throughout.',[[22,1],[34,1],[44,1]],2026102103)
