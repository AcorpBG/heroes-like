"""Publish individually reviewed H3 actions, preserving articulated idle."""
import json
import produce as p
from publish_fluid_creature_animation import publish

NOTE=('Solo review: all744 chronological frames from six original H3 videos inspected. '
      'Selected move17, attack55, hit32, defend15, physical rally cast33 and death57:209 new poses. '
      'Two original arms and legs, right-hand short boarding hook and left-forearm keel shield retained. '
      'The hook turns briefly edge-on during wrist rotation at source34-35, then returns to its crescent profile. '
      'Reciprocal gait, distinct windup/contact/recovery, knee/shield brace and raised-hook rally reviewed. '
      'Death retains the whole descent and side roll: the attached left forearm supports the shield, '
      'then relaxes to a grounded head-left corpse; no collapse interval removed. '
      'Matching extended attack and raised rally stationary holds shortened; original timestamps preserved. '
      'Attack contact source42/index30; rally source37/index13. Runtime move50ms, attack/hit/death33ms, '
      'defend/rally42ms. Every native and mirrored phase inspected at actual128px reference height, '
      'with actual battle-clock captures covering strike contact and recovery. Candidate and mirrored '
      'focused checks pass, including all55 attack poses observed, Normal/Fast and reduced-motion paths. '
      'Eight existing articulated idle phases retained. No continuous browser movie review, manual '
      'gameplay, Linux run or full repository suite claimed.')

if __name__=='__main__':
    d=json.loads((p.SOURCE_DIR/'delivery.json').read_bytes())
    d['visual_review']={'status':'accepted','notes':NOTE}
    p.write(p.SOURCE_DIR/'delivery.json',d)
    p.assemble()
    publish(p.SOURCE_DIR/'handoff.json',['move','attack','hit','defend','cast','death'],NOTE,['idle'])
    print('Published Gloamkeel Bulwarks:209 new poses, eight preserved idle phases.')
