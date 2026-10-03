"""Original chronological motion selections; no synthesized or adjusted poses."""
import json
import produce as p

SELECTIONS = {
 'attack_h3_v2': dict(source_frames=[0,3,6,9,12,15,18,22,30,38,44,46,47,48,49,50,51,54,58,62,66,68,70,72,75,80,86,90,93,96,99,102,108,116,123],frame_msec=50,contact_frame=17,review_note='REJECTED and preserved after full124 RGB/alpha, enlarged anatomy/grips and all35 actual128px both-facing poses. Repeated guides freeze windup through47 then replace the full group at48. This historical selection exposes the defective transition and must never be assembled or published as an accepted action.'),
 'hit_h3_v1': dict(source_frames=[0,16,20,24,28,32,36,40,42,44,46,48,50,54,58,62,66,70,74,78,82,86,90,94,100,108,116,123],frame_msec=35,review_note='Full124 original RGB and alpha inspected. Original raised-front-paw recoil supported by hind paws, intact two horns and faceplate, two-handed handler, recovery to original ready. No flash or new gear. Full enlarged/native acceptance remains pending.'),
}
if __name__ == '__main__':
 for take,selection in SELECTIONS.items():
  out=p.SOURCE_DIR/take
  assert (out/'original.json').exists() and (out/'matte.json').exists()
  p.write(out/'selection.json',selection)
  p.build(out,json.loads((out/'config.json').read_bytes()))
  print('SELECTED_ORIGINAL_POSES',take,len(selection['source_frames']),flush=True)
