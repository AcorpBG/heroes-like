"""Original root-limb action guides; preserve reviewed articulated idle."""
import json
from PIL import Image
import produce as p
UID='unit_neutral_rootvault_barkhulks'
B=p.ROOT/'art/animation/source/poses'/UID
IDENTITY=('Original ROOTVAULT BARKHULK from the supplied painting. One massive hunched living heartwood body, a round concentric tree-ring heartwood disk on the front chest, one long bark head facing SCREEN RIGHT with one original amber eye visible. Exactly FOUR limbs: TWO huge articulated root arms in front with broad knotted root fists, and TWO shorter weight-bearing root legs behind, near/far limbs partially occluding naturally. Arms can bear weight through their root knuckles. No extra limbs, fingers, faces or tree trunks. Preserve the original amber knots, moss, shelf fungi and leafy branch crown, bark grain, original limb proportions and camera. Original weathered painted fantasy game artwork, unchanged body scale and facing, not smooth plastic or realistic footage. ')
PLATE=(' Entire backdrop flat magenta RGB255,0,255 throughout; no scenery, floor, cast shadow, text, camera movement, zoom or cuts. Keep all legitimate root extremities and crown twigs within ample canvas margins. Fixed root contact plane y576; limbs may lift during an actual step but do not float or slide all planted contacts. No detached particles, beams, rings or invented props. ')

def reference(index):
    f=dict(json.loads((B/'packing.json').read_bytes())['frames'][index])
    f['source']=(B/f['source']).relative_to(p.ROOT).as_posix();f['alpha_noise_cutoff']=8
    if index==11:
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
    recipe('move',[12,2,3],[[38,1],[78,2]],0,'One complete heavy reciprocal knuckle-walking cycle IN PLACE: near root arm reaches and plants, opposite rear root leg lifts and passes; transfer weight, then far root arm reaches and opposite near rear leg steps. Preserve separate near/far limbs and flex original roots at their joints. Alternating planted support, no limb multiplication or lateral travel. Crown and beard respond gently to the weight transfer. End smoothly in the exact initial ready stance. ',2026108001)
    recipe('attack',[12,5,6],[[32,1],[65,2]],0,'One heavy root-fist ground slam. Keep three supporting limbs grounded while the original near root arm lifts and bends above the shoulder in a clear windup. Drive that SAME single root fist down and slightly SCREEN RIGHT once, chest and head following the blow. Retain the original two arms and two rear legs. One clear physical contact at the original slam guide, then draw the arm back and recover to exact ready. No repeated strikes, projectiles, shockwave or detached debris. ',2026108002)
    recipe('hit',[12,8],[[45,1]],0,'One brief impact recoil: chest draws back, head and crown lean away, the two original root arms flex at their shoulders and wrists while both rear legs brace. Preserve all four attached limbs and original heartwood disk. Recover smoothly to exact ready without falling, multiplying roots or turning away. ',2026108003)
    recipe('defend',[12,7],[],1,'One continuous Vaultroot Brace: bend the two rear root knees, lower the massive chest, bring the two root fists down and forward into a broad rooted guard with the heartwood disk protected. Head stays facing right, crown flexes with body weight. End held in the original compact guard guide for the final second; no return to ready and no spinning. ',2026108004)
    recipe('cast',[12],[],0,'One physical non-magical support gesture. Keep both rear legs and the far root arm planted. Lift the original near root fist deliberately toward the heartwood chest disk, touch the disk briefly as the head bows, then lower the same fist and recover to exact ready. Shoulder, elbow and root wrist articulate visibly. Four limbs stay attached, no new arms, no human fingers, no spellcasting, glow bloom or particles. ',2026108005)
    recipe('death',[12,9,11],[[48,1]],2,'One continuous heavy grounded collapse: rear root knees buckle, both root arms lose support, massive chest and head sink coherently to the original fallen side, all four limbs folding beside the body. Crown branches and beard settle after the weight lands on ground y576. Finish in the original corpse guide, still recognizable chest disk, original head facing right and mossy bark. Last second motionless, no standing back up, shrinking, disintegration or floating body. ',2026108006)
    p.write(p.SOURCE_DIR/'delivery.json',dict(takes=[c+'_h3_v1' for c in ['move','attack','hit','defend','cast','death']],preserved_accepted_clips=['idle'],visual_review=dict(status='pending',notes='All20 original poses inspected. Eight existing idle poses12-19 show shoulder/root-wrist motion and stable two rear legs with matching loop return; preserve original pixels and260ms timing. Six new actions require full chronological, enlarged and native/live review.')))
    p.write(p.SOURCE_DIR/'runtime_registration.json',dict(unit_id=UID,reference_height=256,output_scale=.5,canvas=[960,640],ground_anchor=[480,576],ready_guide=reference(12),corpse_guide=reference(11),reason='Original guide scales retained; fixed extraction scale and root contact plane. Corpse guide physically registered once, no per-frame normalization.'))
