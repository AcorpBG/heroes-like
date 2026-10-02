"""Publish self-reviewed Seedshield actions; preserve articulated map/battle idle."""
import json
import produce as p
from publish_fluid_creature_animation import publish

NOTE=('Solo review of all1116 chronological original frames from nine H3 takes, '
      'including raw rejected support/collapse backdrop transitions. Selected '
      'move50, attack48, hit34, defend29, physical support37 and death48:246 new poses. '
      'Original two arms/two legs, brown antler helm, green leaf armor, full right-hand '
      'seed-spear with amber curved blade/aperture and left-forearm seedglass shield '
      'retained. Reciprocal walking cycle has matching extended contact endpoints. '
      'Attack blade turns edge-on during rapid original wrist rotation38-41 and '
      'presents its original profile/aperture at contact44/index29, followed by recovery. '
      'Dedicated knee/shield brace holds its terminal pose. Corrected recoil recovers '
      'without v1 detached flakes/slash ribbons. Corrected physical salute raises '
      'the held spear at38/index12 and lowers it without v1 gold star flares. '
      'Blue correction plates avoid v1 green/magenta backdrop switching. The recoil '
      'guide omits only a verified disconnected six-pixel backdrop dash with original '
      'rectangles; all creature pixels above cutoff8 remain exact. Walking extraction '
      'uses clean original ready colors to remove legacy magenta contamination. '
      'Death retains the entire descent, kneeling loss of support, side roll and '
      'settling into a grounded head-left corpse with horizontal original spear and '
      'shield resting on body/ground. Matching stationary attack and salute holds '
      'shortened; no interpolation, reversed footage or per-frame normalization. '
      'Move/attack/hit/death33ms, defend/support42ms. Every selected native and mirrored '
      'phase reviewed at actual128px reference height; actual battle-clock captures '
      'cover windup, contact and recovery. Candidate830 and mirrored830 focused checks '
      'pass, including every48 attack pose observed, Normal/Fast and reduced motion. '
      'Eight existing articulated idle phases retained. No continuous browser movie '
      'review, manual playtest, Linux run or full suite claimed.')

if __name__=='__main__':
    d=json.loads((p.SOURCE_DIR/'delivery.json').read_bytes())
    d['visual_review']=dict(status='accepted',notes=NOTE)
    p.write(p.SOURCE_DIR/'delivery.json',d);p.assemble()
    publish(p.SOURCE_DIR/'handoff.json',['move','attack','hit','defend','cast','death'],NOTE,['idle'])
    print('Published Seedshield Wardens:246 new action poses; eight preserved idle phases.')
