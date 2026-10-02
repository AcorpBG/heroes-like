"""Publish the six individually reviewed original H3 actions, retaining idle."""
import json
import produce as p
from publish_fluid_creature_animation import publish

NOTE = ('Solo review: all 124 chronological RGB frames of eight original H3 takes inspected; '
        'attack v1 rejected for a baked swing trail and defend v1 for lantern simplification. '
        'Selected move33, attack65, hit25, defend16, physical standard-rally cast36 and death22: '
        '197 new poses. Two arms, original right-hand lantern standard, left-hand axe and '
        'shield on the same left forearm retained. Reciprocal knee/heel/toe gait, planted rally, '
        'axe windup/contact/recovery and grounded head-left corpse reviewed. Attack contact '
        'source44/index26; rally source36/index14. Attack33ms, other actions42ms; only matching '
        'stationary holds shortened. Recorded disconnected pale background flecks excluded '
        'from defend/death; unmodified originals and matte extraction recipes retained as provenance. '
        'Every candidate and mirrored native phase inspected at actual128px reference height, '
        'plus eight actual battle-clock captures covering axe contact and recovery. Candidate '
        'and mirrored focused fixtures each272 checks with zero failures and all65 attack '
        'poses observed. Eight existing articulated idle poses reviewed and preserved. '
        'No continuous browser movie review, manual gameplay, Linux run or full suite claimed.')

if __name__ == '__main__':
    d = json.loads((p.SOURCE_DIR/'delivery.json').read_bytes())
    d['visual_review'] = {'status':'accepted', 'notes':NOTE}
    p.write(p.SOURCE_DIR/'delivery.json', d)
    p.assemble()
    publish(p.SOURCE_DIR/'handoff.json', ['move','attack','hit','defend','cast','death'], NOTE, ['idle'])
    print('Published Beaconline Writguard:197 new poses, eight retained idle phases.')
