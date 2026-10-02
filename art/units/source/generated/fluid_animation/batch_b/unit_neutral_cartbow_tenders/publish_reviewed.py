"""Publish seven personally reviewed Cartbow actions; retain accepted idle."""
import sys,json
import produce as p
sys.path.insert(0,str(p.ROOT/'tools'))
from publish_fluid_creature_animation import publish

NOTE=('Solo reviewed all124 chronological original phases per take, enlarged hands/legs/loaded bow and two-wheel cart, every selected native128px pose and actual mirrored rendering, plus battle phase-clock captures. '
      'Accepted complete middle reciprocal walk, physical cart shove/recovery, dedicated crouching guard, empty-palm support gesture, shot/recoil/crank-reload cycle and grounded two-leg corpse. '
      'Clean recoil0-34 from corrected take matches original clean recovery36-123 at the shared backward-lean pose; personally reviewed seam without blending/warping. '
      'Rejected first one-legged walk, unwanted firing outside accepted middle walking cycle, incoming hit effects, late extra recoil bolt and brief collapse flash. Guarded matte crop removes only reviewed alpha<64 rectangular background pixels beside cap. '
      'Runtime-owned bolt flight separated only across empty gaps after release; held reload bolt remains.940 focused candidate and940 actual reflected checks pass. '
      'Preserve eight accepted idle poses and all overworld pixels/timing. Review used chronological stills and native clock-driven captures; no claim of continuous manual movie playback. No broad suite.')

if __name__=='__main__':
 d=json.loads((p.SOURCE_DIR/'delivery.json').read_bytes());d['visual_review']={'status':'accepted','notes':NOTE}
 p.write(p.SOURCE_DIR/'delivery.json',d);p.assemble()
 result=publish(p.SOURCE_DIR/'handoff.json',['move','attack','hit','defend','cast','death','ranged'],NOTE,['idle'])
 print(json.dumps(result))
