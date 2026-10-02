"""Last bounded staff-transition correction from original physical poses."""
import json
import prepare as g
import produce as p
out=p.SOURCE_DIR/'attack_h3_v3';out.mkdir(exist_ok=True)
action=('Continuous painted pose study. The mourner first takes the lower shaft with the free far hand while the near hand keeps its original grip. Both hands rotate the single rigid bronze instrument from the raised diagonal position slowly down to the supplied horizontal position. Its three pale blue glass cylinders keep exactly the same dim painted brightness throughout. Hold the horizontal position briefly. Then both hands rotate the same rigid instrument upright, the far hand releases and lowers, and the mourner settles into the original standing position. All movement comes from shoulders, elbows, wrists, hips and knees; the bronze shaft keeps the same length and shape throughout. This is quiet object positioning in a studio, with only the body, cloth and held original instrument visible. ')
c=dict(unit_id=g.UID,clip='attack',canvas=[960,640],anchor=[480,576],scale=.5,key_rgb=[255,0,255],seed=2026108209,references=[g.reference(i) for i in [0,6,7,8]],guides=[[22,1],[48,2],[64,2],[92,3]],last=0,prompt=(g.IDENTITY+action+g.PLATE).strip(),tiled_decode=dict(tile_size=512,overlap=64,temporal_size=16,temporal_overlap=4))
p.write(out/'config.json',c);p.prepare(out,c);p.verify(out,c)
r=json.loads((p.SOURCE_DIR/'rejected_takes.json').read_bytes());r['takes'].append(dict(take='attack_h3_v2',status='rejected',defect='Original RGB32-41 introduces a bright cyan staff-overlapping ring and beam. Semantic extraction cannot make that a faithful physical strike. Clean contact42 onward is retained as original source only.',correction='attack_h3_v3 replaces combat phrasing with continuous studio object positioning and four original contact guides22/48/64/92. One final correction before reassessment.'))
p.write(p.SOURCE_DIR/'rejected_takes.json',r)
