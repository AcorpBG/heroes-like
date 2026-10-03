"""Correct only the rejected release take; submitted originals are immutable."""
import json
import prepare as prep
import produce as p

if __name__ == '__main__':
    out=p.SOURCE_DIR/'ranged_h3_v2'
    assert not (out/'sampling_submission.json').exists()
    out.mkdir(exist_ok=True)
    action=('One continuous quiet physical feather stretch and shoulder recoil. '
            'Both original taloned feet remain planted while the original wings hinge '
            'up into the supplied upright fan, then the chest and head rock backward '
            'slightly into the supplied physical recoil. The original wings fold '
            'smoothly and both talons relax back to the initial ready pose. '
            'All amber markings and brass oval insets stay the same painted material '
            'throughout. The only visible motion is the bird\'s connected feathers, '
            'neck, shoulders and talons on the uniform plain plate. ')
    c=dict(unit_id=prep.UID,clip='ranged',canvas=[960,704],anchor=[480,640],
           scale=.5,key_rgb=[0,255,255],seed=2026109403,
           references=[prep.reference(i) for i in [16,9,10]],
           guides=[[36,1],[52,2]],last=0,
           prompt=(prep.IDENTITY+action+prep.PLATE).strip(),
           tiled_decode=dict(tile_size=512,overlap=64,temporal_size=16,temporal_overlap=4))
    p.write(out/'config.json',c);p.prepare(out,c);p.verify(out,c)
    d=json.loads((p.SOURCE_DIR/'delivery.json').read_bytes())
    d['takes']=['ranged_h3_v2' if t=='ranged_h3_v1' else t for t in d['takes']]
    d['rejected_takes']=list(dict.fromkeys(d.get('rejected_takes',[])+['ranged_h3_v1']))
    d.setdefault('rejections',{})['ranged_h3_v1']=dict(
        reason='All124 original RGB and all124 enlarged RGBA frames personally reviewed. Physical wing fan/recovery are coherent, but frames42-43 contain a bright connected fire burst over the original forward wing; later detached crescent44-46 does not excuse the attached defect. No source pixels erased or matte thresholds changed.',
        source_frames_reviewed=124,alpha_frames_reviewed=124,replacement='ranged_h3_v2',
        correction='Use original ready16, upright fan9 and quiet physical recoil10; intermediate fan36/recoil52 and matching ready endpoints. Describe fixed painted materials and connected physical anatomy only. Game renderer retains projectile ownership.')
    d['visual_review'].setdefault('source_review',{})['ranged_h3_v1']=dict(
        status='rejected',all_original_rgb_frames=124,all_enlarged_matte_frames=124,
        reason='Connected source fire burst overlaps original wing at42-43.',replacement='ranged_h3_v2')
    p.write(p.SOURCE_DIR/'delivery.json',d)
    print('PREPARED_RANGED_CORRECTION_ORIGINALS_UNCHANGED',flush=True)
