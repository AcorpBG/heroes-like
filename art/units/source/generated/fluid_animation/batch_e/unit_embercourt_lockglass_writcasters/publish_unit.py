"""Publish only this UID while holding the shared current-catalog lock."""
import json,sys
import produce as p
from creature_animation_lock import exclusive
from publish_fluid_creature_animation import publish
UID=p.SOURCE_DIR.name
def read(path):return json.loads(path.read_bytes())
if __name__=='__main__':
 with exclusive('content'):
  manifest=p.ROOT/'content/unit_animation_manifest.json';maps=p.ROOT/'art/overworld/creature_idle.json'
  before=[r for r in read(manifest)['items'] if r['unit_id']!=UID];before_map={k:v for k,v in read(maps)['units'].items() if k!=UID}
  delivery=read(p.SOURCE_DIR/'delivery.json');assert delivery['visual_review']['status']=='accepted_selected_clips'
  publish(p.SOURCE_DIR/'handoff.json',['move','attack','ranged','hit','defend','cast','death'],delivery['visual_review']['notes'],['idle'])
  assert before==[r for r in read(manifest)['items'] if r['unit_id']!=UID]
  assert before_map=={k:v for k,v in read(maps)['units'].items() if k!=UID}
  p.write(p.SOURCE_DIR/'publication.json',dict(other_battle_rows_preserved=len(before),other_map_rows_preserved=len(before_map),lock='content',own_uid=UID))
  print('Published only',UID,'; preserved',len(before),'other current battle rows and',len(before_map),'other current map rows',flush=True)
