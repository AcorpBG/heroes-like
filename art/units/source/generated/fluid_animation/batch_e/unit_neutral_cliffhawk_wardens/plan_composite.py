"""Plan chronological original body/companion pairs and verify natural separation."""
from pathlib import Path
import json,numpy as np
from PIL import Image
R=next(p for p in Path(__file__).resolve().parents if (p/'project.godot').exists());S=Path(__file__).parent;T=S/'companion_h3_v1';B=R/'art/units/source/generated/fluid_animation/batch_c/unit_neutral_cliffhawk_wardens/death_h3_v1'
body=json.loads((B/'selection.json').read_bytes())['source_frames'];late=[i for i in body if i>=36];pairs={}
for i in late:
 j=round((i-36)*122/87)
 if j==48:j=49
 assert j not in [1,48,98,123]
 pairs[j]=i
for j in [i if i!=48 else 49 for i in range(0,97,2)]+[100,107,114,122]:
 if j not in pairs:pairs[j]=min(late,key=lambda i:abs(i-(36+87*j/122)))
records=[]
for j,i in sorted(pairs.items()):
 a=np.array(Image.open(S/f'original_body/rgba_{i:03}.png').convert('RGBA'));b=np.array(Image.open(T/f'matte_plate_v3/rgba_{j:03}.png').convert('RGBA'));overlap=int(np.sum((a[:,:,3]>=8)&(b[:,:,3]>=8)));records.append(dict(body_frame=i,companion_frame=j,opaque_overlap_pixels=overlap))
print('PROPOSED_COMPOSITE',len([i for i in body if i<36])+len(records),'poses','overlaps',[(r['body_frame'],r['companion_frame'],r['opaque_overlap_pixels']) for r in records if r['opaque_overlap_pixels']],flush=True)
(S/'composite_plan.json').write_text(json.dumps(dict(original_early_frames=[i for i in body if i<36],pairs=records,provisional_frame_msec=35,status='pending temporal/native visual assessment',body_frames_preserved=body),indent=2)+'\n')
