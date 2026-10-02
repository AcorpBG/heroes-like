"""Prepare original tripod-machine guides; H3 supplies actual motion."""
import json
import numpy as np
from PIL import Image
import produce as p
UID='unit_brasshollow_pressure_lancers'
LEGACY=p.ROOT/'art/animation/source/poses'/UID
FRAMES=json.loads((LEGACY/'packing.json').read_bytes())['frames']
IDENTITY=('One original Pressure Lancer: a brass and dark iron STEAM TRIPOD MACHINE, not a person. Exactly THREE mechanical legs: near leg screen right, far leg screen left, rear middle leg visible beneath the chassis. Each has jointed piston thigh, knee and shin with a broad metal spade foot. No arms or hands or human head. One round brass boiler torso, upright central pressure tower with white round gauge and orange slotted vents; one tall rear black chimney, one left cylindrical side boiler, brown-red hoses, fixed orange furnace lights and red fabric strip behind chimney. Exactly ONE rigid straight telescopic piston lance mounted to a circular front housing, pointing screen right, with one original broad triangular dark iron spear point and brass collar. Lance is integral to machine, never a held sword. All original joints, three feet, gauge, hoses, armor and lance retained. ')
PLATE=(' Locked original elevated three-quarter orthographic camera facing screen right. Full tripod, all three legs, entire lance point and chimney within960x544 with generous margins, unchanged boiler size and centered root. Uniform saturated GREEN RGB0,255,0 background in EVERY frame; no ground, gradient, background shadows, text, other creatures or props. Only small original chimney steam, no sparks, incoming weapons, projectiles, magic or explosions. Genuine mechanical joint articulation, no whole sprite wobble. ')

def ref(index):
 f=dict(FRAMES[index]);f['source']=(LEGACY/f['source']).relative_to(p.ROOT).as_posix();f['alpha_noise_cutoff']=8
 # Original sheet and separate tripod sheet have different painted boiler sizes.
 # Apply one fixed family conversion, including collapsed poses, never per pose.
 if index<14:f['scale']*=.95 if 'tripod-creep' in f['source'] else .90
 return f

def config(clip,indices,guides,last,description,seed):
 c=dict(unit_id=UID,clip=clip,canvas=[960,544],anchor=[470,480],scale=.5,key_rgb=[0,255,0],seed=seed,references=[ref(i) for i in indices],guides=guides,last=last,prompt=(IDENTITY+description+PLATE).strip(),protected_foreground_chroma=0,tiled_decode=dict(tile_size=512,overlap=64,temporal_size=16,temporal_overlap=4))
 out=p.SOURCE_DIR/(clip+'_h3_v1');out.mkdir(exist_ok=True);assert not (out/'submission.json').exists();p.write(out/'config.json',c);p.prepare(out,c)
 maxima=[]
 for i in range(len(indices)):
  a=np.asarray(Image.open(out/f'guide_{i}_rgba.png')).astype(int);mask=a[:,:,3]>=245;band=a[:,:,1]-np.maximum(a[:,:,0],a[:,:,2]);maxima.append(int(band[mask].max()))
 c['protected_foreground_chroma']=max(maxima)+2;p.write(out/'config.json',c);p.verify(out,c)
 p.write(out/'foreground_measurement.json',dict(opaque_alpha_minimum=245,original_guide_green_minus_max_red_blue=maxima,margin=2,protected_foreground_chroma=c['protected_foreground_chroma']))

def main():
 config('move',[14,3,4,5],[[24,1],[48,2],[72,3],[96,1]],0,'One complete deliberate tripod walking cycle IN PLACE. Original near screen-right leg bends, lifts, swings forward and plants while far-left and rear-middle feet support. Then rear-middle foot lifts, advances and plants; then far-left foot lifts, advances and plants. End with same three-foot contact as ready. Each of THREE legs has a readable loading, passing, extension and contact phase; other two feet support every swing. Boiler root remains centered, piston lance stays aimed right. No lost rear leg, no fourth leg or human gait.',2026100901)
 config('attack',[14,6,7],[[28,1],[56,2]],0,'One physical piston-lance thrust. Flex the THREE legs into supplied low loaded stance and retract lance into its front housing; drive ONE straight lance forward toward screen right with its original triangular tip, extend front leg and transfer weight into contact56. Retract lance to original length, straighten legs and return to exact original ready. No firing, detached spear, magic, extra point or repeated thrust.',2026100902)
 config('hit',[14,10],[[34,1]],0,'One clear impact recoil and recovery, without any incoming object. Boiler and pressure tower tilt back slightly, original three knees compress, mounted straight lance rises with chassis. Recover through knee pistons and lower lance naturally to ready. All THREE feet remain supported and identifiable. No collapse, disassembly, dropped parts or extra legs.',2026100903)
 config('defend',[14,8,9],[[32,1]],2,'One defensive mechanical brace. Spread and flex all THREE original legs, lower boiler center into supplied low tripod guard, tip single mounted lance slightly upward as a protective barrier. HOLD supplied final three-foot stance without returning to ready. Legs and knee pistons bend visibly, gauge tower stays intact; no added shield, arm, leg, weapon or magical effect.',2026100904)
 config('cast',[14,17],[[56,1]],0,'One physical readiness/rally signal, no spellcasting. All THREE feet planted. Rotate original front lance mounting upward so straight lance points diagonally up at supplied peak, briefly hold, then rotate same mounted lance back to its original horizontal ready orientation. Housing pivot and hoses articulate visibly; body and feet stay centered, original vents pulse subtly. No firing, new limb, hand, staff, beam or detached lance.',2026100905)
 config('death',[14,11,12,13],[[38,1],[72,2]],3,'One continuous loss of pressure and grounded collapse. All THREE knee pistons buckle, boiler descends toward screen right; folded legs keep their identities and feet. Boiler rolls onto side, chimney and pressure tower tilt with body; single attached lance lowers until its tip rests on ground beside chassis. Finish in supplied cold side-prone machine with three folded legs and dark orange vents. No explosion, floating point, lost or fourth leg, mechanical disassembly, stand-up recovery or shrinking body.',2026100906)
 p.write(p.SOURCE_DIR/'runtime_registration.json',dict(unit_id=UID,reference_height=256,output_scale=.5,ground_anchor=[470,480],fixed_source_family_multipliers={'continuity-alpha/original-poses.png':.90,'continuity-alpha/tripod-creep-and-guard.png':.95,'idle-v2/hands-alpha.png':1},reason='Standing legacy original203px and tripod190px versus accepted articulated idle181px. Original-family conversions preserve relative boiler/anatomical size in crouches and corpse; idle unchanged. No per-frame normalization.'))
 p.write(p.SOURCE_DIR/'delivery.json',dict(takes=[n+'_h3_v1' for n in ['move','attack','hit','defend','cast','death']],preserved_accepted_clips=['idle'],visual_review=dict(status='pending',notes='Solo Pressure Lancers six dedicated H3 mechanical actions. Exactly three legs and a mounted single lance; review all original phases and native scales before publication. Preserved articulated eight-pose idle.')))

if __name__=='__main__':main()
