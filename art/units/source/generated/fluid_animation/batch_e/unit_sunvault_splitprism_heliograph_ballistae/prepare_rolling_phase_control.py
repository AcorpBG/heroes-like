"""Use the reviewed alternate ORIGINAL painted spoke phase as video control."""
import copy
import json
import produce as p


def main():
    S=p.SOURCE_DIR;folder=S/'rolling_rotation_key_v4'
    matte=json.loads((folder/'matte_spatial_plate.json').read_bytes())
    assert p.sha(folder/'matte_spatial_plate.png')==matte['rgba_sha256']
    p.write(folder/'visual_review.json',dict(
        status='qualified_original_video_guide',reviewer='coordinator',
        examined='Original1466x1073 RGB, initial semantic extraction, spatial soft-edge correction on full dark/light backgrounds, fixed native128/256 registration in both facings, original rolling guide960x704.',
        findings='The alternate painted wheel has a visible half-spoke phase offset: lower near-wheel hub ray/gap differs from the original rolling phase. Two wheel rims and gold hubs remain fixed in the same axle; three star supports stay folded, single operator retains both hand grips, blue front and amber rear rods and round mirror. New extraction removes pale plate contamination around spoke holes/rods while retaining original alpha and all opaque RGB byte for byte.',
        anatomical_scale='Fixed .21 for this1466x1073 original, versus .45 for960x704 original rolling guide. Near-wheel anatomical diameter original135px*.45=60.75 reference pixels, alternate287px*.21=60.27. Anchor746,899 follows wheel ground/central chassis, never a changing whole-sprite bounding box.',
        limits='A useful original guide, not an accepted animation. H3 must actually rotate the wheels continuously between guides without reshaping rims, flickering spoke count or changing the chassis.'))
    c=copy.deepcopy(json.loads((S/'move_h3_v2/config.json').read_bytes()))
    ref=json.loads((folder/'matte_spatial_reference.json').read_bytes())
    ref['source_sha256']=matte['rgba_sha256']
    c['references'].append(ref)
    c['guides']=[[16,4],[32,2],[48,4],[64,3],[80,4],[96,1],[112,4]]
    c.update(seed=2026100388,last=0,correction_of='move_h3_v2',
        prompt=c['prompt'].split('Use the same flat pale blue-gray background')[0]+'Use the same flat pale blue-gray background over the whole image in every frame. Continuous wheeled travel cycle in place. Both existing blue spoke disks must rotate visibly in the same clockwise direction around their stationary gold hubs. Between each supplied spoke-phase guide, show intermediate spoke angles; continue through the next repeated pattern rather than reversing or settling on a stationary wheel. The fixed ivory-and-gold wheel rims do not grow, wobble or change perspective; the one axle and vertical blue chassis plate remain stationary. Exactly three original star-foot struts stay folded UP off the ground throughout. The single operator turns the existing crank with both hands, visibly bending elbows and knees. Cape follows. Both original crystal rods remain attached, inactive, and the round mirror remains mounted. All wheel diameters, chassis proportions, three folded supports and operator size remain consistent with the supplied references. Fixed elevated tactical camera and central axle; the engine supplies travel so do not translate or zoom. Smooth return to the original first spoke/arm phase at the end. No glows, flash, beam, particles or extra parts.',
        visual_review='pending original video; original wheel phase and anatomical registration personally reviewed',selection='not_selected')
    name='move_h3_v3';target=S/name;target.mkdir(exist_ok=True)
    assert not (target/'sampling_submission.json').exists()
    p.write(target/'config.json',c);p.prepare(target,c);p.verify(target,c)
    print('ALTERNATE_ORIGINAL_WHEEL_PHASE_QUALIFIED_AS_GUIDE; MOVE_V3_PREPARED_UNSUBMITTED',flush=True)


if __name__=='__main__':main()
