"""Retain observed chronological action intervals after personal CPU review."""
import json
import produce as p
if __name__=='__main__':
 move=list(range(16,63,2))
 attack=[0,12,*range(14,31,2),38,46,52,*range(53,65),68,74,80,86,92,98,104,110,116,123]
 for clip,ids,note in [
 ('move',move,'All124original RGB and RGBA plus both facings at reference128 and14 enlargedmatched RGB/RGBA phase views personally inspected. Retain the first complete reciprocal four-limb cycle16-62: near claw lift/reach/contact/load, opposite front claw lift/reach/load, rear root knee/hip support and matching ready seam. The second generated cycle and exterior ready holds remain in original video. Stable forked crown/stone plates/three-clawed hands/leafy mantle; no effects or added limbs.'),
 ('attack',attack,'All124original RGB/RGBA plus both reference128facings and20 enlargedmatched phase views personally inspected. One complete rear-supported rise, two-front-hand downward rotation/contact62 and continuous return to original ready. Both claw faces rotate away during brief fast stroke57-59; original motion blur remains, never omitted or masked. Four connected limbs, original crown/stone plates/amber materials retained. Native actual battle action validation remains pending.')]:
  d=p.SOURCE_DIR/(clip+'_h3_v1');assert not (d/'selection.json').exists();assert ids==sorted(set(ids))
  s=dict(source_frames=ids,frame_msec=64 if clip=='move' else 42,review_note=note,retiming='Original124frames24fps remain intact. Select complete active cycle/contact/recovery in chronological order; trim only exterior or long physically stable holds. Move12fps samples retimed64ms for engine travel; rapid contact samples42ms retain source24fps. No duplicates, reverse frames or generated interpolation.')
  if clip=='attack':s['contact_frame']=ids.index(62);s['frame_durations_msec']=[70 if 14<=i<=30 or 68<=i<=110 else 42 for i in ids];s['frame_durations_msec'][ids.index(38)]=100;s['frame_durations_msec'][ids.index(46)]=80
  p.write(d/'selection.json',s);c=json.loads((d/'config.json').read_bytes());p.build(d,c)
  p.write(d/'source_interval_review.json',dict(status='source_interval_personally_reviewed_pending_full_unit_runtime',original_rgb_frames=124,matte_frames=124,source_native_facings_reviewed=['normal','reflected'],selected_frames=ids,notes=note,continuous_video_playback=False))
 print('Selected complete move/contact cycles',len(move),len(attack),'personal full-unit review still pending')
