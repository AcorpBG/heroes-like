"""Select the personally reviewed full independent nod and assemble pending unit."""
import json
import produce as p

if __name__ == '__main__':
    out = p.SOURCE_DIR / 'cast_h3_v5'
    assert not (out / 'selection.json').exists()
    ids = [0,12,16,20,*range(24,49,3),56,64,80,88,92,96,100,104,108,112,116,123]
    assert len(ids) == 25
    durations = [55 if i not in [56,64,80] else 120 for i in ids]
    note = ('All124 original RGB/RGBA frames and all124 fixed128-reference poses in each facing personally inspected. '
            'All25 selected original/matte poses inspected enlarged. One rear-knee/front-elbow supported shoulder/crown nod, '
            'low pause around48-92 and complete recovery96-123. Fixed painted chest and hip insets, stable original bark/stone/moss, '
            'four connected limbs and curled tail; no burst or connected recoloring. Trim only redundant ready and low holds; '
            'retain complete lowering and recovery. Full unit runtime acceptance remains pending.')
    p.write(out / 'selection.json', dict(source_frames=ids,frame_msec=55,frame_durations_msec=durations,loop=False,review_note=note))
    p.write(out / 'source_interval_review.json', dict(status='source_interval_personally_reviewed_pending_full_unit_runtime',original_rgb_frames=124,matte_frames=124,source_native_facings_reviewed=['normal','reflected'],selected_frames=ids,selected_enlarged_frames_reviewed=25,all_selected_matched_rgb_rgba_enlarged_reviewed=True,original_pixel_proof_sha256=p.sha(out / 'original_pixel_proof.json'),notes=note,continuous_video_playback=False))
    registration = json.loads((p.SOURCE_DIR / 'runtime_registration.json').read_bytes())
    registration['rejected_painted_support_guide'] = registration.pop('support_guide')
    registration['support_guide'] = json.loads((out / 'config.json').read_bytes())['references'][1]
    registration['support_reason'] = 'Separate grounded nod source using original low painting; no reuse of guard footage.'
    p.write(p.SOURCE_DIR / 'runtime_registration.json', registration)
    delivery = json.loads((p.SOURCE_DIR / 'delivery.json').read_bytes())
    for take in delivery['takes']:
        folder=p.SOURCE_DIR/take
        p.build(folder,json.loads((folder/'config.json').read_bytes()))
    p.assemble()
    brief=json.loads((p.SOURCE_DIR/'brief.json').read_bytes())
    brief['source_status']='six_sources_reviewed_pending_full_unit_native_acceptance'
    brief['provisional_selected_pose_count']=165
    p.write(p.SOURCE_DIR/'brief.json',brief)
    print('Six sources assembled pending acceptance:165 new poses,8 original idle preserved at publication.',flush=True)
