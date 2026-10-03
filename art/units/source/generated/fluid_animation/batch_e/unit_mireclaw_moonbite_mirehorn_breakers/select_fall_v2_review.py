"""Chronological connected fall poses; selected native review still required."""
import json
import produce as p
if __name__=='__main__':
 out=p.SOURCE_DIR/'death_h3_v2'
 p.write(out/'selection.json',dict(source_frames=[0,12,16,20,22,24,26,28,30,32,34,36,38,40,42,44,46,48,50,52,54,56,58,60,62,64,68,72,78,86,94,108,123],frame_msec=50,review_note='All124 original RGB/alpha and21 enlarged RGB/alpha grip/paw/horn landmarks inspected; connected two-body lowering and original prone staff endpoint. Source ready/kneel/sidefall/corpse retained at original registration. Actual128both facings and Godot review pending.'))
 p.build(out,json.loads((out/'config.json').read_bytes()));print('SELECTED_FALL_V2_REVIEW',33,flush=True)
