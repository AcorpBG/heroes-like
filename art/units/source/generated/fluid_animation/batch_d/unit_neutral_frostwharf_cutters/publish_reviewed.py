"""Publish six personally reviewed Frostwharf actions; retain accepted idle."""
import sys,json
import produce as p
sys.path.insert(0,str(p.ROOT/'tools'))
from publish_fluid_creature_animation import publish

NOTE=('Solo reviewed all124 chronological original phases in each of eight takes, enlarged hands/hooks/legs, every selected native128px pose and actual mirrored rendering, plus battle phase-clock captures. '
      'Accepted reciprocal two-leg walk, shortened physical two-hook strike with two-arm recovery, clean recoil, crossed-blades guard, physical blade salute and continuous grounded collapse with persistent corpse. '
      'Rejected initial attack cyan arc and incoming projectile in initial hit; corrected complete attack/hit videos supply delivered actions. '
      'Guarded crop removes independently reviewed alpha<64 rectangular background residue beside the head, preserving opaque character pixels and all original footage. '
      'Attack timing42ms matches source24fps and every pose appears under the actual shell clock;317 candidate and317 reflected focused checks pass. '
      'Preserve eight accepted articulated idle poses and all overworld pixels/timing. Review used chronological stills and native clock-driven captures; no claim of continuous manual movie playback. No broad suite.')

if __name__=='__main__':
 d=json.loads((p.SOURCE_DIR/'delivery.json').read_bytes());d['visual_review']={'status':'accepted','notes':NOTE}
 p.write(p.SOURCE_DIR/'delivery.json',d);p.assemble()
 result=publish(p.SOURCE_DIR/'handoff.json',['move','attack','hit','defend','cast','death'],NOTE,['idle'])
 print(json.dumps(result))
