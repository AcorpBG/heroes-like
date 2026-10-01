"""Bounded correction takes; preserve every failed original unchanged."""
import json
import produce as p
from prepare import ref

def prepare(name, c):
    out=p.SOURCE_DIR/name
    out.mkdir(exist_ok=True)
    assert not (out/'submission.json').exists()
    p.write(out/'config.json',c)
    p.prepare(out,c)
    p.verify(out,c)

def main():
    def old(name): return json.loads((p.SOURCE_DIR/name/'config.json').read_bytes())
    c=old('attack_h3_v1')
    c['seed']=2026100812
    c['prompt']=('Physical two-handed melee shove with a short rigid wooden tube. '+c['prompt'].split(' One melee jab')[0]+' Move the whole rigid pipe forward using both arms and a small torso lean, then retract it and lower to ready. Its brass-ringed shaft and short cyan needle point retain exactly their reference lengths throughout. The point stays attached to the wooden muzzle, never extends or emits anything. Maintain two original hands on the two spaced grips. One anticipation, one short thrust, one recovery. Fixed elevated orthographic camera, same full body size and ground root. Flat uniform magenta background RGB255,0,255 throughout, no other effects or objects.').strip()
    prepare('attack_h3_v2',c)

    c=old('ranged_h3_v1')
    c.update(seed=2026100815,references=[ref(11),ref(12)],guides=[],last=1)
    c['prompt']=('One controlled breath through the small brass-ringed wooden blowpipe. The same young teal-hooded man stays in the supplied two-handed aiming stance, rear mouthpiece at lips and left hand supporting the front. The single small cyan needle tip slips out of the muzzle once, leaving the supplied empty rigid wooden pipe. Keep the needle as small as in the reference, with no flash, beam, glow plume or trail. Hold the empty aim calmly for the rest of the clip. Two original hands remain on the same rear and front grips, both boots planted, same face, hood, armor, quiver and vials. One release only; no loading or second shot. Fixed elevated orthographic camera facing right, entire unchanged body and equipment inside960x544. Flat saturated magenta RGB255,0,255 backdrop throughout with no lighting changes or shadows.').strip()
    prepare('ranged_release_h3_v2',c)

    c=old('death_h3_v1')
    c.update(seed=2026100816,references=[ref(17),ref(14),ref(16)],guides=[[38,1]],last=2,key_rgb=[0,255,0])
    c['prompt']=('A continuous physical side collapse of the supplied teal-hooded human scout. Knees buckle, body drops onto its knees, then hips and shoulders roll down toward screen right into the supplied head-right prone corpse. Both original legs and arms remain intact. The rigid wooden pipe lowers in the original right hand and rests horizontally beside the body. Same face, ragged teal cloak, bronze leather armor, quiver and cyan belt vials throughout. End with the whole body, hands, boots and pipe resting on the ground and hold completely still. Fixed elevated orthographic camera, unchanged anatomical body size and ground reference, entire creature always inside960x544. Every frame has exactly the same flat pure saturated green RGB0,255,0 background. No color cycling, floor, shadow, light effects, particles or extra objects.').strip()
    prepare('death_h3_v2',c)
    p.write(p.SOURCE_DIR/'correction_review.json',dict(rejected={'attack_h3_v1':'Frames50-52 stretch the attached cyan needle during melee contact.', 'ranged_h3_v1':'Frames46-49 add a large cyan plume; frames74-79 emit a second needle. Preserve valid preparation and reload/recovery for possible segment assembly.', 'death_h3_v1':'Frames17-56 use orange, insufficiently separated from bronze costume for the measured chroma extractor.'},bounded_defend='Frames0-37 are the complete brace into a held two-hand crouched guard. Reject firing after38; end the delivered guard before that unrelated action.',preserved=['move_h3_v1','hit_h3_v1','cast_h3_v1','reviewed existing idle'],rule='No synthetic articulation, padding, gate relaxation or overwritten original generation.'))

if __name__=='__main__':main()
