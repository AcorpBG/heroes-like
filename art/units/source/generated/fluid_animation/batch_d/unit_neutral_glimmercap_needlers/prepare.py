"""Prepare original Glimmercap Needler H3 action guides, not replacement motion."""
import json
from pathlib import Path
import produce as p

UID='unit_neutral_glimmercap_needlers'
LEGACY=p.ROOT/'art/animation/source/poses'/UID
FRAMES=json.loads((LEGACY/'packing.json').read_bytes())['frames']
IDENTITY=('One original adult human Glimmercap Needler, lean young man with narrow pale face, dark hair, teal hood with small pale mushroom ornaments, teal scarf and ragged cloak, dark leather layered bronze armor, olive forearm wraps, black trousers and tall bronze-bound boots. Cyan crystal-tipped needle quiver on back and cyan glass belt vials. One straight brown blowpipe with brass rings and ONE loaded cyan needle tip at the muzzle. Right hand grips its rear, near screen left, and left hand holds spare needles in ready or supports the forward pipe during two-handed actions. Exactly two arms, two hands and two legs, same face, clothing, pipe and equipment throughout. ')
PLATE=(' Locked elevated three-quarter orthographic camera facing screen right. Full creature, needle tips, pipe, boots and cloak stay in960x544 with generous margins, same anatomical body size and centered root throughout. Uniform pure saturated magenta RGB255,0,255 background for every frame; no gradients, color cycling, floor, cast shadow, text, particles, external light, magic, extra people or objects. Anatomically articulated physical joints, no morphing equipment or extra arms. ')

def ref(index):
 f=dict(FRAMES[index]);f['source']=(LEGACY/f['source']).relative_to(p.ROOT).as_posix()
 if index<17:f['scale']*=.97
 f['alpha_noise_cutoff']=8
 return f

def config(clip,indices,guides,last,description,seed):
 c=dict(unit_id=UID,clip=clip,canvas=[960,544],anchor=[470,480],scale=.5,key_rgb=[255,0,255],seed=seed,references=[ref(i) for i in indices],guides=guides,last=last,prompt=(IDENTITY+description+PLATE).strip(),protected_foreground_chroma=26,tiled_decode=dict(tile_size=512,overlap=64,temporal_size=16,temporal_overlap=4))
 out=p.SOURCE_DIR/(clip+'_h3_v1');out.mkdir(exist_ok=True)
 assert not (out/'submission.json').exists()
 p.write(out/'config.json',c);p.prepare(out,c);p.verify(out,c)

def main():
 config('move',[2],[],0,'Two complete reciprocal running strides in place. Start with RIGHT near leg extended forward and LEFT far leg bent behind. Near leg loads and passes back as far leg comes forward; then exchange again and return to the supplied contact. BOTH original legs alternate contact, loading, passing and extension. Pipe retained low in original right hand, spare needles in original left, quiver and cloak follow real body motion. No sliding root or duplicated near-leg-only steps.',2026100701)
 config('attack',[17,4,5],[[28,1],[48,2]],0,'One melee jab, never a shot. Bring the loaded pipe up into two spaced hand grips, draw arms back slightly with elbows bent, plant lead boot and drive a short two-handed shove toward screen right with the original loaded cyan needle tip, retract both arms and lower pipe to original ready. Keep the ONE loaded tip throughout; no projectile release, extra blade or bow. Spare needles are held safely out of the jab and return with the left ready hand.',2026100702)
 config('hit',[17,9],[[32,1]],0,'One brief impact recoil and recovery. Chest and hood lean backward, knees flex, original left hand draws to chest, original right hand retains the complete pipe angled down. Recover balance by bending knees and returning torso and left hand to original ready. No fall or new action.',2026100703)
 config('defend',[17,8],[],1,'One defensive transition. Place spare needles away safely, bring both original hands to two spaced pipe grips, bend both knees into supplied low crouched guard with pipe protecting chest and loaded tip facing right, then HOLD the guard through the final frame. No firing or return to idle in the held ending.',2026100704)
 config('ranged',[17,10,11,12,13],[[22,1],[44,2],[58,3],[82,4]],0,'One blowpipe shot and recovery. Ready, bring ONE cyan needle into the original pipe, raise pipe to mouth and aim toward screen right with right hand at rear near mouth and left supporting forward barrel. Exhale ONCE; the loaded cyan tip leaves the muzzle at the release guide and the pipe is visibly empty. The game owns projectile flight: do not draw a travelling dart, beam or particles outside the muzzle. Lower empty pipe, retrieve spare needles, then return to the original loaded ready. Only one shot, no repeated firing, no third arm or changing pipe length.',2026100705)
 config('death',[17,16],[],1,'One continuous loss of balance and side collapse. Both knees give way, body lowers naturally, hips and shoulders tip toward screen right and hooded head comes down into supplied head-right prone corpse. Keep two original arms and legs, full quiver and pipe. Pipe lowers with original right hand and settles horizontally beside the body with cyan needle tip facing right. Remain completely prone with both boots, hands, body and pipe grounded through the final frame. No standing recovery, raised feet or upright pipe.',2026100706)
 # Prepared only to expose the reviewed ready reference for a new support guide.
 config('cast',[17],[],0,'One physical support signal, no casting. Keep original right hand holding pipe down toward screen left. Lift original left hand with spare cyan needles to shoulder height in a clear rally gesture, nod once, then lower left hand to original ready. Both boots stay planted. No glowing effect or released needle.',2026100707)
 p.write(p.SOURCE_DIR/'runtime_registration.json',dict(unit_id=UID,reference_height=256,output_scale=.5,ground_anchor=[470,480],legacy_action_family_scale=.97,reason='Original ready paintings have about201px body envelope versus195px retained hand-articulated idle. One legacy-family conversion preserves relative crouch/fall geometry; reviewed idle guides retain original scale. No per-frame normalization.'))
 p.write(p.SOURCE_DIR/'delivery.json',dict(takes=[n+'_h3_v1' for n in ['move','attack','hit','defend','ranged','death','cast']],preserved_accepted_clips=['idle'],visual_review=dict(status='pending',notes='Solo seven-action Glimmercap Needler production. Source chronology and native review required; preserve reviewed articulated eight-frame idle.')))

if __name__=='__main__':main()
