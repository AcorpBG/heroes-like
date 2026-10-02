"""Publish this reviewed unit under the current shared content mutex."""
import json,shutil,hashlib
from pathlib import Path
import produce as p
from creature_animation_lock import exclusive
from publish_fluid_creature_animation import publish
UID='unit_veilmourn_saltwake_eulogists'
B=p.ROOT/'.artifacts/parallel_animation_20261002'/UID
if __name__=='__main__':
 d=json.loads((p.SOURCE_DIR/'delivery.json').read_bytes());assert d['visual_review']['status']=='accepted_selected_clips'
 with exclusive('content'):
  catalog=p.ROOT/'content/unit_animation_manifest.json';idle=p.ROOT/'art/overworld/creature_idle.json'
  before=json.loads(catalog.read_bytes());oldmap=json.loads(idle.read_bytes());B.mkdir(parents=True,exist_ok=True)
  p.write(B/'baseline_manifest.json',before);p.write(B/'baseline_map.json',oldmap)
  row=next(r for r in before['items'] if r['unit_id']==UID)
  shutil.copyfile(p.ROOT/row['pose_sheet'].removeprefix('res://'),B/'baseline_atlas.png')
  shutil.copyfile(p.ROOT/oldmap['units'][UID]['path'].removeprefix('res://'),B/'baseline_map_idle.png')
  result=publish(p.SOURCE_DIR/'handoff.json',list(json.loads((p.SOURCE_DIR/'handoff.json').read_bytes())['units'][0]['clips']),d['visual_review']['notes'],['idle'])
  after=json.loads(catalog.read_bytes());newmap=json.loads(idle.read_bytes())
  assert [r for r in before['items'] if r['unit_id']!=UID]==[r for r in after['items'] if r['unit_id']!=UID]
  assert {k:v for k,v in oldmap['units'].items() if k!=UID}=={k:v for k,v in newmap['units'].items() if k!=UID}
  digest=lambda obj:hashlib.sha256(json.dumps(obj,sort_keys=True,separators=(',',':')).encode()).hexdigest()
  before_others=[r for r in before['items'] if r['unit_id']!=UID];after_others=[r for r in after['items'] if r['unit_id']!=UID]
  before_map={k:v for k,v in oldmap['units'].items() if k!=UID};after_map={k:v for k,v in newmap['units'].items() if k!=UID}
  p.write(p.SOURCE_DIR/'publication.json',dict(result=result,other_rows_preserved=True,other_row_count=len(before_others),before_other_battle_sha256=digest(before_others),after_other_battle_sha256=digest(after_others),before_other_map_sha256=digest(before_map),after_other_map_sha256=digest(after_map),published_own_battle_sha256=digest(next(r for r in after['items'] if r['unit_id']==UID)),published_own_map_sha256=digest(newmap['units'][UID])))
  print(result)
