"""Prepare original-only Tunnel Lantern H3 guides at the retained idle body scale."""
import copy,json
from pathlib import Path
import produce as p

UID='unit_neutral_tunnel_lanterns'
LEGACY=p.ROOT/'art/animation/source/poses'/UID
def ref(index):
 f=copy.deepcopy(json.loads((LEGACY/'packing.json').read_bytes())['frames'][index])
 f['source']=(LEGACY/f['source']).relative_to(p.ROOT).as_posix()
 # Existing idle has187px opaque body; old standing actions215px. Apply one
 # anatomical source-family conversion, never each pose's bounding-box height.
 if index<12:f['scale']*=.87
 f['alpha_noise_cutoff']=8
 return f

def prepare():
 near=dict(name='near_right_contact_original',source=(p.SOURCE_DIR/'walk_near_contact_v1.png').relative_to(p.ROOT).as_posix(),rects=[[0,0,1680,960]],anchor=[870,856],scale=.23125,alpha_noise_cutoff=8)
 identity='One original Tunnel Lantern guard: stocky stern stubbled man, charcoal hood with bronze arrow badge, dark iron armor with bronze rivets/edges, olive tabard, rope and leather pouches, heavy armored boots. Exactly two arms/hands and two legs. RIGHT hand retains one short wooden-shaft spear with complete dark silver pointed head. LEFT arm retains one tall oval dark wood bronze-rimmed shield, with one caged amber lantern fixed to its FRONT. '
 plate=' Locked elevated three-quarter orthographic camera facing screen right, same body/equipment size throughout and anatomical root centered. All body, shield, spear tip and butt inside960x544. Uniform pure magenta RGB255,0,255 background throughout; no floor, cast shadow, text, extra people, new objects or external particles. Lantern flame remains INSIDE its original cage. Rigid original spear and shield; physical articulated joints, stable grips.'
 definitions={
 'attack':([ref(0),ref(4),ref(5),ref(6)],[[27,1],[55,2],[84,3]],0,'One short-spear thrust. Lift right fist beside right shoulder into supplied windup with the spear tip pointed toward screen right, shield remains on left arm. Drive right shoulder/elbow forward, extend the short spear horizontally to screen right in supplied contact pose. The right hand stays around the SAME shaft position; keep full point and rear butt. Recoil through elbow and shoulder, lower spear back to ready. One anticipation/thrust/recovery, no extra strike. Both boots remain grounded at contact, torso twists locally. No released spear or magic.'),
 'hit':([ref(0),ref(8)],[[32,1],[76,0]],0,'One physical backward shoulder/torso recoil with flexed knees, then controlled recovery to ready. Shield tilts with the left forearm, and right elbow retains the short spear throughout. Both boots support the body; no fall, no travel, no extra action. Lantern stays securely fixed to shield; equipment passive, no visible external effects.'),
 'defend':([ref(0),ref(7)],[[55,1]],1,'Raise left-arm lantern shield forward into supplied low defensive brace. Bend both knees and tuck torso behind the shield; right hand keeps spear low with complete point. Shield protects chest, face still visible above rim. Reach guard by the middle and HOLD that grounded stance through last frame; do not return to idle. Lantern remains on shield front; no external light blast or weapon release.'),
 'cast':([ref(0),ref(15)],[[52,1],[96,0]],0,'One physical lantern-shield signal to companions: lift left elbow/forearm so attached shield and lantern rise to the supplied upright cue pose, tilt shield outward briefly, head looks ahead, then lower left forearm and settle back to ready. Right fist keeps short spear safely low and moves naturally with shoulder. Both boots stay planted. No magical invocation or released light; amber lamp stays inside cage.'),
 'death':([ref(0),ref(9),ref(10),ref(11)],[[28,1],[59,2]],3,'One continuous heavy armored collapse. Knees buckle, torso sinks into supplied kneel; left shield tilts downward and touches ground. Lower hip and shoulder into the side fall, then relax fully into supplied horizontal head-left corpse. Final body, boots, own spear and lantern shield rest on ground; spear may leave relaxed right fingers only as it lands beside body. Preserve exactly one complete spear and one complete shield/lantern throughout. Flame dims naturally inside cage as corpse settles. No stand-up or repeated fall, no upright props at end.'),
 'move':([ref(2),near,ref(3)],[[32,1],[64,0],[96,1]],0,'Walk in place with reciprocal armored strides. Starting contact has far leg forward/near leg trailing; near/right leg starts at screen-left hip under spear arm and swings forward toward screen right from its own hip through bent-knee passing, contacts ahead, takes weight, and moves behind as far leg passes forward. Alternate BOTH boots through contact, loading, passing and toe-off. Left arm carries lantern shield and right hand holds same short spear low; no grip/equipment swaps. No translation, camera drift or marching the same leg repeatedly.')}
 for order,(clip,(refs,guides,last,action)) in enumerate(definitions.items()):
  out=p.SOURCE_DIR/(clip+'_h3_v1');out.mkdir(exist_ok=False)
  c=dict(unit_id=UID,clip=clip,canvas=[960,544],anchor=[470,480],scale=.5,key_rgb=[255,0,255],seed=2026100410+order,references=refs,guides=guides,last=last,prompt=identity+action+plate,protected_foreground_chroma=26,tiled_decode=dict(tile_size=512,overlap=64,temporal_size=16,temporal_overlap=4))
  p.write(out/'config.json',c);p.prepare(out,c);p.verify(out,c)
 p.write(p.SOURCE_DIR/'runtime_registration.json',dict(unit_id=UID,reference_height=256,output_scale=.5,ground_anchor=[470,480],legacy_family_scale=.87,reason='One legacy source-family body conversion215px standing to187px existing articulated idle; source-specific old recipe scales retained before this global conversion. Idle drawings/timing are preserved. No per-frame normalization.'))
 print('Prepared six pending H3 actions from preserved original pose guides')
if __name__=='__main__':prepare()
