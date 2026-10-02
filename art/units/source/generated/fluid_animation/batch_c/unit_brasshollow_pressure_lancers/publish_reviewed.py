"""Publish the six personally reviewed mechanical actions; retain accepted idle."""
import sys,json
import produce as p
sys.path.insert(0,str(p.ROOT/'tools'))
from publish_fluid_creature_animation import publish

NOTE=('Solo reviewed all124 chronological original phases per take, enlarged limb/weapon/support transitions, full native128px and actual reflected rendering of every selected pose, plus battle phase-clock captures. '
      'Exactly three mechanical legs, one cold integral telescopic lance, original pressure gauge and boiler retained. Complete tripod cycle, readable single spear stroke and recovery, recoil, intact-foot guard, physical readiness signal and grounded terminal corpse accepted. '
      'Recovered original clipped guard feet in source guides; rejected invented attack flash, incoming hit drum/explosion and mismatched first tripod size. '
      '328 focused candidate checks and328 reflected checks pass. Preserve eight accepted idle poses and map pixels/timing. Review used chronological stills and native clock-driven captures; no claim of continuous manual video playback. No broad repository suite.')

if __name__=='__main__':
 d=json.loads((p.SOURCE_DIR/'delivery.json').read_bytes())
 d['visual_review']={'status':'accepted','notes':NOTE}
 p.write(p.SOURCE_DIR/'delivery.json',d);p.assemble()
 print(json.dumps(publish(p.SOURCE_DIR/'handoff.json',['move','attack','hit','defend','cast','death'],NOTE,['idle'])))
