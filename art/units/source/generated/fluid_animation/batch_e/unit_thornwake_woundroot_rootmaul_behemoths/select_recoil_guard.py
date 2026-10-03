"""Retain reviewed corrected physical reaction and original low-guard transition."""
import json
import produce as p

if __name__=='__main__':
    selections={
        'hit_h3_v2':[0,8,12,16,20,24,28,32,36,40,44,48,52,56,60,64,68,72,76,80,88,96,104,116,123],
        'defend_h3_v2':[0,*range(2,33,2),48,64,96,123]}
    notes={
        'hit_h3_v2':'All124 original RGB/RGBA and all124 fixed128-reference poses per facing personally reviewed. Stable original painted plate/materials, no purple subject edge. One modest rear-supported shoulder and elbow rock, lower recoil around44 and complete return through96-123; retain full reaction/recovery with three-clawed hands and four connected root limbs. Source enlarged representative phases reviewed; all selected enlarged poses and actual full-unit runtime remain pending.',
        'defend_h3_v2':'All124 original RGB/RGBA and all124 fixed128-reference poses per facing personally reviewed. Stable painted plate/materials without the prior purple subject edge. Two front hands lower into a compact low crouch with both rear root feet supported; settling through32 and sustained guard through123. Trim only redundant stationary hold samples. All selected enlarged poses and actual full-unit runtime remain pending.'}
    for name,ids in selections.items():
        folder=p.SOURCE_DIR/name
        assert not (folder/'selection.json').exists() and ids==sorted(set(ids))
        selection=dict(source_frames=ids,frame_msec=32 if name.startswith('hit') else 45,
                       review_note=notes[name],retiming='Chronological original frames only; every reaction and guard transition phase retained. Sparse stable hold samples have explicit durations. No reversal, duplication, interpolation or pose normalization.')
        if name.startswith('defend'):
            selection['frame_durations_msec']=[45 if i<=32 else 160 for i in ids]
        p.write(folder/'selection.json',selection)
        p.write(folder/'source_interval_review.json',dict(
            status='source_interval_personally_reviewed_pending_enlarged_and_full_unit_runtime',
            original_rgb_frames=124,matte_frames=124,source_native_facings_reviewed=['normal','reflected'],
            selected_frames=ids,notes=notes[name],continuous_video_playback=False))
        p.build(folder,json.loads((folder/'config.json').read_bytes()))
    print('Reviewed corrected intervals selected:',{name:len(ids) for name,ids in selections.items()},flush=True)
