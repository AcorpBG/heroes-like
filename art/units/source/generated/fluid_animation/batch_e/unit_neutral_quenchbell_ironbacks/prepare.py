"""Original armored quadruped guides; preserve articulated eight-pose idle."""
import json
from PIL import Image
import produce as p

UID='unit_neutral_quenchbell_ironbacks'
B=p.ROOT/'art/animation/source/poses'/UID
IDENTITY=('Original QUENCHBELL IRONBACK from the supplied painted references. One massive armored rhinoceros-like quadruped facing SCREEN RIGHT, exactly FOUR stout hoofed legs: two front and two rear, near and far limbs partially occluding naturally. Gray-brown shaggy fur under overlapping dark steel dorsal plates with brass edging, original red/orange pressure seams and circular red gauges on shoulder/back. One original long curved brass bell horn on the nose and original smaller head horns; keep length, placement and metal shape unchanged. Original red eyes, muzzle, armored leg cuffs and short tufted tail. No human arms/hands, extra feet, rider, weapons, muzzle transformation or new lights. Preserve original weathered painted fantasy artwork, three-quarter camera, body proportions and anatomical scale. ')
PLATE=('Entire background flat magenta RGB255,0,255 throughout; no scenery, floor texture, shadow, dust, shockwaves, speed lines, projectiles, particles or floating props. Fixed orthographic camera, no zoom, pan or cut. Keep all horns, hoof tips and tail within generous margins. Ground contact plane y576; moving feet lift legitimately while at least other feet support the mass. Planted hooves do not skate; no root travel during gait. ')

def reference(index):
    f=dict(json.loads((B/'packing.json').read_bytes())['frames'][index])
    f['source']=(B/f['source']).relative_to(p.ROOT).as_posix()
    f['alpha_noise_cutoff']=8
    if index in range(2,12):
        im,offset=p.source_pose(f,8)
        bounds=im.getchannel('A').point(lambda a:255 if a>=128 else 0).getbbox()
        delta=offset[1]+bounds[3]
        f['anchor']=[f['anchor'][0],round(f['anchor'][1]+delta/f['scale'])]
        # One rigid legacy-reference translation, measured from the original
        # largest shoulder pressure gauge against accepted ready pose12.
        # This aligns the two authored sheets, not each generated video frame.
        f['guide_offset']=[94,0]
    return f

def recipe(clip,indices,guides,last,action,seed):
    out=p.SOURCE_DIR/(clip+'_h3_v1');out.mkdir(exist_ok=True)
    assert not (out/'sampling_submission.json').exists(),'Submitted original is immutable'
    c=dict(unit_id=UID,clip=clip,canvas=[960,640],anchor=[480,576],scale=.5,key_rgb=[255,0,255],seed=seed,references=[reference(i) for i in indices],guides=guides,last=last,prompt=(IDENTITY+action+PLATE).strip(),tiled_decode=dict(tile_size=512,overlap=64,temporal_size=16,temporal_overlap=4))
    p.write(out/'config.json',c);p.prepare(out,c);p.verify(out,c)
    print('Prepared',clip,[(i,Image.open(out/f'guide_{j}_rgba.png').getbbox()) for j,i in enumerate(indices)],flush=True)

if __name__=='__main__':
    recipe('move',[12,2,4,3],[[28,1],[60,2],[92,3]],0,'One complete heavy reciprocal quadruped walk IN PLACE: near front hoof lifts/passes/plants while far rear hoof steps, transfer weight then far front and near rear step. Four legs remain separate and attached, natural near/far occlusion, knees and fetlocks flex. Horn/head bob with weight and original short tail sways; dorsal plates stay attached without morphing. Finish in exact initial ready stance. ',2026108201)
    recipe('attack',[12,5,6],[[32,1],[62,2],[72,2]],0,'One Bellhorn Ram: brace rear hooves, lift muzzle slightly in the original windup, lower the SAME curved brass nose horn and drive head/shoulders forward SCREEN RIGHT once into original contact posture. Four legs support the thrust, no jumping or running away. Small local physical lunge followed by pulling head and shoulder back to exact ready; horn does not detach, shorten, multiply or become a fist. No invented impact effect. ',2026108202)
    recipe('hit',[12,8],[[45,1]],0,'One brief impact recoil: muzzle and horn draw back, original foreleg knees flex, shoulder recoils against rear-hoof support. Preserve all four legs, original muzzle and continuous armored silhouette. Recover to exact initial ready without collapsing, rearing or turning away. ',2026108203)
    recipe('defend',[12,7],[],1,'One continuous dedicated defensive brace: spread and plant the same original four hooves, bend foreleg knees, lower shoulder slightly and point the original horn forward/down in compact held guard. Keep rigid horn and attached layered steel plates. Finish held in original guard, do not return to ready or invent more legs. ',2026108204)
    recipe('cast',[12,17],[[50,1]],0,'One physical non-magical support gesture: bow the original horn/head deliberately, lift the near FRONT hoof slightly with a clear knee/fetlock flex, paw downward once and plant that same hoof, then raise head to exact ready. Other three legs support the mass throughout. Original red gauges remain part of armor; no magical effects, human gestures or new limbs. ',2026108205)
    recipe('death',[12,9,10,11],[[38,1],[70,2],[96,3]],3,'One slow grounded collapse: foreleg knees buckle, head/horn lower, original heavy shoulder sinks onto one side while rear legs fold, followed by body/plates settling into original side-rest corpse. Remain supported by a hoof/knee/body contact throughout, no jumping or upward roll. Four attached legs rest beside the torso. Original horn/muzzle/fur and gauges remain recognizable, red seams settle dimly without new effects. Last second motionless in original corpse, no shrink/disintegration or standing back up. ',2026108206)
    p.write(p.SOURCE_DIR/'delivery.json',dict(takes=[k+'_h3_v1' for k in ['move','attack','hit','defend','cast','death']],preserved_accepted_clips=['idle'],visual_review=dict(status='pending',notes='All20 original poses and curated identity inspected. Original eight-pose idle has foreleg/knee/head/tail articulation with ready return; preserve original battle/map pixels and260ms timing. Six dedicated H3 actions require full chronological/native/live review.')))
    p.write(p.SOURCE_DIR/'runtime_registration.json',dict(unit_id=UID,reference_height=256,output_scale=.5,canvas=[960,640],ground_anchor=[480,576],ready_guide=reference(12),ground_registered_guides={str(i):reference(i) for i in range(2,12)},legacy_sheet_guide_offset=[94,0],reason='Preserve original guide scales; one rigid legacy-sheet translation aligns its original largest shoulder gauge with accepted ready12. Register actual guide hoof/knee/body contacts once; never per-video-frame stabilization or normalization.'))
