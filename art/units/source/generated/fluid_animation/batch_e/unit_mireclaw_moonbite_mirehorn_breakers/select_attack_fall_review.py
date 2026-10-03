"""Continuous corrected attack and explicit historical failed fall review."""
import json
import produce as p
if __name__ == '__main__':
 for take,s in [
 ('attack_h3_v3',dict(source_frames=[0,12,16,18,20,22,24,28,32,36,40,44,48,50,52,54,56,58,60,62,64,66,68,70,72,74,76,78,80,82,86,90,94,98,102,108,116,123],frame_msec=50,contact_frame=23,review_note='All124 original RGB/alpha and21 detailed landmarks inspected. Connected low windup, gradual forward head/shoulder lean into original four-paw posture and recovery, intact two horns and original grips, no effect or pose replacement. Actual128 both facings and Godot review pending.')),
 ('death_h3_v1',dict(source_frames=[0,16,24,30,38,44,48,50,52,54,56,58,60,62,64,65,66,67,68,69,70,71,72,73,74,75,76,77,78,82,90,108,123],frame_msec=50,review_note='REJECTED historical review: all124 RGB/alpha show an invented second hooked shaft from the right rein hand52-62, then original left staff curls into a loop64-73 before snapping to the original ground endpoint. Preserve all source and expose failed equipment transition; never assemble this as an accepted fall.')),
 ]:
  out=p.SOURCE_DIR/take;p.write(out/'selection.json',s);p.build(out,json.loads((out/'config.json').read_bytes()));print('SELECTED_REVIEW_POSES',take,len(s['source_frames']),flush=True)
