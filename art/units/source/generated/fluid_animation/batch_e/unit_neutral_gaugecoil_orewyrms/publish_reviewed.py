"""Publish this UID from current catalogs while holding the content lock."""
import json,sys
from pathlib import Path
ROOT=next(p for p in Path(__file__).resolve().parents if (p/'project.godot').exists())
OUT=Path(__file__).resolve().parent
UID='unit_neutral_gaugecoil_orewyrms'
sys.path.insert(0,str(ROOT/'tools'))
from creature_animation_lock import exclusive
from publish_fluid_creature_animation import publish
def read(p):return json.loads(p.read_bytes())
def write(p,v):p.write_text(json.dumps(v,indent=2)+'\n',encoding='utf-8')
if __name__=='__main__':
 delivery=read(OUT/'delivery.json');assert delivery['visual_review']['status']=='accepted_selected_unit'
 with exclusive('content'):
  before=read(ROOT/'content/unit_animation_manifest.json');maps=read(ROOT/'art/overworld/creature_idle.json')
  base=ROOT/'.artifacts/parallel_animation_20261002'/UID
  write(base/'publication_manifest.json',before);write(base/'publication_map.json',maps)
  print(publish(OUT/'handoff.json',list(read(OUT/'handoff.json')['units'][0]['clips']),delivery['visual_review']['notes'],['idle']))
  after=read(ROOT/'content/unit_animation_manifest.json');newmap=read(ROOT/'art/overworld/creature_idle.json')
  assert [r for r in before['items'] if r['unit_id']!=UID]==[r for r in after['items'] if r['unit_id']!=UID]
  assert {k:v for k,v in maps['units'].items() if k!=UID}=={k:v for k,v in newmap['units'].items() if k!=UID}
  write(base/'published_manifest.json',after);write(base/'published_map.json',newmap)
  print('Current other-unit rows preserved exactly.',flush=True)
