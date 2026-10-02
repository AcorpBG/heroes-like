"""Keep observed valid actions and repair only the missing strike interval."""
import json
import produce as p
from select_reviewed import select

def select_attack_cast():
    windup = [0,8,10]+list(range(12,21))+[24,28,30,31,32]
    release = [27,28,29,30]
    recovery = list(range(36,45))+[46,54,66]+list(range(68,83))+[90,104,123]
    select('attack_h3_v2',windup+recovery,
        'All124 phases and enlarged two-arm grips reviewed. Original corrected windup and recovery are retained. Exclude34/35: hammer head disappears. Use the first original take27-30 for the physically matching overhead-to-forward release; no pixel reconstruction. Native seam and complete shell-clock review pending.')
    select('attack_h3_v1',release,
        'Only original27-30 is selected: intact original rectangular hammer head rotates from overhead behind to forward above the hands. The original ghosted initial lift is excluded. Join to corrected overhead32 and corrected mid-downstroke36 without interpolation, reversal or per-pose registration changes. Native seam review pending.')
    select('cast_h3_v2',[0,8,16,18]+list(range(20,27))+[32,44,56,68]+list(range(69,79))+[84,96,123],
        'All124 chronological originals and enlarged wrists, shaft/head and body reviewed. Two original hands raise the same maul diagonally beside shoulder20-26, distinct held physical rally salute32-68, controlled lowering69-78, original ready. Head remains original size and fully in canvas. No magic, extra limbs or equipment; fixed source-family scale, no normalization. Native review pending.',hold={56:126})
    d=json.loads((p.SOURCE_DIR/'delivery.json').read_bytes())
    d['takes']=['move_h3_v1','hit_h3_v1','defend_h3_v1','cast_h3_v2']
    sequence=[dict(take='attack_h3_v2',video_frame=i) for i in windup]
    sequence += [dict(take='attack_h3_v1',video_frame=i) for i in release]
    sequence += [dict(take='attack_h3_v2',video_frame=i) for i in recovery]
    d['clip_sequences']={'attack':dict(frames=sequence,timing=dict(frame_msec=42,contact_frame=len(windup)+len(release)+2))}
    p.write(p.SOURCE_DIR/'delivery.json',d)

def select_death():
    select('death_h3_v3',[0,8,16,18]+list(range(20,46))+[48,56,62]+list(range(63,96))+[104,123],
        'All124 originals and enlarged knee descent, side roll, both arms/legs, original hammer and final grounding reviewed. Endpoint-only correction removes hard intermediate pose plateaus: knees gradually lower20-34, torso sags35-45, loses support63-69, side roll70-82, hands lower original maul83-92, grounded persistent corpse93-123. Preserve every active descent/roll/weapon-settling frame; shorten static holds only. Fixed original anatomical scale/root, no shifting, shrink, interpolation, reversed motion or padding. Native review pending.')
    d=json.loads((p.SOURCE_DIR/'delivery.json').read_bytes())
    if 'death_h3_v3' not in d['takes']:d['takes'].append('death_h3_v3')
    p.write(p.SOURCE_DIR/'delivery.json',d)
    p.assemble()

if __name__=='__main__':
    select_attack_cast()
    select_death()
