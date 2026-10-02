"""Correct original guide-family scale and remove misleading effect cues."""
import json
import numpy as np
from PIL import Image
import produce as p
from prepare import IDENTITY,PLATE

def correction(clip,description,seed):
 old=p.SOURCE_DIR/(clip+'_h3_v1');c=json.loads((old/'config.json').read_bytes())
 if clip in ['move','defend']:
  for f in c['references']:
   if 'tripod-creep-and-guard' in f['source']:f['scale']*=.80/.95
 identity=IDENTITY.replace('piston lance','telescoping metal spear').replace('Lance is integral to machine, never a held sword.','The solid metal spear is bolted to the front mechanism.')
 c['prompt']=(identity+description+PLATE).strip();c['seed']=seed
 out=p.SOURCE_DIR/(clip+'_h3_v2');out.mkdir(exist_ok=True);assert not (out/'submission.json').exists();p.write(out/'config.json',c);p.prepare(out,c)
 maxima=[]
 for i in range(len(c['references'])):
  a=np.asarray(Image.open(out/f'guide_{i}_rgba.png')).astype(int);band=a[:,:,1]-np.maximum(a[:,:,0],a[:,:,2]);maxima.append(int(band[a[:,:,3]>=245].max()))
 c['protected_foreground_chroma']=max(maxima)+2;p.write(out/'config.json',c);p.verify(out,c)
 p.write(out/'foreground_measurement.json',dict(original_guide_green_minus_max_red_blue=maxima,opaque_alpha_minimum=245,margin=2,protected_foreground_chroma=c['protected_foreground_chroma']))

def main():
 correction('move','A physical tripod walking cycle in place. Near screen-right foot lifts, advances and plants; far screen-left foot then lifts, advances and plants; rear-middle foot finally lifts, advances and plants. Each leg has separate loading, passing and extension while other two support. Repeat first near-foot step and settle into the original matched contact at end. Exactly three original leg chains remain attached. Keep original boiler dimensions throughout, centered chassis and straight metal spear directed horizontally right.',2026100911)
 correction('defend','Three-leg mechanical lowering and firm bracing. Slowly flex all three knee pistons and spread feet outward, lowering the boiler to the supplied low guard. Metal spear rotates upward slightly as the front housing pivots. Maintain the last low stance through the end, all three original spade feet grounded, boiler and gauge same size throughout.',2026100912)
 correction('attack','Demonstration of ONE mechanical telescoping spear stroke. Start at ready, slowly bend all three legs to load weight and pull the rigid metal spear shaft backward through its original front piston housing. At supplied extended pose push the solid straight metal shaft and its original iron triangular point forward toward screen right, briefly hold, then retract through the same housing, restore leg joints and return to original ready. The only motion is solid metal parts translating, pistons flexing and the red cloth following. Keep original orange vents constant; the spear point remains cold solid iron in every frame.',2026100913)
 correction('hit','One mechanical backward rock and recovery. Keeping the three spade feet planted, bend knees and rotate boiler and gauge tower backward into supplied leaning pose, raising the attached metal spear with torso. Pause briefly, extend knee pistons and recover upright so spear returns horizontal. Only this one isolated machine moves; surrounding green plate stays completely empty. Original mechanism and all three legs remain intact.',2026100914)
 p.write(p.SOURCE_DIR/'rejected_takes.json',dict(move_h3_v1='Tripod-family guide gauge19px versus accepted idle15px; boiler grows around early reference transition. Recalibrate entire original tripod-sheet family .95->.80, not per-video-frame.',defend_h3_v1='Same tripod guide-family scale mismatch; preserve original but regenerate at fixed corrected family scale.',attack_h3_v1='Invented firing flash29-36 obscures active spear extension; reject, do not erase or bridge active motion.',hit_h3_v1='Invented incoming drum19-23 and explosion24-31; reject, do not erase effects or omit the recoil.'))
 reg=json.loads((p.SOURCE_DIR/'runtime_registration.json').read_bytes());reg['fixed_source_family_multipliers']['continuity-alpha/tripod-creep-and-guard.png']=.80;reg['reason']='Fixed original-family boiler registration: tripod guide white gauge19x21 source-video pixels versus accepted idle15x18; .80 original family factor replaces .95. Original-poses family .90 and accepted idle1 unchanged. Maintain relative crouch/corpse anatomy; no per-frame normalization.';p.write(p.SOURCE_DIR/'runtime_registration.json',reg)

if __name__=='__main__':main()
