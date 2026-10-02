"""Publish the exact solo-reviewed Peatflare Jarrier delivery."""
import json
import produce as p
from publish_fluid_creature_animation import publish

NOTE=('Solo review accepted seven H3 actions and preserved eight articulated idle poses. All13 original takes reviewed chronologically, with enlarged limb/grip/contact/loop/corpse details. All291 new action poses and retained8 idle poses inspected at native128px reference height, normal and actual reflected Godot draws. Reciprocal16-pose run;62-pose physical right-fist punch with jar stow/retrieval;34-pose knee/chest recoil retaining jar;51-pose smooth crouched guard;36-pose empty-left-palm rally and return;43-pose side collapse with original round jar retained against chest and persistent grounded corpse;49-pose single right-overarm throw, empty follow-through and reload. Runtime owns projectile flight: original detached jar55 separated above a verified empty5-row gap, jar56 beyond an empty5-column gap; complete original videos/mattes retained and full character components protected. Support excludes spatially varying4-6 and color-cycling47-73 during unchanged ready/held gesture; remaining source plates pass unchanged uniformity/separation gates with original-guide measured palette bands. Reject v1 hopping gait, invented hit projectile/jar loss, abrupt defense cut, empty-left-hand ranged effects, barrel-morphing v1 death and orbiting loose-jar v2 death. No duplicated, reversed, interpolated, warped or per-frame normalized padding. Windows Godot candidate971 and mirrored971 checks pass. Review used original chronological frames and native clock/phase renders; no continuous browser/manual playback, manual playtest, Linux execution or full repository suite claimed.')

if __name__=='__main__':
    delivery=json.loads((p.SOURCE_DIR/'delivery.json').read_bytes())
    assert delivery['takes']==['move_h3_v2','attack_h3_v1','hit_h3_v2','defend_h3_v2','cast_h3_v1','death_h3_v3','ranged_h3_v2']
    expected={'move':16,'attack':62,'hit':34,'defend':51,'cast':36,'death':43,'ranged':49}
    for take in delivery['takes']:
        row=json.loads((p.SOURCE_DIR/take/'handoff.json').read_bytes())['units'][0]
        assert len(row['frames'])==expected[next(iter(row['clips']))]
        for record in row['provenance'].values():assert p.sha(p.ROOT/record['path'])==record['sha256']
    delivery['visual_review']=dict(status='accepted',notes=NOTE)
    p.write(p.SOURCE_DIR/'delivery.json',delivery);p.assemble()
    print(json.dumps(publish(p.SOURCE_DIR/'handoff.json',list(expected),NOTE,['idle']),indent=2))
