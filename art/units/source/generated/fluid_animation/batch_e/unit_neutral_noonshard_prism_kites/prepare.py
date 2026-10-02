"""Original four-winged Prism Kite guides with fixed authored registration."""
import json
from PIL import Image,ImageDraw
import produce as p

UID='unit_neutral_noonshard_prism_kites'
B=p.ROOT/'art/animation/source/poses'/UID
IDENTITY=('The original NOONSHARD PRISM KITE from the supplied references, facing SCREEN RIGHT throughout. One small airborne white-opal draconic creature, exactly FOUR attached glass wings, TWO on each side, with original gold/brass curved frames and veinwork and multicoloured iridescent glass panes. Preserve its original long narrow white-and-gold head, gold swept head crest, exactly TWO small gold taloned legs beneath the chest, and TWO original trailing curled white tail fronds ending in faceted leaf-shaped prism fins. Wings hinge at the same shoulder roots; tails flex naturally without multiplying. No human arms, rider, weapons, extra legs, extra wings, feathers or detached body parts. Preserve the supplied painted fantasy artwork, side-facing three-quarter orthographic camera, original proportions and anatomical scale. ')
PLATE=('Entire background uniform dark navy RGB16,32,64, no scenery, shadows, dust, light rays, magical rings, particles, detached glass shards or projectiles. Fixed camera, no cuts, zoom, pan, rotation or root travel. Keep all four wing tips, both tails and head crest comfortably inside the image. Logical ground plane y640; living poses hover with original clearance and freely tucked talons, rather than planting flying feet on the ground. ')

def reference(index):
    frame=dict(json.loads((B/'packing.json').read_bytes())['frames'][index])
    frame['source']=(B/frame['source']).relative_to(p.ROOT).as_posix()
    frame['alpha_noise_cutoff']=8
    if index<16:
        frame['guide_offset']=[120,0 if index>=13 else -52]
    return frame

def recipe(clip,indices,guides,last,action,seed):
    out=p.SOURCE_DIR/(clip+'_h3_v1');out.mkdir(exist_ok=True)
    assert not (out/'sampling_submission.json').exists(),'Submitted originals are immutable'
    config=dict(unit_id=UID,clip=clip,canvas=[960,704],anchor=[480,640],scale=.5,key_rgb=[16,32,64],seed=seed,references=[reference(i) for i in indices],guides=guides,last=last,prompt=(IDENTITY+action+PLATE).strip(),tiled_decode=dict(tile_size=512,overlap=64,temporal_size=16,temporal_overlap=4))
    p.write(out/'config.json',config);p.prepare(out,config);p.verify(out,config)
    print('PREPARED',clip,[(index,Image.open(out/f'guide_{j}_rgba.png').getbbox()) for j,index in enumerate(indices)],flush=True)

if __name__=='__main__':
    recipe('move',[16,2,4,3],[[28,1],[60,2],[92,3]],0,'One complete controlled flight cycle IN PLACE: four wings rise together into original upstroke, hinge down in the original passing position, sweep through original downstroke and return to ready. Near/far pairs remain attached and distinct. The two small talons tuck/extend naturally and both original tail ribbons trail the physical wingbeat. No running, jumping or flying offscreen. ',2026108301)
    recipe('attack',[16,5,6],[[32,1],[62,2],[72,2]],0,'One physical beak-and-head jab: brace with original wing windup, extend neck and the SAME original snout toward SCREEN RIGHT once, with two talons curling beneath the chest. Small local head/shoulder thrust, then draw neck back and return all wings/tails to the initial ready pose. No breath beam, magic, detached feathers or flying away. ',2026108302)
    recipe('ranged',[16,9,10,11],[[52,1],[68,2],[92,3]],0,'One clear ranged release without a baked projectile: steady hover, lift the original head and open the mouth slightly, aim SCREEN RIGHT, extend the head once in the supplied release posture, physically recoil and recover the original wings/head/talons to ready. The runtime supplies the projectile; show only the creature, no beam, shard, spark or orb. ',2026108303)
    recipe('hit',[16,12],[[48,1]],0,'One brief physical impact reaction: head draws back, original neck bends, all four wings flare briefly and two talons curl while both original tail fronds sway. Recover to exact original ready hover without falling, turning away, changing scale or morphing the face. ',2026108304)
    recipe('defend',[16,7],[],1,'One continuous dedicated defensive fold: bend the original four wings into the compact supplied glass-wing guard around the chest; bow head slightly and tuck the original two talons. Keep glass wings and curled tail fronds fully attached and readable. Finish holding that original protective posture; do not reopen to ready. ',2026108305)
    recipe('cast',[16,3],[[50,1]],0,'One calm non-projectile support gesture: dip the original head deliberately, fan all four original glass wings outward in the supplied lowered-wing posture, flex both small talons gently, then raise head and recover to exact initial ready hover. Preserve original glass panes and gold frames; no magic effect, orb, glow, new object or attack. ',2026108306)
    recipe('death',[16,13,14,15],[[38,1],[72,2],[98,3]],3,'One continuous loss of lift and grounded collapse: four original glass wings fold and droop as torso descends, two talons reach toward the ground, original body settles onto its side with wings and both tails folded into the supplied corpse. The final body rests on ground plane y640. No disappearance, upward flip, regenerated wings, shrinkage or standing back up. Last second remain motionless in that original grounded corpse. ',2026108307)
    p.write(p.SOURCE_DIR/'delivery.json',dict(takes=[clip+'_h3_v1' for clip in ['move','attack','ranged','hit','defend','cast','death']],preserved_accepted_clips=['idle'],visual_review=dict(status='pending',notes='Original identity and all24 authored poses personally inspected. Existing eight idle wing/talon/tail phases require native seam/readability check before preservation. Seven new H3 actions require full original chronological, enlarged matte, native/reflected/live and actual combat review. Original ranged-charge8 has a detached sliver and is excluded from guides.')))
    p.write(p.SOURCE_DIR/'runtime_registration.json',dict(unit_id=UID,canvas=[960,704],output_scale=.5,ground_anchor=[480,640],ready_reference=reference(16),legacy_living_guide_offset=[120,-52],legacy_grounded_death_guide_offset=[120,0],measurement=dict(ready_gold_wing_root=[586,421],legacy_idle_gold_wing_root=[466,473]),reason='One rigid translation aligns the original legacy living sheet wing root with accepted ready16. Preserve source scales. Original corpse retains its authored ground contact instead of receiving the living hover shift. No per-video-frame alignment, normalization, synthetic motion or interpolation.'))
    target=p.ROOT/'.artifacts/noonshard_prism_kite_h3';target.mkdir(exist_ok=True)
    sheet=Image.new('RGB',(1600,1760),(16,32,64));draw=ImageDraw.Draw(sheet)
    for cell,index in enumerate([16,2,4,3,5,6,9,10,11,12,7,13,14,15]):
        clip=next(c for c in ['move','attack','ranged','hit','defend','death'] if index in {'move':[16,2,4,3],'attack':[16,5,6],'ranged':[16,9,10,11],'hit':[16,12],'defend':[16,7],'death':[16,13,14,15]}[c])
        config=json.loads((p.SOURCE_DIR/(clip+'_h3_v1')/'config.json').read_bytes());j=next(j for j,f in enumerate(config['references']) if f['name']==reference(index)['name'])
        im=Image.open(p.SOURCE_DIR/(clip+'_h3_v1')/f'guide_{j}_rgba.png');im.thumbnail((396,390),Image.Resampling.LANCZOS)
        x,y=cell%4*400,cell//4*440;sheet.paste(im,(x,y+30),im);draw.text((x+5,y+5),f'{index} {reference(index)["name"]}',fill='white')
    sheet.save(target/'registered-guides.png')
