"""Original Tidepool Cutters guides; one anatomical scale and two distinct blades."""
import json
import numpy as np
from PIL import Image,ImageDraw
from scipy.ndimage import binary_erosion
import produce as p

UID='unit_neutral_tidepool_cutters'
BASE=p.ROOT/'art/animation/source/poses'/UID
PACK=json.loads((BASE/'packing.json').read_bytes())
IDENTITY=(
 'ONE original adult female Tidepool Cutter, elevated three-quarter view facing screen right. '
 'Keep her teal headscarf with long trailing ties, long dark-brown beaded hair, white pearl earrings and gold medallion. '
 'She wears a weathered teal long coat over cream cloth, brown cross-body straps, rope belt, netted hip pouch with white shells, dark trousers, black fingerless gloves and brown rope-wrapped boots. '
 'Exactly TWO arms, TWO hands and TWO legs. Each hand firmly grips its OWN short silver hook-bladed cutter, with gold handle and dangling white shell charm. '
 'Maintain both distinct short curved blades, their hook tips, metal shapes and handle connections in every frame. No third blade, swapped hands, long sword, shield or missing weapon. '
 'Keep her original adult face, body proportions, equipment, original painted fantasy texture and camera. '
)
PLATE=(
 ' Locked orthographic camera, fixed anatomical scale and centered root. Full figure including every blade tip, headscarf and boot inside the canvas. '
 'Uniform saturated MAGENTA background throughout, no scene, floor, shadow, gradient or camera motion. '
 'Natural joint articulation, real support and stable grips, no body morphing, extra limbs, trails, glow or magical effects. '
)

def ref(i):
 f=dict(PACK['frames'][i]);f['source']=(BASE/f['source']).relative_to(p.ROOT).as_posix();f['alpha_noise_cutoff']=8
 return f

TAKES={
 'move_h3_v1':([2,3],[[31,1],[93,1]],0,
  'Briskly walk in place through two complete reciprocal gait cycles. Both boots alternate contact, loading, passing and forward extension. '
  'Keep the body root centered for engine movement, not drifting across the image. Carry both blades safely down and outward with lightly swinging elbows. End in the initial gait phase.'),
 'attack_h3_v1':([13,4,5,6],[[30,1],[55,2],[86,3]],0,
  'Perform ONE right-hand hooked-blade slash toward screen right. Raise the right blade over the right shoulder in anticipation while the left blade remains low and outward as a guard. '
  'Step into a short controlled slash with the right arm sweeping down and forward across the chest, then retract it, recover both blades and return to the original ready stance. '
  'Exactly two blades remain in their original hands; never merge or detach them. No thrown weapon, spinning, repeated strikes or weapon morphing.'),
 'hit_h3_v1':([13,9],[[40,1]],0,
  'React once to a chest impact. Shoulders recoil, head tilts back and knees flex while both hands keep their hooked blades low and away from the torso. '
  'Recover balance onto both planted boots and return to the original stance. No fall, attack or loose weapon.'),
 'defend_h3_v1':([13,8],[],1,
  'Immediately begin one continuous defensive brace: raise both forearms, cross the two blades in front of the face with both separate hands visible, and bend knees gradually into the final low crouch. '
  'Lower the hips without changing anatomical scale. Finish holding the crossed-blade crouching guard. No return to standing, strike or scene cut.'),
 'cast_h3_v1':([13,7],[[42,1],[68,1]],0,
  'Give ONE nonmagical readiness salute: smoothly bring both hooked blades up to cross at chest height while remaining upright. '
  'Keep both hands separate, each on its own gold handle. Briefly hold the crossed-blade salute, then uncross and lower both blades to the original relaxed stance. '
  'Boots remain planted; this is a physical support gesture, no spell, attack or crouch.'),
 'death_h3_v1':([13,10,11,12],[[33,1],[75,2]],3,
  'Collapse continuously. Knees buckle, lower onto both knees, then tip onto the side toward screen left. '
  'Arms lower both hooked cutters onto the ground as the torso descends. Finish on the side, head at screen left, feet at screen right, both blades grounded in front. '
  'Keep both hands and both blades distinct throughout, and the scarf, pouch and body attached. No recovery, disappearing limbs, floating blades or camera movement.'),
}

if __name__=='__main__':
 thumbs=[]
 for n,(name,(indices,guides,last,action)) in enumerate(TAKES.items()):
  out=p.SOURCE_DIR/name;out.mkdir(exist_ok=False)
  c=dict(unit_id=UID,clip=name.split('_')[0],canvas=[960,640],anchor=[440,560],scale=.5,key_rgb=[255,0,255],seed=2026092950+n,
   references=[ref(i) for i in indices],guides=guides,last=last,prompt=(IDENTITY+action+PLATE).strip(),
   tiled_decode=dict(tile_size=512,overlap=64,temporal_size=16,temporal_overlap=4))
  p.prepare(out,c);excess=[]
  for i in range(len(indices)):
   im=Image.open(out/f'guide_{i}_rgba.png');a=np.asarray(im).astype(float);mask=binary_erosion(a[:,:,3]>240,iterations=3)
   excess.append(float((np.minimum(a[:,:,0],a[:,:,2])-a[:,:,1])[mask].max()))
   thumbs.append((name+':'+str(i),im.copy()))
  c['protected_foreground_chroma']=max(0,int(max(excess))+2)
  c['foreground_measurement']=dict(rule='Opaque interiors eroded three pixels; maximum magenta excess plus two.',per_guide_max=excess)
  p.write(out/'config.json',c)
 p.write(p.SOURCE_DIR/'delivery.json',dict(unit_id=UID,takes=list(TAKES),preserved_accepted_clips=['idle'],visual_review=dict(status='pending',notes='Review complete original chronology, distinct blade/hand continuity, reciprocal gait, grounded collapse and native battle scale. Preserve reviewed eight-pose idle/map.')))
 sheet=Image.new('RGB',(1440,((len(thumbs)+3)//4)*260),(42,48,43));draw=ImageDraw.Draw(sheet)
 for j,(name,im) in enumerate(thumbs):
  im.thumbnail((356,237));x,y=j%4*360,j//4*260;sheet.paste(im,(x,y+23),im);draw.text((x+4,y+4),name)
 sheet.save(p.ROOT/'.artifacts/tidepool_h3/guides.png')
