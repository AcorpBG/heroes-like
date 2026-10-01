"""Reassess repeated gun-emission failures as an unambiguous physical kick."""
import json
from PIL import Image
import produce as p
import prepare_h3 as original
import prepare_solo_completion as prep

if __name__=='__main__':
    s=p.SOURCE_DIR
    prep.composite_body('melee_kick_body_v1',[500,888],.535,Image.open(s/'mast_component35.png'))
    c=json.loads((s/'attack_solo_h3_v3/config.json').read_bytes())
    c.update(seed=2026100361,references=[original.ref(0),prep.whole('melee_kick_body_v1_control')],guides=[[10,0],[40,1],[80,0]],last=0)
    c['prompt']='One original Flaremast woman, brown hair, blue cap/amber goggles, teal cream-cuff jacket, brown quilted vest, red scarf/sash, cream trousers and tall brown strapped boots. Exactly two arms/hands and two legs. Both hands hold the same passive long brass flared tube with red chamber LOW across waist pointing DOWN RIGHT throughout. Same standing brass mast/red-orange-blue canisters/tripod is motionless at screen left. Perform ONE FRONT BOOT KICK toward screen right: transfer weight onto the far boot at its original screen-right ground contact, raise the near knee from the screen-left hip beneath red sash, extend that boot forward to the supplied kick contact, retract knee then ground both boots back in original ready stance. Torso counterbalances smoothly, elbows/hands and tube stay passive and low; no lifting or operation of held equipment. A continuous leg-driven physical action, one knee lift, one kick, one recovery, no repetition. Locked elevated three-quarter orthographic camera facing right, same anatomical scale and equipment geometry. Full body/held tube/mast/kicking boot inside960x640, no extra limbs. Perfectly uniform flat pure green RGB0,255,0 background, unchanged empty surroundings, no floor/shadow/gradient/hue cycling/text/particles/emissions/flame/smoke/detached objects.'
    out=s/'attack_solo_h3_v4';out.mkdir(exist_ok=False);p.write(out/'config.json',c);p.prepare(out,c);p.verify(out,c)
    print('Prepared leg-driven kick with passive low-held equipment')
