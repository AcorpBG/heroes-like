"""Prepare fixed-scale original Kitehook action guides, retaining articulated idle."""
import json
import numpy as np
from PIL import Image, ImageDraw
from scipy.ndimage import binary_erosion
import produce as p

UID = 'unit_neutral_kitehook_runners'
BASE = p.ROOT/'art/animation/source/poses'/UID
PACK = json.loads((BASE/'packing.json').read_bytes())
IDENTITY = ('One original Kitehook Runner, an athletic adult woman with fair skin and brown tied-back hair, '
 'a teal headband, yellow neck scarf, ivory rolled sleeves, brown leather vest and belts, '
 'brown trousers, round steel knee guards, brown leather boots with yellow bindings. '
 'Teal and yellow cloth streamers trail from her shoulders and belt. One coiled rope hangs on her left hip. '
 'Exactly two arms and two legs. Both hands grip one compact wooden hook pole horizontally across her waist: '
 'the forward hand near the silver twin-curved hook head on screen right, the rear hand toward the rope-loop butt on screen left. '
 'Preserve one pole, its length, metal hook shape, both grips, face, rope and clothing. ')
PLATE = (' Fixed elevated three-quarter orthographic camera, face toward screen right, original painted body scale. '
 'Keep the complete body, hook pole, rope and trailing cloth inside the frame. '
 'The background remains perfectly flat pure magenta RGB255,0,255 throughout: '
 'no hue changes, floor, shadows, horizon, scenery, text, other people or effects. '
 'Smooth physical joint articulation with unchanged anatomy and equipment. ')
TAKES = {
 'move_h3_v1': ([17,2], [[35,1]], 0,
  'Run in place through two reciprocal stride cycles, with the opposite leg moving forward on the second contact. Alternate the near and far legs through extension, '
  'foot contact, loading, passing and toe lift. Keep the hips centered without travelling across the frame. '
  'Both hands hold the same hook pole safely across the waist. The knees and ankles bend coherently, '
  'cloth and ponytail trail naturally. End in the initial ready stance.'),
 'attack_h3_v1': ([17,4,5,6], [[30,1],[55,2],[85,3]], 0,
  'Perform one two-handed short hook-pole thrust toward screen right. Draw both elbows back in windup, '
  'then extend both arms and lean from the hips into the supplied contact pose. '
  'Both hands stay attached to the same wooden shaft, silver hook head points right. '
  'Retract the hook and recover the initial ready stance. No projectile or detached weapon.'),
 'hit_h3_v1': ([17,9], [[28,1],[45,1]], 0,
  'React to one impact with a short backward torso recoil. Bend both knees, rock the shoulders and head back '
  'into the supplied recoil while both hands retain the hook pole. Feet stay near their original contacts. '
  'Pause briefly and recover upright to the initial stance. Empty background stays identical.'),
 'defend_h3_v1': ([17,8], [[58,1]], 1,
  'Lower into the supplied guarded crouch by bending both knees. Lean forward, '
  'bring the hook pole low and across the body with both hands firmly on its original shaft. '
  'Both legs support the body and the head remains alert toward right. Finish holding the guarded crouch.'),
 'cast_h3_v1': ([13,16], [[30,1]], 0,
  'Perform a practical physical ready signal. Lift the same hook pole with both hands from waist level through the supplied chest-level pose, '
  'then substantially higher to above her head as a rally signal. Both elbows clearly lift and extend. '
  'Briefly hold the high pole around the middle of the video, '
  'then lower the pole to the original waist-level grip. Keep both feet grounded. '
  'This noncaster makes an equipment readiness gesture without magic, glow, projectiles or new equipment.'),
 'death_h3_v1': ([17,10,11,12], [[32,1],[68,2]], 3,
  'Perform one continuous defeat collapse. Knees buckle and lower onto the ground, '
  'then hips lower and the torso tips gently onto its side with the head toward screen right. '
  'Both hands retain the hook pole until it meets the ground, then it rests flat immediately beside the body. '
  'Settle into the supplied grounded side-rest corpse with exactly two arms and two legs, '
  'cloth draped over the body, one rope coil and exactly one hook pole on the ground. Finish motionless.')
}

def ref(index):
    frame = dict(PACK['frames'][index])
    frame['source'] = (BASE/frame['source']).relative_to(p.ROOT).as_posix()
    frame['alpha_noise_cutoff'] = 8
    return frame

if __name__ == '__main__':
    thumbs = []
    for number,(name,(indices,guides,last,action)) in enumerate(TAKES.items()):
        out = p.SOURCE_DIR/name
        out.mkdir(exist_ok=False)
        config = dict(unit_id=UID,clip=name.split('_')[0],canvas=[960,640],anchor=[470,560],scale=.5,
          key_rgb=[255,0,255],seed=2026100120+number,references=[ref(i) for i in indices],guides=guides,last=last,
          prompt=(IDENTITY+action+PLATE).strip(),tiled_decode=dict(tile_size=512,overlap=64,temporal_size=16,temporal_overlap=4))
        # Move's first original cycles the magenta plate. These later takes
        # were still unsubmitted when the coordinator authorized green.
        # It also separates the original corpse hand's purple bruising.
        green = config['clip'] in {'defend','cast','death'}
        if green:
            config['key_rgb']=[0,255,0]
            config['prompt']=config['prompt'].replace('magenta RGB255,0,255','green RGB0,255,0')
        p.prepare(out,config)
        bands=[]
        for i in range(len(indices)):
            im=Image.open(out/f'guide_{i}_rgba.png');pixels=np.asarray(im).astype(float)
            mask=binary_erosion(pixels[:,:,3]>240,iterations=3)
            chroma=(pixels[:,:,1]-np.maximum(pixels[:,:,0],pixels[:,:,2]) if green
                    else np.minimum(pixels[:,:,0],pixels[:,:,2])-pixels[:,:,1])
            bands.append(float(chroma[mask].max()))
            thumbs.append((name+':'+str(i),im.copy()))
        config['protected_foreground_chroma']=max(0,int(max(bands))+2)
        config['foreground_measurement']=dict(rule=('Eroded opaque green-minus-max(red,blue) maximum plus two across original guides, retaining teal cloth and corpse bruising.' if green else 'Eroded opaque min(red,blue)-green maximum plus two across original guides.'),per_guide_max=bands)
        if green:
            config['foreground_measurement']['separation']=255-config['protected_foreground_chroma']
            config['palette_preparation_note']='Observed move-v1 magenta hue cycling; coordinator authorized stronger pure-green plate before this initial take was ever submitted.'
        p.write(out/'config.json',config)
    p.write(p.SOURCE_DIR/'delivery.json',dict(unit_id=UID,takes=list(TAKES),preserved_accepted_clips=['idle'],
       visual_review=dict(status='pending',notes='Original idle has visible two-hand hook-pole lift/return and cloth motion. Candidate requires complete chronological review of reciprocal running, two-grip hook thrust, recoil, crouch, physical pole signal and grounded collapse; continuous playback route remains unavailable.')))
    sheet=Image.new('RGB',(1440,((len(thumbs)+3)//4)*270),(43,48,43));draw=ImageDraw.Draw(sheet)
    for i,(name,im) in enumerate(thumbs):
        im.thumbnail((356,245));x,y=i%4*360,i//4*270
        sheet.paste(im,(x,y+23),im);draw.text((x+4,y+4),name)
    sheet.save(p.ROOT/'.artifacts/kitehook_h3/guides.png')
