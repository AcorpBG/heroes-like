"""Publish only reviewed Ironback actions against current concurrent catalogs."""
import copy,json,sys
from pathlib import Path
import produce as p
from creature_animation_lock import exclusive
from publish_fluid_creature_animation import publish
import verify_delivery

UID='unit_neutral_quenchbell_ironbacks'
OUT=p.ROOT/'.artifacts/parallel_animation_20261002'/UID

def refresh_other_rows():
    for name,path,key in [('manifest',p.ROOT/'content/unit_animation_manifest.json','items'),('map',p.ROOT/'art/overworld/creature_idle.json','units')]:
        current=json.loads(path.read_bytes())
        original=json.loads((OUT/f'initial_baseline_{name}.json').read_bytes())
        if key=='items':
            own=next(r for r in original[key] if r['unit_id']==UID)
            current[key]=[copy.deepcopy(own) if r['unit_id']==UID else r for r in current[key]]
        else:current[key][UID]=original[key][UID]
        p.write(OUT/f'baseline_{name}.json',current)

if __name__=='__main__':
    delivery=json.loads((p.SOURCE_DIR/'delivery.json').read_bytes())
    assert delivery['visual_review']['status']=='accepted_selected_clips','Native review must precede acceptance'
    with exclusive('content'):
        refresh_other_rows()
        result=publish(p.SOURCE_DIR/'handoff.json',['move','attack','hit','defend','cast','death'],delivery['visual_review']['notes'],['idle'])
        verify_delivery.verify(OUT)
        p.write(OUT/'publication.json',result)
        print(json.dumps(result))
