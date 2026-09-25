"""Original Gorefen anatomy, fixed-scale guides and separate H3 action briefs."""
import json
from pathlib import Path

SOURCE = Path(__file__).resolve().parent
UNIT = 'unit_mireclaw_gorefen_rippers'
IDENTITY = (
    'Locked orthographic camera, original richly painted fantasy strategy game sprite on a perfectly uniform vivid GREEN RGB(0,255,0) background. '
    'The background stays identical everywhere and throughout, including all gaps between claws and legs. No scenery, floor shadow, text, particles or colored lighting. '
    'One large muscular crocodilian quadruped: dark slate grey-brown pebbled scales, pinkish belly, long crocodile snout with ivory teeth, '
    'red quill crest along its head, neck and back, exactly ONE long curved tail with red fin spines. '
    'Tan rope harness and small ivory bone/fang fetishes hang over its back, chest and sides. Exactly FOUR legs with hooked dark claws, ONE head and ONE tail. '
    'Forelegs are beneath the shoulders toward IMAGE RIGHT; hindlegs beneath the pelvis toward IMAGE LEFT. Keep near and far legs anatomically distinct. '
    'Preserve the same skull, muzzle length, eyes, scales, crest, ropes, ornaments and claws. No rider, wings, humanoid arms, weapons, extra legs or magic. '
    'Stable three-quarter RIGHT-facing view, no camera motion, zoom or changes in anatomical scale. Full body and tail stay visible with ample margins. '
)
ACTIONS = {
    'hit': ([11], 0, [],
        'One moderate hit arrives from IMAGE RIGHT. The head and shoulder recoil back, foreleg elbows flex and hindlegs take weight. '
        'Then regain balance gradually and restore the original ready stance. Keep the four paws supported; the tail counterbalances and settles. '
        'Continuous recoil and recovery, no jump, roll, spin, attack, collapse or frozen pose followed by an instant reset.'),
    'defend': ([11, 6], 1, [],
        'Continuously lower the chest and neck into the supplied defensive crouch. Forelegs bend and spread slightly to brace; hindlegs retain support. '
        'Keep the snout forward and low, protect the soft belly, curl the tail upward for balance. Hold the final guarded crouch. '
        'No attack, jump, new tail or return to standing at the end.'),
    'move': ([2], 0, [],
        'Walk in place through two slow complete four-beat reptilian walking cycles. Each near and far forepaw and hindpaw must lift, swing forward, '
        'plant and support weight in turn, while the other paws support the body. Show alternating opposing contacts and clear passing phases. '
        'The body center stays fixed for engine-driven travel; the tail counterbalances, ropes and ornaments sway gently. '
        'Return smoothly to the starting gait phase. No hopping with all feet airborne, dragging, sliding, backwards steps, duplicated feet or changing direction.'),
    'attack': ([11, 4, 5], 0, [[30, 1], [58, 2], [104, 0]],
        'Perform one vicious forward bite and foreclaw lunge. Load weight onto the hindlegs and open the jaws in anticipation, '
        'drive the head and near foreclaw toward IMAGE RIGHT, snap the jaw closed at contact, then withdraw the head and forepaw. '
        'Recover all four feet and the original ready posture smoothly. Preserve the full snout, one lower jaw and all teeth. '
        'No projectile, tail strike, magic, extra attack or reversal of facing.'),
    'cast': ([11, 1], 0, [[54, 1]],
        'Perform one physical rally roar, not a magic spell. Brace all four feet, take a deep breath, raise the chest and head, '
        'open the jaw to roar upward while the shoulders and forelegs visibly tense. Then close the jaw, lower the head and chest and return to ready. '
        'The tail flexes naturally and the bone ornaments sway. No forward attack, beam, glow, particles or new objects.'),
    'death': ([11, 8, 9, 10], 3, [[36, 1], [86, 2]],
        'One continuous loss of support and collapse. Foreleg elbows buckle and the chest lowers first; hindquarters then sink, '
        'the body tips onto its side and all four legs fold toward IMAGE LEFT. Head and long snout remain toward IMAGE RIGHT. '
        'The tail uncurls and rests on the ground toward IMAGE LEFT; ropes and bones settle with the body. '
        'Match the final side-lying corpse, finish completely still, no standing again, disintegration, extra limbs or flipping head/tail orientation.'),
}


def pose(index):
    x, y = index % 4 * 512, index // 4 * 256
    return dict(source=f'art/animation/runtime/poses/{UNIT}.png',
                rects=[[x, y, x + 512, y + 256]], anchor=[x + 256, y + 236],
                scale=1, alpha_noise_cutoff=8)


if __name__ == '__main__':
    for number, (clip, (indices, last, guides, prompt)) in enumerate(ACTIONS.items()):
        target = SOURCE / f'{clip}_v1'
        target.mkdir(exist_ok=True)
        assert not (target / 'submission.json').exists(), 'Submitted takes are immutable'
        config = dict(unit_id=UNIT, clip=clip, scale=.8, anchor=[480, 480],
                      key_rgb=[0, 255, 0], protected_foreground_chroma=72,
                      references=[pose(i) for i in indices], last=last, guides=guides,
                      seed=925801 + number,
                      tiled_decode=dict(tile_size=256, overlap=64, temporal_size=16, temporal_overlap=4),
                      prompt=IDENTITY + prompt)
        (target / 'config.json').write_text(json.dumps(config, indent=2) + '\n')
    (SOURCE / 'delivery.json').write_text(json.dumps(dict(takes=[f'{c}_v1' for c in ACTIONS]), indent=2) + '\n')
