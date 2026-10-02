"""Select reviewed original chronological motion; native acceptance pending."""
import json
import produce as p

def choose(take, indices, msec, note, contact=None):
    out=p.SOURCE_DIR/take
    s=dict(source_frames=indices,frame_msec=msec,review_note=note,
           retiming_reason='Preserve original observed frames and 24fps timestamps; action-specific runtime tempo reviewed through the actual battle clock. No interpolation, reverse playback or per-frame normalization.')
    if contact is not None:s['contact_frame']=contact
    p.write(out/'selection.json',s)
    p.build(out,json.loads((out/'config.json').read_bytes()))

if __name__=='__main__':
    choose('move_h3_v1',list(range(20,37)),50,'One reciprocal cycle: opposite planted contacts, weight transfer, passing knees and foot extension. Original right hook and left forearm shield retained. Matching extended contact endpoints; later repeated cycles excluded.')
    choose('attack_h3_v1',list(range(12,50))+list(range(72,89)),33,'Right hook rises above right shoulder, turns briefly edge-on during wrist rotation at34-35, then sweeps forward in full crescent profile with shield retained. Windup, contact42 and articulated recovery retained; matching extended hold49-72 shortened.',30)
    choose('hit_h3_v1',list(range(27,59)),33,'Continuous backward torso recoil and knee flex followed by forward recovery. Right hook and left keel shield retained throughout; no unrelated collapse or effects.')
    choose('defend_h3_v1',list(range(20,35)),42,'Dedicated planted knee bend and forward left-shield brace. Original short right hook raised across waist. Terminal guard held, no idle alias.')
    choose('cast_h3_v1',list(range(24,44))+list(range(72,85)),42,'Physical support signal: right hook raised above right shoulder, then lowered into recovery; left forearm retains shield. Matching stationary raised hold43-72 shortened. No invented magic or forward attack.',13)
    choose('death_h3_v1',list(range(31,88)),33,'Continuous knee descent, side roll, grounded head-left collapse and settling legs. Attached left forearm initially supports keel shield above fallen torso then relaxes and lowers it; right hook rests on ground. Entire interval retained, including arm relaxation; final grounded corpse persists.')
    p.assemble()
    print('Six actions assembled:209 original new poses; native review pending.')
