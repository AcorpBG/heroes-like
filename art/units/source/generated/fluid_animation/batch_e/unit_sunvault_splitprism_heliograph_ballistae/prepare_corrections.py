"""Preserve rejected originals and prepare narrowly corrected H3 sources."""
import copy
import json
import produce as p


def main():
    S = p.SOURCE_DIR
    review = {
        'unit_id': S.name,
        'reviewer': 'coordinator personal original chronology and native inspection',
        'move_h3_v1': {
            'status': 'rejected_for_movement',
            'examined': 'all 124 RGB, all 124 alpha, all 124 fixed-native128 poses in both facings on dark/light backgrounds',
            'identity': 'Two wheels, three folded star-foot supports, single operator, lens and both equipment tips remain coherent; alpha clean.',
            'defect': 'Operator arm/crank and cape move, but wheel spokes predominantly oscillate near their original orientation instead of sustained rolling. Crank articulation alone does not qualify a dedicated carriage movement clip.',
            'selection': [],
        },
        'ranged_h3_v1': {
            'status': 'rejected_at_original_RGB_review',
            'examined': 'all 124 original RGB frames in chronological order; original three guide canvases rechecked',
            'defect': 'Source frames 25-31, 34-41 and 46-55 introduce baked blue projectiles/flash. The original solid triangular blue launcher tip is lost through much of frames 28-73 and then reappears. An exact guide at45 does not fix intervening equipment loss or repeated shots.',
            'selection': [],
            'alpha_native_acceptance': 'not performed or claimed for this already rejected take',
        },
        'preservation': 'All source RGB videos, latents, full mattes, guides, prompts, model settings and hashes retained unchanged. No source pixels edited; no published animation or gameplay changed.',
    }
    p.write(S/'initial_pair_review.json', review)

    corrections = {
        'move_h3_v2': (
            'move_h3_v1', 2026100362, [[60, 2]],
            'Animate one continuous forward rolling loop of this wheeled carriage in place. '
            'The two original blue spoke disks visibly revolve clockwise around their own stationary gold axle hubs, each completing a full revolution during this shot. '
            'Their circular ivory-and-gold rims and diameter stay unchanged; only the disks rotate, the axle and vertical blue front chassis plate remain stationary. '
            'Wheel angular motion proceeds in the same direction throughout, rather than wobbling backward and forward. '
            'All three original star-foot supports stay folded UP beside the chassis throughout; only the two wheel rims contact the same ground reference. '
            'The single operator visibly turns the hand crank in a smooth circle with bending elbows and balanced knees; cape follows. '
            'The rigid blue and amber rods and round lens remain mounted, unchanged and inactive. '
            'Fixed camera and fixed central axle position, no whole-body translation or zoom. Smoothly match the initial rolling pose at the end.'
        ),
        'ranged_h3_v2': (
            'ranged_h3_v1', 2026100363, [[36, 1], [60, 2]],
            'Animate exactly one physical spring-compression and recoil cycle of the original carriage. '
            'First the single operator leans forward, bending both elbows while winding the existing rear crank. '
            'Then the mechanism briefly compresses along its original mount and the operator absorbs one backward recoil, knees and elbows bending. '
            'Finally the operator returns smoothly to the original ready stance and grip. '
            'The long solid blue crystalline rod INCLUDING its triangular blue tip remains visibly attached, continuous and identical throughout, just as in every supplied guide. '
            'The shorter amber rod also stays attached and intact. Both rods are rigid inert equipment; nothing leaves them. '
            'Only the operator, crank, mount and slight lens pivot articulate. Three gold star feet remain planted on the same ground reference and both wheels stay still. '
            'Keep the empty blue-gray background entirely empty throughout. No detached blue triangle, light streak, ray, projectile, muzzle flash, spark or particle at any point. '
            'One compression/recoil followed by recovery, no repeated cycles.'
        ),
    }
    for name, (parent, seed, guides, beats) in corrections.items():
        c = copy.deepcopy(json.loads((S/parent/'config.json').read_bytes()))
        # Retain the personally reviewed identity/camera/material constraints.
        identity = c['prompt'].split('Use the same flat pale blue-gray background')[0]
        c.update(seed=seed, guides=guides,
                 prompt=identity + 'Use the same flat pale blue-gray background over the whole image in every frame. Entire carriage, tips and feet stay safely inside the frame. ' + beats,
                 visual_review='pending_new_original_video; original guide images personally rechecked',
                 correction_of=parent, selection='not_selected')
        folder = S/name
        folder.mkdir(exist_ok=True)
        assert not (folder/'sampling_submission.json').exists(), 'Submitted take is immutable'
        p.write(folder/'config.json', c)
        p.prepare(folder, c)
        p.verify(folder, c)
        for i in range(len(c['references'])):
            assert p.sha(folder/f'guide_{i}_chroma.png') == p.sha(S/parent/f'guide_{i}_chroma.png')
    print('Two corrected action graphs prepared from exact reviewed original guides; no new source accepted.')


if __name__ == '__main__':
    main()
