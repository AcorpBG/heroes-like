"""Publish only personally accepted Whistler clips against current catalogs."""
import json,shutil
from pathlib import Path
import produce as p
from creature_animation_lock import exclusive
from publish_fluid_creature_animation import publish
from verify_delivery import verify
UID='unit_thornwake_pollenhook_whistlers'
if __name__=='__main__':
 review=p.ROOT/'.artifacts/parallel_animation_20261002'/UID
 delivery=json.loads((p.SOURCE_DIR/'delivery.json').read_bytes())
 assert delivery['visual_review']['status']=='accepted_selected_unit','Personal native/reflected/action review must finish before publication'
 with exclusive('content'):
  before=json.loads((p.ROOT/'content/unit_animation_manifest.json').read_bytes());map_before=json.loads((p.ROOT/'art/overworld/creature_idle.json').read_bytes())
  p.write(review/'baseline_manifest.json',before);p.write(review/'baseline_map.json',map_before)
  result=publish(p.SOURCE_DIR/'handoff.json',['move','attack','ranged','hit','defend','cast','death'],delivery['visual_review']['notes'],preserved=['idle'])
  after=json.loads((p.ROOT/'content/unit_animation_manifest.json').read_bytes());map_after=json.loads((p.ROOT/'art/overworld/creature_idle.json').read_bytes())
  assert [x for x in before['items'] if x['unit_id']!=UID]==[x for x in after['items'] if x['unit_id']!=UID]
  assert {k:v for k,v in map_before['units'].items() if k!=UID}=={k:v for k,v in map_after['units'].items() if k!=UID}
  verify(review)
  print('PUBLISHED_SELECTED_WHISTLER',result,flush=True)
