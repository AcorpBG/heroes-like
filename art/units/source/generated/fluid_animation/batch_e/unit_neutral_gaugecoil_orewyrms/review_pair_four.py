"""Select complete personally reviewed support and collapse originals."""
import json
import produce as p
O=p.SOURCE_DIR
reviews={
 'cast_h3_v1':('All124 original RGB/alpha chronological frames, enlarged0/24/44/54/68/90/123 and all124 exact128px RIGHT/reflected poses personally inspected. Near-front rock leg raises and folds beside chest, remaining three original legs support or are naturally occluded; attached valve tail straightens and returns with the original pressure hardware retained. Clear physical support routine, closed jaw, no invented effects or anatomy. Returns ready by100. Actual Godot acceptance remains required.',list(range(24,101,2))),
 'death_h3_v1':('All124 original RGB/alpha chronological frames, enlarged0/24/46/68/86/104/123 and all124 exact128px RIGHT/reflected poses personally inspected. Four original rock legs fold as mineral body lowers; mouth petals briefly open with no effects then close, original valve tail settles onto ground and three gauge/pod positions remain attached. Final123 has cold pods and grounded original corpse. Complete onset through final corpse selected; actual Godot acceptance remains required.',list(range(13,124,2)))
}
for take,(review,frames) in reviews.items():
 p.write(O/take/'review.json',dict(status='provisionally_accepted_source',review=review,reviewed_original_frames=124,reviewed_native_poses_per_facing=124))
 p.write(O/take/'selection.json',dict(source_frames=frames,frame_msec=83,matte_directory='matte_v3',review_note=review+' Original24fps sampled at12fps, no cut-around, duplicate padding, synthesis, normalization or warping.'))
 p.build(O/take,json.loads((O/take/'config.json').read_bytes()))
print('SUPPORT39_COLLAPSE56_PROVISIONAL',flush=True)
