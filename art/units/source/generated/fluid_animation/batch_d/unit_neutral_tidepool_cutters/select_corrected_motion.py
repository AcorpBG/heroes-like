"""Select original walking cycle and continuous guard transition after review."""
import json
import produce as p

for name,indices,note in [
 ('move_h3_v2',list(range(54,89)),'All124 chronological frames reviewed. Original54..88 supplies one reciprocal cycle with both boots alternately carrying weight, continuous counter-swing and matching passing-phase seam. Enlarged54/58/62/66/70/74/78/82/86/88/89/90 inspected before and after measured pure-blue extraction. Both hooked blades remain held; native review pending.'),
 ('defend_h3_v2',list(range(11,36)),'All124 chronological frames reviewed. Original11..35 raises both hooked blades and lowers the hips into a held crossed guard; two hands/grips stay distinct. Enlarged11/15/18/21/23/25/30/35 inspected before and after measured pure-blue extraction. End hold sampled once; native review pending.'),
 ('cast_h3_v2',list(range(12,39))+[44,52,60,68,76]+list(range(79,103)),'All124 chronological frames and enlarged12/20/26/30/38/80/86/92/98/102 reviewed. Upright two-blade readiness salute, brief held cross and clean return with two separate grips. No magic or invented weapon. Long held phase shortened using original samples; native review pending.')]:
 out=p.SOURCE_DIR/name
 p.write(out/'selection.json',dict(source_frames=indices,frame_msec=32,review_note=note))
 p.build(out,json.loads((out/'config.json').read_bytes()))
