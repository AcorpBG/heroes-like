"""Complete the reviewed source selection, pending native-scale acceptance."""
import json
import produce as p

out=p.SOURCE_DIR/'death_h3_v2'
indices=list(range(4,24))+[28,34,40,46,50,53]+list(range(54,85))
p.write(out/'selection.json',dict(source_frames=indices,frame_msec=32,review_note='Full124-frame chronology and enlarged4/9/14/22/56/62/66/69/73/84 reviewed after measured pure-blue extraction. Knees buckle, weight lowers to both knees, torso falls sideways and settles with both blades on the ground. Shorten kneeling pause using original samples; preserve every fall/settling frame. Final84 is grounded and motionless; native review pending.'))
p.build(out,json.loads((out/'config.json').read_bytes()))
d=json.loads((p.SOURCE_DIR/'delivery.json').read_bytes())
d['takes']=['move_h3_v2','attack_h3_v1','hit_h3_v1','defend_h3_v2','cast_h3_v2','death_h3_v2']
d['visual_review']=dict(status='pending',notes='267 original H3 frames selected across six dedicated actions. Full chronology/enlarged anatomy, hands, both blades, loop seam and alpha reviewed; native battle-scale check still required. Preserve original eight-frame articulated idle/map. No continuous playback or manual playtest claim.')
p.write(p.SOURCE_DIR/'delivery.json',d)
p.assemble()
print({k:len(v['indices']) for k,v in json.loads((p.SOURCE_DIR/'handoff.json').read_bytes())['units'][0]['clips'].items()})
