"""Rebuild only reviewed clean Flaremast candidates from unchanged H3 pixels."""
import argparse,json
import produce as p

SELECTED={
 'defend_h3_v2':dict(source_frames=[0]+list(range(12,41,2))+[123],frame_msec=83,review_note='124 chronological originals reviewed; dedicated reciprocal knee bend into held kneeling guard, brass launcher red chamber/two grips, stationary full mast and canisters retained; selected dense transition12–40 and terminal held123. No effect removal or erased geometry. Enlarged light/dark and native candidate review; continuous temporal preview remains blocked. Pending coordinator acceptance.'),
 'cast_h3_v2':dict(source_frames=[0]+list(range(20,41,2))+[64,96]+list(range(104,121,2))+[123],frame_msec=83,review_note='124 chronological originals reviewed; physical nonmagic empty right-palm signal while left hand supports unchanged brass red-chamber launcher, right trigger grip restored. Dense raising20–40 and recovery104–120, sparse reviewed held64/96, exact ready123. No effect removal or erased geometry. Enlarged light/dark and native candidate review; continuous temporal preview remains blocked. Pending coordinator acceptance.')}

if __name__=='__main__':
 a=argparse.ArgumentParser();a.add_argument('--include-death',action='store_true');args=a.parse_args()
 if args.include_death:
  SELECTED['death_h3_v2']=dict(source_frames=[0]+list(range(12,21,2))+[28]+list(range(34,49,2))+list(range(52,105,4))+[106,123],frame_msec=83,review_note='All124 chronological originals and enlarged light/dark body, weapon, mast junction and final corpse phases reviewed. Grounded kneel to side collapse, launcher retained; complete mast settling with all canisters and tripod attached through106, terminal settled123. Dense body12–48 and mast52–106 transition preserved, no truncated event, effect removal or geometry erasure. Fixed native registration. Continuous temporal preview remains blocked. Pending coordinator acceptance.')
 for take,selection in SELECTED.items():
  out=p.SOURCE_DIR/take;c=json.loads((out/'config.json').read_bytes());p.write(out/'selection.json',selection);p.build(out,c)
 registration=json.loads((p.SOURCE_DIR/'runtime_registration.json').read_bytes())
 delivery=dict(unit_id='unit_neutral_flaremast_crews',takes=list(SELECTED),generation_takes=[clip+'_h3_v'+str(v) for v in [1,2] for clip in ['move','attack','ranged','hit','defend','cast','death']],preserved_accepted_clips=['idle'],runtime_scale_multiplier=registration['runtime_scale_multiplier'],runtime_scale_reason='One uniform .90 conversion for ALL newly authored actions based on decoded ready versus retained articulated idle; output scale .45, no per-frame normalization.',source_anchor_adjustment=registration['source_anchor_adjustment'],source_registration_reason=registration['basis']['equation'],remaining_gaps=['move','attack','ranged','hit']+([] if args.include_death else ['death']),visual_review=dict(status='pending',notes='Clean partial guard/support/death candidate; full124 chronological originals and enlarged light/dark phases inspected. Fixed .45/[470,576] registration matches retained8-pose idle. Continuous temporal preview blocked. Candidate native/runtime checks and coordinator acceptance required. Full unit remains incomplete.'))
 p.write(p.SOURCE_DIR/'delivery.json',delivery);p.assemble()
 handoff=json.loads((p.SOURCE_DIR/'handoff.json').read_bytes())['units'][0]
 assert all(f['scale']==.45 and f['anchor']==[470,576] for f in handoff['frames'])
 print('Clean candidate:',','.join(handoff['clips']),'frames',len(handoff['frames']),'scale.45 anchor[470,576]')
