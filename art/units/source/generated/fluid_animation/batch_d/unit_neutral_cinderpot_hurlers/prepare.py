"""Prepare action-specific original Cinderpot references for local H3."""
import json
import produce as p

UID = 'unit_neutral_cinderpot_hurlers'
BASE = p.ROOT / 'art/animation/source/poses' / UID
PACK = json.loads((BASE / 'packing.json').read_bytes())
IDENTITY = (
    'ONE original human Cinderpot Hurler, a lean adult hooded fantasy skirmisher facing screen right in elevated three-quarter view. '
    'Preserve the dark charcoal hood with thin orange edging, shadowed face and nose, layered brown leather shoulder armor, '
    'wrapped forearms and hands, brown armored boots, dark trousers, orange hanging waist cloth, leather belts and the small round orange clay pots strapped across the chest. '
    'Exactly two arms, two hands and two legs. No sword, staff, shield, helmet or added equipment. '
    'Keep the same lean adult anatomy, silhouette, pot belt, hood, orange trim and hand-painted materials. '
)
PLATE = (
    ' Locked orthographic camera, unchanged body scale and root location. Full body and both hands remain inside the canvas. '
    'Perfectly flat uniform bright MAGENTA background throughout every frame, never another color. '
    'No scenery, ground shadow, camera motion, zoom, extra people, extra limbs, smoke, fire, sparks, beams or magic effects. '
    'Only this character moves; keep boots grounded except the explicitly lifted walking or falling limb.'
)

def ref(index):
    f = dict(PACK['frames'][index])
    f['source'] = (BASE / f['source']).relative_to(p.ROOT).as_posix()
    # Older action originals are taller than the later accepted idle source.
    # Match their standing anatomy with one fixed factor across all old poses.
    if index < 18:
        f['scale'] *= .915
    f['alpha_noise_cutoff'] = 8
    return f

TAKES = {
    'move_h3_v1': ([18], [], 0,
        'Walk in place for two complete reciprocal walking cycles. Alternate near and far legs through heel contact, weight loading, knee passing, lift, forward extension and opposite foot contact. '
        'Each boot clearly lifts and plants, knees and ankles articulate. Let both forearms swing modestly near the belt while the pots remain secured. '
        'The orange cloth sways lightly. Keep the torso in place for engine-driven travel and finish at the starting walking phase.'),
    'attack_h3_v1': ([18,6,7], [[34,1],[65,2]], 0,
        'Perform one empty-handed punch toward an opponent at screen right. Draw the near fist back beside the shoulder, rotate the torso and load the rear boot. '
        'Extend that same fist forward in one forceful straight punch with a clear contact pose, while the other hand guards the chest. '
        'Follow through then bend the striking elbow and recover both hands to the starting belt-level ready posture. Do not throw a pot during this melee action.'),
    'hit_h3_v1': ([18,14], [[38,1]], 0,
        'Act one compact recoil gesture: tip the torso backward, contract both shoulders, bend the elbows and knees, then regain balance and return to ready. '
        'Boots remain planted. Hands briefly spread away from the belt and recover naturally. No visible cause, attacker or projectile. Do not fall.'),
    'defend_h3_v1': ([18,9], [[52,1]], 1,
        'From ready, bend both knees into a stable low defensive brace, bringing both bent forearms up to protect the face and hood. '
        'Plant both boots and hold this guarded crouch for the remainder. Keep both hands, shoulders and legs anatomically coherent. Do not punch.'),
    'cast_h3_v1': ([18,21], [[43,1],[72,1]], 0,
        'Perform a physical readiness signal, not a spell: lift both hands from the belt to chest level, deliberately check and tighten the leather wrist wraps, '
        'briefly hold the prepared fists together in front of the chest, then lower them to the initial belt-level ready pose. '
        'Keep all clay pots strapped in place; no throwing or conjuring. Both boots remain planted.'),
    'death_h3_v1': ([18,15,16,17], [[32,1],[72,2]], 3,
        'One continuous collapse. The knees buckle and the shoulders sag; lower onto one knee, put a hand down, then let the hip and torso fall onto the side. '
        'The head settles at screen left and both legs extend toward screen right. Keep the small pots attached to the belt. '
        'End as a fully grounded motionless body with both hands and boots resting naturally. No recovery, floating body or disappearing limbs.'),
    'ranged_h3_v1': ([18,10,11,12,13], [[23,1],[50,2],[69,3],[101,4]], 0,
        'Perform one deliberate overarm clay-pot throw. Take ONE small orange clay pot from the chest belt with the near hand, '
        'raise that same pot behind the shoulder while the far hand points toward screen right, then swing the throwing arm forward and release once toward screen right. '
        'The pot moves away after release; the hand opens naturally and follows through. Recover both hands to the original ready pose at the belt. '
        'The other pots remain firmly strapped in their original places. No explosion, extra projectile, smoke or flash.'),
}

if __name__ == '__main__':
    for ordinal,(name,(indices,guides,last,action)) in enumerate(TAKES.items()):
        out = p.SOURCE_DIR/name
        out.mkdir(exist_ok=False)
        config = dict(unit_id=UID,clip=name.split('_')[0],canvas=[960,640],anchor=[430,560],scale=.5,
            key_rgb=[255,0,255],protected_foreground_chroma=10,seed=2026092910+ordinal,
            references=[ref(i) for i in indices],guides=guides,last=last,prompt=IDENTITY+action+PLATE,
            tiled_decode=dict(tile_size=512,overlap=64,temporal_size=16,temporal_overlap=4))
        p.write(out/'config.json',config)
        p.prepare(out,config)
    p.write(p.SOURCE_DIR/'delivery.json',dict(unit_id=UID,takes=list(TAKES),preserved_accepted_clips=['idle'],
        visual_review=dict(status='pending',notes='Review all original frames for hood/pot continuity, anatomy, gait, throw release, grounding and native scale before publishing.')))
