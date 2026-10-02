"""Original four-wing Lanternmoth action guides; preserve the reviewed idle."""
import json
from PIL import Image
import produce as p
UID='unit_neutral_sunscale_lanternmoths'
B=p.ROOT/'art/animation/source/poses'/UID
IDENTITY=('Original SUNSCALE LANTERNMOTH from the supplied painting. One furry charcoal/ivory moth thorax, one glowing faceted amber lantern abdomen pointing down and back SCREEN LEFT, head with the original golden eye facing SCREEN RIGHT. Exactly FOUR blue-and-gold mineral-patterned wings: two large forewings and two smaller hindwings, all attached at their original thorax roots. Preserve their gold crescent markings and cobalt panels, near/far pairing and proportions. Exactly TWO curved feather antennae and SIX slender insect legs attached below the thorax, three near-side and three partly occluded far-side legs; no arms, rider, human hands or equipment. Never add wings, legs, antennae, bells or ornaments. Keep original painted fantasy style, fixed side three-quarter camera, original body scale/facing. ')
PLATE=(' Entire backdrop flat magenta RGB255,0,255 throughout, no scenery, floor, cast shadow, text, camera movement, zoom or cuts. Preserve ALL wing tips, antennae and legitimate legs inside generous canvas margins. Anatomical hover reference remains stable; no global translation stands in for articulated motion. No detached particles, beams, bolts, shards or invented props. ')

def reference(index):
    f=dict(json.loads((B/'packing.json').read_bytes())['frames'][index])
    f['source']=(B/f['source']).relative_to(p.ROOT).as_posix();f['alpha_noise_cutoff']=8
    if index==15:
        # Register physical corpse contact once; retain all original body pixels.
        im,offset=p.source_pose(f,8);delta=offset[1]+im.height
        f['anchor']=[f['anchor'][0],round(f['anchor'][1]+delta/f['scale'])]
    return f

def recipe(clip,indices,guides,last,action,seed):
    out=p.SOURCE_DIR/(clip+'_h3_v1');out.mkdir(exist_ok=True)
    assert not (out/'submission.json').exists(),'Submitted original is immutable'
    c=dict(unit_id=UID,clip=clip,canvas=[960,640],anchor=[480,576],scale=.5,key_rgb=[255,0,255],seed=seed,references=[reference(i) for i in indices],guides=guides,last=last,prompt=(IDENTITY+action+PLATE).strip(),tiled_decode=dict(tile_size=512,overlap=64,temporal_size=16,temporal_overlap=4))
    p.write(out/'config.json',c);p.prepare(out,c);p.verify(out,c)
    print('Prepared',clip,[(i,Image.open(out/f'guide_{j}_rgba.png').getbbox()) for j,i in enumerate(indices)])

if __name__=='__main__':
    recipe('move',[16],[],0,'Two complete deliberate four-wing flight cycles in place. Both forewings sweep upward and then push down; the two smaller hindwings flex in coordination at their separate roots. Six legs tuck and extend slightly, feather antennae trail the strokes. Stable centered thorax and abdomen, no travel or rotations. Return smoothly to the exact original ready hover. ',2026107001)
    recipe('attack',[16,6],[[48,1]],0,'One close-range claw rake: tuck abdomen and draw the two front legs back, load all four wing roots, then extend and rake the two original front legs SCREEN RIGHT once while the other four legs stay attached and tucked. A short coordinated wing stroke supports the rake. Recover claws, wings and antennae to exact initial ready; no second strike or repeated flight cycle. ',2026107002)
    recipe('ranged',[16],[],0,'One Sunscale Fan release. Aim the head SCREEN RIGHT, arch both original forewings to expose the lantern abdomen, tense the four wing roots as the original amber facets brighten, then make one clear coordinated outward wing snap and abdominal pulse. Recoil and recover to exact ready. Light stays entirely within the existing abdomen; no detached projectile or beam because the game renders flight separately. One charge, one release, one recovery only. ',2026107003)
    recipe('hit',[16,12],[[42,1]],0,'One brief impact recoil: head and thorax draw back, four wings flex protectively, antennae bend and six attached legs curl. Abdomen follows coherently. Recover to exact ready without loss of flight or collapse. ',2026107004)
    recipe('defend',[16,7],[],1,'One continuous defensive brace. Gradually rotate and fold all four attached wings down and inward around the thorax and glowing abdomen, tuck six legs and bow the feather antennae. Keep head and original markings recognizable. End in a clearly held mineral-wing shield stance for the final second, without returning ready or snapping between poses. ',2026107005)
    recipe('cast',[16],[],0,'One innate Lanternscale support signal: lift and slowly fan the two original forewings while smaller hindwings counterflex, bow the two feather antennae and bring the original front pair of legs together beneath the head. The existing faceted abdomen makes one gentle warm pulse, then legs and four wings return smoothly to original ready. No human spellcasting, new arms, rings, particles or projectile. ',2026107006)
    recipe('death',[16,15],[],1,'One continuous grounded collapse. Lose wing lift, curl the six insect legs, fold all four original wings as the thorax and amber abdomen descend to virtual ground y576. Land on the original side with head right and abdomen left. Feather antennae, wings and all six legs settle naturally against the ground; abdomen dims to the original terminal corpse. Final second completely still, no shrinking, dissolving, clipped wings, detached legs or hovering corpse. ',2026107007)
    p.write(p.SOURCE_DIR/'delivery.json',dict(takes=[c+'_h3_v1' for c in ['move','attack','ranged','hit','defend','cast','death']],preserved_accepted_clips=['idle'],visual_review=dict(status='pending',notes='All24 legacy paintings inspected. Eight existing idle poses show coherent four-wing flex with legs/antennae response and matching loop seam; preserve pixels and130ms timing. Seven new H3 actions require chronological, enlarged and native/live review.')))
    p.write(p.SOURCE_DIR/'runtime_registration.json',dict(unit_id=UID,reference_height=256,output_scale=.5,canvas=[960,640],ground_anchor=[480,576],ready_guide=reference(16),corpse_guide=reference(15),reason='Original ready/legacy action source scales retained. One fixed extraction scale and canvas anchor; physical corpse contact registered once. No per-frame scale or bounding-box anchoring.'))
