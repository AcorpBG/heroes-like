"""Retain source verdicts and remove the overly dense spoke constraints."""
import copy
import json
import produce as p


def main():
    S = p.SOURCE_DIR
    p.write(S/'death_h3_v2/visual_review.json', dict(
        status='qualified_source_pending_runtime', reviewer='coordinator',
        examined='All124 original RGB chronologically; enlarged alpha16..111; all124 native128 poses in each facing.',
        findings='Three supports fold20..33. Operator bends37..55 and descends beneath the chassis56..70; carriage tilts70..78. The quicker gravity pivot75..76 retains attached limbs and joints. Operator extends into the grounded final pose83..95; mirror settles96..103. Both wheels, single axle, both crystal rods and folded supports remain attached, without generated explosions or disappearing anatomy.',
        selection_reason='20..104 retains the loss of support, continuous fall, settling and grounded corpse;85 consecutive original frames at42ms.',
        review_limits='Chronological frame review, not a manual game test or continuous video playback. Actual runtime, imported textures, both facings and reduced motion remain required.'))
    p.write(S/'death_h3_v2/selection.json', dict(
        source_frames=list(range(20,105)), frame_msec=42,
        review_note='85 consecutive observed collapse poses, ending in grounded source104. Source-qualified; runtime pending.'))
    p.write(S/'move_h3_v3/visual_review.json', dict(
        status='rejected_at_original_RGB_review', reviewer='coordinator',
        examined='All124 original RGB chronologically in eight pages.',
        defect='The operator cranks and cape moves, but the blue wheel spokes stay nearly stationary. The alternate painted wheel phase and seven interior guides do not produce coherent forward rolling.',
        alpha_native_acceptance='Not performed or claimed after RGB rejection.', selection=[],
        reassessment='Dense interior spoke constraints may freeze wheel orientation. Use only the original initial rolling pose and the reviewed alternate spoke-phase endpoint, leaving the full temporal interval unconstrained for rotation. Require continuous directional rotation with fixed hubs/rims; inspect it before selecting any frames.',
        preservation='Original video, latent,124 decoded RGB hashes/mattes, guides and exact generation provenance retained.'))
    c = copy.deepcopy(json.loads((S/'move_h3_v3/config.json').read_bytes()))
    c['references'] = [c['references'][0], c['references'][4]]
    identity = c['prompt'].split('Use the same flat pale blue-gray background')[0]
    c.update(seed=2026100390, guides=[], last=1, correction_of='move_h3_v3',
        control_reassessment='Two endpoint originals only; remove every interior constraint; continuous forward spoke rotation is mandatory.',
        prompt=identity+'Use the same flat pale blue-gray background over the entire image in every frame. The two large blue spoked wheels continuously ROLL FORWARD around their fixed gold hubs, visibly rotating clockwise through one complete revolution and a further half revolution during the whole video. The blue spokes pass through progressively different angles at every moment; they do not oscillate, remain stationary or merely shimmer. Preserve the existing gold-and-ivory outer rims, wheel diameter, perspective and single axle. The carriage stays centered in place at the same elevated tactical camera angle because the game supplies travel. All three original star-foot struts stay folded up throughout. The same single operator works the existing crank with both hands while bending elbows and knees, with his cape following the motion. Both solid original crystal rods and the round mirror remain attached and inactive. Only the wheels rotate and operator articulates; no zoom, growth, added anatomy, glowing effects, flashes or projectiles. Gradually arrive at the supplied final spoke phase without replacing the whole pose.',
        visual_review='pending original video; two original endpoint guides personally reviewed', selection='not_selected')
    folder = S/'move_h3_v4'
    folder.mkdir(exist_ok=True)
    assert not (folder/'sampling_submission.json').exists()
    p.write(folder/'config.json', c)
    p.prepare(folder, c)
    p.verify(folder, c)
    print('DEATH85_SOURCE_QUALIFIED; MOVE3_REJECTED; MOVE4_ENDPOINT_ONLY_PREPARED', flush=True)


if __name__ == '__main__':
    main()
