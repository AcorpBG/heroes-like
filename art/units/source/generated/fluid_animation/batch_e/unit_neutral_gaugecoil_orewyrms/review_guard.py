"""Select personally qualified complete grounded original brace."""
import json
import produce as p
O=p.SOURCE_DIR
review='All124 original RGB/RGBA chronological frames, enlarged0/24/44/54/68/96/123 and all124 exact128px RIGHT/reflected poses personally inspected. Four attached rock legs bend/spread while body and closed jaw lower between planted feet onto the original support plane. Original three pressure hardware positions and attached valve tail remain intact. Deliberate low broad brace is reached by24 and held through123; no floating, extra anatomy, effects or clipping. Background cycles colors but independently reviewed semantic alpha cleanly preserves original silhouette. Complete ready-to-brace0–32 selected, final32 held. Actual Godot acceptance remains required.'
p.write(O/'defend_h3_v2/review.json',dict(status='provisionally_accepted_source',review=review,reviewed_original_frames=124,reviewed_native_poses_per_facing=124))
p.write(O/'defend_h3_v2/selection.json',dict(source_frames=list(range(0,33,2)),frame_msec=83,matte_directory='matte_v3',review_note=review+' Original24fps sampled at12fps; no cut-around, duplicate padding, synthesis, normalization or warping.'))
p.build(O/'defend_h3_v2',json.loads((O/'defend_h3_v2/config.json').read_bytes()))
b=json.loads((O/'unit_brief.json').read_bytes());b['defend_key_status']='New original four-leg grounded guide and all124 source RGB/RGBA/enlarged/both-facing exact128px poses personally qualified provisionally; selected17 complete ready-to-low-brace poses, actual Godot pending.';p.write(O/'unit_brief.json',b)
p.assemble()
print('SIX_ORIGINAL_ACTIONS_ASSEMBLED',len(json.loads((O/'handoff.json').read_bytes())['units'][0]['frames']),flush=True)
