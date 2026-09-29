"""Rebuild reviewed original-frame selections; native acceptance is separate."""
import json
import produce as p

if __name__=='__main__':
 start=list(range(8,18))+[20,28]
 strike=list(range(0,124,3))
 recovery=[64,68]+list(range(69,81))+[86,96,106,114,123]
 for take,frames in [('attack_h3_v1',start+recovery),('attack_strike_h3_v3',strike)]:
  out=p.SOURCE_DIR/take
  note=('Only the reviewed original anticipation and recovery outside rejected trail frames; full take remains rejected. ' if take=='attack_h3_v1' else 'All124 original phases reviewed: clean bent-elbow progression into full extension, no trail or duplicate blade; original knife, shield, anatomy and grounded stance maintained. ')
  p.write(out/'selection.json',dict(source_frames=frames,frame_msec=30,review_note=note+'Three-frame source sampling in the slow corrected interval deliberately retimed to30ms for a readable game strike. Native review pending.'))
  p.build(out,json.loads((out/'config.json').read_bytes()))
 sequence=[dict(take='attack_h3_v1',video_frame=i) for i in start]+[dict(take='attack_strike_h3_v3',video_frame=i) for i in strike]+[dict(take='attack_h3_v1',video_frame=i) for i in recovery]
 contact=len(start)+strike.index(114)
 delivery=json.loads((p.SOURCE_DIR/'delivery.json').read_bytes())
 delivery['takes']=['move_h3_v1','hit_h3_v1','defend_h3_v1','cast_h3_v1','death_h3_v1']
 delivery['clip_sequences']={'attack':dict(frames=sequence,timing=dict(frame_msec=30,contact_frame=contact,frame_durations_msec=[90 if i==contact else 30 for i in range(len(sequence))]))}
 delivery['visual_review']=dict(status='pending',notes='Reviewed all992 chronological original frames, enlarged grips/anatomy/alpha and attack joins. Corrected cyan/white trail using an original mid-swing guide and isolated strike; retain only valid anticipation/recovery from first take. All six actions now selected, native candidate review pending; preserve existing eight-pose articulated idle.')
 p.write(p.SOURCE_DIR/'delivery.json',delivery);p.assemble()
 print('Selected attack',len(sequence),'contact',contact)
