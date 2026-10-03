"""Select reviewed continuous collapse; preserve first sampled support defect."""
import json
import produce as p

if __name__=='__main__':
    death=p.SOURCE_DIR/'death_h3_v2'
    ids=[0,8,*range(12,97,3),104,116,123]
    assert len(ids)==34
    note='All124 original RGB/RGBA frames and all124 native128 poses in both facings reviewed. Rear support bends, front elbows flex, crown/shoulders settle continuously through42-96 into the original grounded dull corpse; original scale is retained through the descent. Small original leaf/root fragment near75 is retained, never masked away. Complete lowering and grounded endpoint; all selected enlarged poses and full runtime remain pending.'
    if (death/'selection.json').exists():
        assert json.loads((death/'selection.json').read_bytes())['source_frames']==ids
    else:
        p.write(death/'selection.json',dict(source_frames=ids,frame_msec=45,loop=False,static_frame=33,review_note=note))
        p.write(death/'source_interval_review.json',dict(status='source_interval_personally_reviewed_pending_enlarged_and_full_unit_runtime',original_rgb_frames=124,matte_frames=124,source_native_facings_reviewed=['normal','reflected'],selected_frames=ids,notes=note,continuous_video_playback=False))
    p.build(death,json.loads((death/'config.json').read_bytes()))
    old=p.SOURCE_DIR/'cast_h3_v2';out=p.SOURCE_DIR/'cast_h3_v3'
    p.write(old/'rejection.json',dict(status='rejected_source',original_rgb_frames_reviewed=124,matte_frames_reviewed=124,enlarged_matched_phase_indices=[0,12,24,36,44,55,64,80,96,112,123],representative_native_frame_indices=list(range(16,32)),native_facings_reviewed=['normal','reflected'],reason='Original source repeats green/yellow/magenta backdrop transitions. Connected bark, claws and leaf edges retain unnatural purple coloration at native and enlarged scale. Limb motion is coherent but full support interval cannot qualify; no masking or recoloring connected foreground.',all_originals_and_recipes_preserved=True,continuous_video_playback=False))
    assert not (out/'sampling_submission.json').exists()
    out.mkdir(exist_ok=True);c=json.loads((old/'config.json').read_bytes())
    c['seed']=2026120305;c['guides']=[[48,1]]
    c['prompt']=('A locked painterly tactical view of the supplied original Rootmaul Behemoth on an entirely solid magenta backdrop. The backdrop remains the identical flat magenta through the whole sequence. '
                 'The wooden creature keeps its four connected root limbs, three stone claws on each front hand, forked crown, stone shoulder plates, leafy mantle, curled tail and fixed painted amber insets. '
                 'Only its near front elbow on SCREEN LEFT flexes slowly. That same clawed hand moves up to the supplied raised-hand position in front of the shoulder. The far front hand on SCREEN RIGHT and both rear feet stay planted. '
                 'Then that near elbow extends and the same hand moves down into the identical starting pose. Its hunched body, camera, scale, lighting and original colors stay fixed. '
                 'This is one quiet physical elbow flexion and extension on the same unchanging solid magenta backdrop.')
    if (out/'config.json').exists():assert json.loads((out/'config.json').read_bytes())==c
    p.write(out/'config.json',c);p.prepare(out,c);p.verify(out,c)
    for filename in ['foreground_measurement.json','extraction_settings.json']:
        if not (old/filename).exists():continue
        record=json.loads((old/filename).read_bytes())
        for guide in record.get('guides',[]):
            guide['path']=guide['path'].replace(old.name,out.name);assert p.sha(p.ROOT/guide['path'])==guide['sha256']
        p.write(out/filename,record)
    p.write(out/'correction.json',dict(prior_take=old.name,prior_rejection_sha256=p.sha(old/'rejection.json'),change='Remove numeric background/color-transition language and use quiet physical elbow flexion/extension. Same original raised-hand painting, sparse control moved55 to48, new seed. Unchanged model20-step sampler, canvas, anatomy registration and fixed matte; no connected-pixel repair.'))
    delivery=json.loads((p.SOURCE_DIR/'delivery.json').read_bytes());delivery['takes']=[x.replace('cast_h3_v2','cast_h3_v3') for x in delivery['takes']]
    if 'cast_h3_v2' not in delivery['failed_takes']:delivery['failed_takes'].append('cast_h3_v2')
    p.write(p.SOURCE_DIR/'delivery.json',delivery)
    print('Collapse34 selected, enlarged pending. Failed support retained; corrected support prepared unsubmitted.',flush=True)
