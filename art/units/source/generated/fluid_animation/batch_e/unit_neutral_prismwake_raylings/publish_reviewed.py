"""Read-current locked publication of this unit only, with idle pixel proof."""
import copy,json,shutil
from PIL import Image
import produce as p
from creature_animation_lock import exclusive
from publish_fluid_creature_animation import publish
from integrate_fluid_creature_animation import resolve
UID='unit_neutral_prismwake_raylings'
def run():
 with exclusive('content'):
  baseline=p.ROOT/'.artifacts/parallel_animation_20261002'/UID/'publication_baseline';baseline.mkdir(parents=True,exist_ok=True)
  old=json.loads((p.ROOT/'content/unit_animation_manifest.json').read_bytes());maps=json.loads((p.ROOT/'art/overworld/creature_idle.json').read_bytes());row=next(r for r in old['items'] if r['unit_id']==UID)
  if not (baseline/'baseline_manifest.json').exists():
   p.write(baseline/'baseline_manifest.json',old);p.write(baseline/'baseline_map.json',maps)
   shutil.copyfile(resolve(row['pose_sheet']),baseline/'baseline_atlas.png');shutil.copyfile(resolve(maps['units'][UID]['path']),baseline/'baseline_map_idle.png')
  packet=json.loads((p.SOURCE_DIR/'handoff.json').read_bytes())['units'][0]
  assert packet['visual_review']['status']=='accepted_selected_unit'
  published=publish(p.SOURCE_DIR/'handoff.json',list(packet['clips']),packet['visual_review']['notes'],['idle'])
  current=json.loads((p.ROOT/'content/unit_animation_manifest.json').read_bytes());newmap=json.loads((p.ROOT/'art/overworld/creature_idle.json').read_bytes())
  assert [r for r in old['items'] if r['unit_id']!=UID]==[r for r in current['items'] if r['unit_id']!=UID]
  assert {k:v for k,v in maps['units'].items() if k!=UID}=={k:v for k,v in newmap['units'].items() if k!=UID}
  a=Image.open(baseline/'baseline_map_idle.png').convert('RGBA');b=Image.open(resolve(newmap['units'][UID]['path'])).convert('RGBA')
  assert a.size==b.size and a.tobytes()==b.tobytes();assert maps['units'][UID]['frame_msec']==newmap['units'][UID]['frame_msec']
  print(json.dumps(published));print(f'Other {len(old["items"])-1} current battle/map rows and exact preserved idle pixels/timing verified')
if __name__=='__main__':run()
