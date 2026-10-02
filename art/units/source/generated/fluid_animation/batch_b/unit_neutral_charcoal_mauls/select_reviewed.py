"""Select reviewed original chronology without synthetic or duplicated motion."""
import json
import produce as p
def select(take,indices,note,contact=None,msec=42,hold=None):
 out=p.SOURCE_DIR/take;s=dict(source_frames=indices,frame_msec=msec,review_note=note)
 if contact is not None:s['contact_frame']=indices.index(contact)
 if hold:s['frame_durations_msec']=[hold.get(i,msec) for i in indices]
 p.write(out/'selection.json',s);p.build(out,json.loads((out/'config.json').read_bytes()))
def first_actions():
 select('move_h3_v1',[0,6,8]+list(range(10,41))+[42],
  'All124 chronological originals and enlarged alternate legs/boots and two-handed maul grips reviewed. Keep complete first reciprocal cycle: screen-left boot lifts behind12-16, screen-right knee passes16-20 and extends22-26, opposite support/passing28-34, both boots return planted38-42. Ready42-to0 seam reviewed. Later repeated walks remain in original video. Same two arms/two legs, original shaft, head, apron and coal basket; no duplicates, reversal, interpolation or anatomical normalization. Native review required.')
 select('hit_h3_v1',[0,8,16,18]+list(range(19,29))+[34,48,62]+list(range(63,78))+[84,96,123],
  'All124 chronological originals and enlarged chest/backward lean, grounded boots and two real hand grips reviewed. Recoil19-28, brief backwards balance hold, shoulders/knees recover63-77 into original ready. No incoming object or impact effect. Original two-handed maul and two arms/legs retained. Shorten unchanged hold only; no synthesized motion, duplicate/reversed/interpolated poses or posture normalization. Native review required.',hold={28:126})
 select('defend_h3_v1',[0,8,16,18,20]+list(range(21,31))+[34,38,42,46,72,96,123],
  'All124 chronological originals and enlarged both hands/shaft, shoulders, bent knees and stable boots reviewed. Raise same shaft21-23 and crouch24-28; wrists adjust into dedicated held maul guard through123. Two original hands remain on original shaft, no shield or invented equipment. Retain actual transition phases and final held stance, shorten unchanged holds only; no duplication/reversal/interpolation or pose normalization. Native review required.',24)
if __name__=='__main__':first_actions()
