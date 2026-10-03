"""Select connected guard transition for actual game-scale visual review."""
import json
import produce as p
if __name__=='__main__':
 out=p.SOURCE_DIR/'defend_h3_v2'
 p.write(out/'selection.json',dict(source_frames=[0,8,16,20,24,28,32,36,40,42,44,46,48,50,52,54,56,58,60,62,70,86,108,123],frame_msec=50,review_note='Complete original RGB124 and transparent124 reviewed; continuous lowering into original held brace. Local original soft-boundary color recovery retains exact pinned NN alpha and all original geometry; measured original palette protects foreground. Sixteen enlarged grip/paw/horn landmarks viewed. Actual128both facings and Godot fixture pending.'))
 p.build(out,json.loads((out/'config.json').read_bytes()))
 print('GUARD_SELECTED24_GAME_SCALE_REVIEW_PENDING',flush=True)
