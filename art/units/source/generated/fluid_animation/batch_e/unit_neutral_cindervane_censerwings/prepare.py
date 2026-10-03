"""Censerwing original-pixel guides, action beats and anatomical registration."""
import json
import numpy as np
from scipy.ndimage import label
from PIL import Image
import produce as p

UID='unit_neutral_cindervane_censerwings'
B=p.ROOT/'art/animation/source/poses'/UID
IDENTITY=('The original CINDERVANE CENSERWING bird in the supplied painted references, facing SCREEN RIGHT. Preserve the same narrow curved red beak, white sinuous throat, dark charcoal and red feathers with ivory stripes and oval amber ember markings, swept curling red crest, original brass cylindrical chest censer with glowing oval vents, exactly TWO dark thin legs ending in red hooked talons, and the same attached curled ember-feather tail. The original FOUR feathered wings are two larger upper wings and two smaller lower wings; folded far wings may be naturally occluded, never duplicate a visible wing. Preserve the supplied original feather contours and body proportions, same orthographic three-quarter side camera and surface detail. ')
PLATE=('Fixed camera and body reference, uniform flat cyan background RGB0,255,255. Keep the entire original bird, beak, talons, wing tips, crest and attached tail inside the canvas. Tail ember markings and chest vents are painted body details and remain attached. The shot contains only this bird against the plain plate. Living feet and flight clearance follow the supplied original guides; logical ground reference y640. ')

def reference(index):
    f=dict(json.loads((B/'packing.json').read_bytes())['frames'][index])
    f['source']=(B/f['source']).relative_to(p.ROOT).as_posix()
    f['alpha_noise_cutoff']=8
    foreign={3:[899,174,905,186],5:[374,482,385,491],8:[94,910,115,916],13:[304,1042,308,1050]}.get(index)
    if foreign:
        # Only personally identified neighboring-sheet fragments.
        # Original source PNGs and all connected bird pixels remain untouched.
        alpha=np.asarray(Image.open(p.ROOT/f['source']))[:,:,3]
        mask=np.zeros(alpha.shape,dtype=bool)
        for x0,y0,x1,y1 in f['rects']:mask[y0:y1,x0:x1]=alpha[y0:y1,x0:x1]>8
        labels,n=label(mask,np.ones((3,3),dtype=np.uint8))
        counts=np.bincount(labels.ravel());counts[0]=0;body=int(counts.argmax())
        x0,y0,x1,y1=foreign
        assert not np.any(labels[y0:y1,x0:x1]==body)
        assert 0<int(mask[y0:y1,x0:x1].sum())<64
        rects=[]
        for a,b,c,d in f['rects']:
            ix0,iy0,ix1,iy1=max(a,x0),max(b,y0),min(c,x1),min(d,y1)
            if ix0>=ix1 or iy0>=iy1:rects.append([a,b,c,d]);continue
            rects.extend(r for r in [[a,b,c,iy0],[a,iy0,ix0,iy1],[ix1,iy0,c,iy1],[a,iy1,c,d]] if r[0]<r[2] and r[1]<r[3])
        f['rects']=rects
        f['crop_recipe']=dict(kind='reviewed_foreign_original_sheet_fragment',excluded_rectangle=foreign,source_pixels=int(mask[y0:y1,x0:x1].sum()),complete_connected_original_bird_preserved=True)
    if index<16:
        f['guide_offset']=[64,0 if index>=13 else 16]
    return f

def recipe(clip,indices,guides,last,action,seed):
    out=p.SOURCE_DIR/(clip+'_h3_v1');out.mkdir(exist_ok=True)
    assert not (out/'sampling_submission.json').exists(), 'Submitted original is immutable'
    c=dict(unit_id=UID,clip=clip,canvas=[960,704],anchor=[480,640],scale=.5,key_rgb=[0,255,255],seed=seed,references=[reference(i) for i in indices],guides=guides,last=last,prompt=(IDENTITY+action+PLATE).strip(),tiled_decode=dict(tile_size=512,overlap=64,temporal_size=16,temporal_overlap=4))
    p.write(out/'config.json',c);p.prepare(out,c);p.verify(out,c)
    print('PREPARED',clip,[(i,Image.open(out/f'guide_{j}_rgba.png').getbbox()) for j,i in enumerate(indices)],flush=True)

if __name__=='__main__':
    recipe('move',[16,2,4,3],[[24,1],[52,2],[80,3],[104,0]],0,'One complete wingbeat cycle in place: the original large and small feather wings hinge upward, sweep through level passing flight, lower, then recover to the initial ready fold. The original two talons tuck naturally during the flight phase and uncurl during return. Attached feather tail and crest respond to the physical stroke. Keep the original censer attached to the breast. ',2026109301)
    recipe('attack',[16,5,6],[[16,1],[34,2],[52,2],[72,0],[100,0]],0,'One physical forward beak jab: wings draw into the original windup, neck reaches horizontally once with the same original curved beak in the supplied contact pose, two talons flex, then neck retracts and wings settle into exact initial ready. The bird keeps its same chest censer. This is a short head-and-neck exercise, followed by recovery; the plain shot depicts only the visible bird anatomy. ',2026109302)
    recipe('ranged',[16,9],[[50,1]],0,'One smooth continuous aiming and physical release motion: the original throat lifts and chest censer tilts slightly as the original wings spread into the supplied symmetrical aim pose, then a visible single small chest/head recoil and smoothly return through successive original wing positions to initial ready. The image shows the original bird and its attached plumage only; the separate game renderer supplies the shot. ',2026109303)
    recipe('hit',[16,12],[[42,1]],0,'One continuous physical recoil and recovery: neck curves backward through successive positions, shoulders flinch and original feather wings spread into the supplied recoil. Two original talons flex, then both legs, wings and head smoothly recover to exact original ready. Body remains intact and upright. ',2026109304)
    recipe('defend',[16,7],[[56,1]],1,'One continuous feather-wing protective brace: the original wings progressively hinge and fold in front of the chest censer, head dips and both talons tense below the body. Finish holding the compact supplied original guard with folded wings. Keep the wings folded through the end. ',2026109305)
    recipe('cast',[16,9],[[50,1]],0,'One continuous physical support acknowledgement for this noncaster: both original taloned feet stay grounded while the original feather wings hinge smoothly into the supplied upright feather-fan gesture. Briefly dip the head and flex the original talons, chest censer staying attached, then smoothly fold wings and raise head back to initial ready. This is a calm standing acknowledgement with attached feather-tail response. ',2026109306)
    recipe('death',[16,13,14,15],[[28,1],[56,2],[88,3]],3,'One continuous exhausted collapse: wings sag, both original legs lose support, the breast and original brass censer lower, neck folds sideways and the body settles into the supplied original grounded side-resting bird. Fold all original wings beside the body and settle the attached tail and both talons. Hold the supplied corpse through the final second. ',2026109307)
    p.write(p.SOURCE_DIR/'delivery.json',dict(takes=[x+'_h3_v1' for x in ['move','attack','ranged','hit','defend','cast','death']],preserved_accepted_clips=['idle'],visual_review=dict(status='pending',notes='Original curated identity and all24 original native paintings personally inspected; eight existing idle phases show feather-wing/talon articulation and compatible return, pending actual Godot review before preservation. No new H3 action accepted yet. Actual battle source faces right although curated identity faces left.')))
    p.write(p.SOURCE_DIR/'runtime_registration.json',dict(unit_id=UID,canvas=[960,704],output_scale=.5,ground_anchor=[480,640],ready_reference=reference(16),legacy_living_guide_offset=[64,16],legacy_grounded_guide_offset=[64,0],measurement=dict(original_idle_censer_reference=[288,136],accepted_idle_censer_reference=[320,144]),rule='A single rigid source-sheet translation aligns original brass breast censer with accepted idle16. Preserve all authored per-painting scales and original corpse ground clearance; no per-video-frame alignment, normalization, stabilization or generated motion.'))
