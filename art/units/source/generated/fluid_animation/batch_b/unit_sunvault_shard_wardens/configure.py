"""Original Shard Warden references, fixed anchors and separate H3 action briefs."""
import json
from pathlib import Path

SOURCE = Path(__file__).resolve().parent
UNIT = 'unit_sunvault_shard_wardens'
IDENTITY = (
    'Locked orthographic camera, original richly painted fantasy strategy sprite on perfectly uniform vivid GREEN RGB(0,255,0). '
    'Identical flat background everywhere including limb gaps, no scenery, shadows, text, particles or colored lighting. '
    'One human male guard with short swept brown hair and exposed face, white plate armor edged in gold, blue scarf and blue split tabard, '
    'small violet triangular gems on chest and knee plates, brown gloves and armored boots. Exactly two arms and two legs. '
    'His RIGHT hand, on IMAGE LEFT in the ready pose, grips one SHORT brown-shafted mace with a solid white/gold cylindrical hammer head and blue gem ends. '
    'His LEFT forearm, on IMAGE RIGHT, supports one tall pointed kite shield with white panels, gold rim and blue/violet faceted crystal panels. '
    'The shield remains attached to that same forearm; the mace remains in the same right-hand grip throughout. No sword, staff, new weapon, duplicate shield or helmet. '
    'Preserve shield height/width, mace shaft length and hammer head, face, armor and all materials without morphing or hue changes. '
    'Stable three-quarter RIGHT-facing view, full body and equipment visible, unchanged anatomical scale, fixed camera with no zoom or rotation. '
)
ACTIONS = {
    'move': ([2], 0, [],
        'Walk in place through two complete measured marching cycles. Alternate right and left leg forward contacts, knee bend, foot lift, passing and planting. '
        'The weapon-side leg on image left and shield-side leg on image right take turns stepping; keep their identities and two boots. '
        'Keep the torso centered for game-engine travel. Carry the shield steadily while the mace arm swings modestly; scarf and tabard follow the gait. '
        'Return smoothly to the original contact phase. No hopping, sliding, crossed legs, whole-body spinning or attacking.'),
    'defend': ([14, 9], 1, [],
        'Lower into a guarded stance continuously: knees bend, shield arm brings the large kite shield forward to protect the chest, '
        'mace arm lowers beside the hip without releasing its grip. Brace both planted feet and hold the final shield guard. '
        'No attack, shield throw, kneeling collapse or return to upright at the end.'),
    'hit': ([14, 10], 0, [[40, 1]],
        'One impact from image right pushes the upper body back. Recoil at the shoulders, bend the knees, draw the shield inward and tighten the mace grip. '
        'Then regain balance gradually and return both feet, shield and mace to the original ready stance. '
        'Continuous moderate recoil and recovery, no instant pose reset, weapon release, extra arm, attack or collapse.'),
    'attack': ([14, 6, 7], 0, [[30, 1], [58, 2], [104, 0]],
        'One right-handed mace attack toward image right. Draw the short mace upward and back over the weapon-side shoulder while the shield stays on the left forearm. '
        'Swing the same mace forward and down in a clear physical arc, extend at contact, then retract and recover smoothly to ready. '
        'A single hammer head remains attached to the same short shaft. No projectile, spell, stretching shaft, shield-arm attack or body growth.'),
    'cast': ([14, 6], 0, [[48, 1]],
        'One physical rally salute, not a spell. Keep both feet planted, lift the right-hand mace above the shoulder and raise the chest with confidence, '
        'briefly present the shield, then lower the same mace and shield smoothly back to the original ready stance. '
        'Visible elbow and shoulder articulation, no strike, projectile, floating object, magical glow or particles.'),
    'death': ([14, 11, 12, 13], 3, [[38, 1], [82, 2]],
        'One continuous human collapse. Knees buckle, lower onto a knee, torso tips down toward image left, shield lowers with the left forearm. '
        'Fall onto the side with head toward image left and feet toward image right, matching the final grounded corpse. '
        'Keep the mace in the right hand as it lowers to rest and keep the single shield with the body. '
        'Two arms and two legs only, no popping apart, floating equipment, sudden teleport or standing again. Finish still.'),
}


def pose(index):
    x, y = index % 4 * 512, index // 4 * 256
    return dict(source=f'art/animation/runtime/poses/{UNIT}.png',
                rects=[[x, y, x + 512, y + 256]], anchor=[x + 256, y + 248],
                scale=1, alpha_noise_cutoff=8)


if __name__ == '__main__':
    for number, (clip, (indices, last, guides, action)) in enumerate(ACTIONS.items()):
        target = SOURCE / f'{clip}_v1'
        target.mkdir(exist_ok=True)
        assert not (target / 'submission.json').exists(), 'Submitted takes are immutable'
        config = dict(unit_id=UNIT, clip=clip, scale=.8, anchor=[480, 480],
                      key_rgb=[0, 255, 0], protected_foreground_chroma=32,
                      references=[pose(i) for i in indices], last=last, guides=guides,
                      seed=925901 + number,
                      tiled_decode=dict(tile_size=256, overlap=64, temporal_size=16, temporal_overlap=4),
                      prompt=IDENTITY + action)
        (target / 'config.json').write_text(json.dumps(config, indent=2) + '\n')
    (SOURCE / 'delivery.json').write_text(json.dumps(dict(takes=[], visual_review=dict(status='pending', notes='Original video actions await source and native review.')), indent=2) + '\n')
