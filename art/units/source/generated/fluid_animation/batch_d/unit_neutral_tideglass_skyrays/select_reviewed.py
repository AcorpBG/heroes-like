"""Select inspected original temporal frames; never interpolate or normalize."""
import json
import produce as p

# The two repaired action selections are added only after their original
# chronological footage passes visual review. The explicit source-frame
# contact and static poses refer to observed articulation, not model guides.
selections={
 'move_h3_v2':(list(range(0,124,2))+[123],48,None,0,'Two complete reciprocal near/far wing strokes with delayed tail/ribbon and attached bell response. Matched ready endpoints; fixed hover reference.'),
 'ranged_h3_v2':([0,16,22,24,26]+list(range(28,50,2))+[56,62]+list(range(64,92))+[96,104,112,123],33,64,66,'Broadside alignment, attached bell charge, root snap at64, wing/harness recoil and recovery. Keep original release sequence dense; no baked projectile. Shorten stationary ready/charge holds.'),
 'hit_h3_v2':([0,16,22]+list(range(24,82,2))+[88,96,112,123],33,None,32,'Head/chest draw back and wings curl after impact, bell/ribbon response, then controlled recovery. Original frame32 is readable peak recoil.'),
 'cast_h3_v2':([0,8,12]+list(range(14,98,2))+[104,112,123],33,36,36,'One physical resonator signal: both wing tips lift, head inclines and harness rings, wings and bells settle to ready. No invented spell effect; distinct one-cycle support gesture.'),
 'death_h3_v2':([0,12,20]+list(range(22,82,2))+[96,112,123],42,None,123,'Lift fails, membranes fold, torso descends and tail/ribbons/harness settle onto the ground. Final grounded corpse matches the original registered corpse guide; shorten stationary holds.'),
}

if __name__=='__main__':
 corrected=json.loads((p.SOURCE_DIR/'corrected_selections.json').read_bytes())
 for take,spec in corrected.items():
  assert spec['status']=='visually_reviewed_original_sequence'
  selections[take]=(spec['source_frames'],spec['frame_msec'],spec.get('contact_source_frame'),spec['static_source_frame'],spec['review_note'])
 assert set(selections)==set(json.loads((p.SOURCE_DIR/'delivery.json').read_bytes())['takes'])
 for take,(indices,msec,contact,static,note) in selections.items():
  assert indices==sorted(set(indices)) and indices[0]==0 and indices[-1]==123
  out=p.SOURCE_DIR/take;s=dict(source_frames=indices,frame_msec=msec,static_frame=indices.index(static),review_note=note)
  if contact is not None:s['contact_frame']=indices.index(contact)
  p.write(out/'selection.json',s);p.build(out,json.loads((out/'config.json').read_bytes()))
 p.assemble()
 print('Selected new original poses:',{k:len(v[0]) for k,v in selections.items()},sum(len(v[0]) for v in selections.values()))
