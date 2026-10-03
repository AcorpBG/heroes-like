"""Record personally observed source verdicts, retaining unresolved transitions."""
import copy
import json
import produce as p


def main():
    S = p.SOURCE_DIR
    p.write(S/'defend_h3_v2/visual_review.json', dict(
        status='qualified_source_pending_runtime', reviewer='coordinator',
        examined='All124 original RGB chronologically; alpha16..79 on alternating dark/light; fixed native128 poses0..95 in each facing.',
        findings='Operator knees, elbows and torso gradually lower behind the round mirror while the mirror pivots into cover. The transition20..64 preserves two wheels, original axle, three planted star feet, both solid crystal rods and one operator. Held guard64..68 retains attached grips and clean thin equipment silhouettes. No forced interior pose substitution or generated attack effects.',
        selection_reason='16..68 includes the continuous entry and five observed held-cover poses. All53 consecutive originals at42ms; final frame is the held guard.',
        review_limits='Chronological frame inspection, not continuous video playback or manual game test. Actual native runtime/import/map/reduced checks remain required.'))
    p.write(S/'defend_h3_v2/selection.json', dict(
        source_frames=list(range(16,69)), frame_msec=42,
        review_note='53 consecutive original transition/held guard poses; source-qualified, runtime pending.'))
    p.write(S/'cast_h3_v2/visual_review.json', dict(
        status='rejected_at_original_transition_review', reviewer='coordinator',
        examined='All124 original RGB chronologically; alpha32..95 on dark/light; original-size59,60,90,91.',
        defect='Baked ring is gone, but source59..60 abruptly substitutes the supplied calibration chassis attitude: launcher axis, mirror, front strut and operator shift together.90..91 makes another whole-carriage shift during recovery. The manual lean alone does not repair the missing mechanical transitions.',
        selection=[], native_acceptance='Not performed or claimed after source rejection.',
        reassessment='After two failed support takes, the interior separately painted peak is unsuitable as a hard temporal constraint despite wheel-diameter registration. Remove it entirely, use the same ready original at both endpoints, and request only an operator crank gesture with the stationary carriage retaining its original attitude.',
        preservation='All original video, latent,124 RGB hashes/mattes, guides and provenance retained.'))
    c = copy.deepcopy(json.loads((S/'cast_h3_v2/config.json').read_bytes()))
    identity = c['prompt'].split('Use the same flat pale blue-gray background')[0]
    c.update(seed=2026100389, references=[c['references'][0]], guides=[], last=0,
        prompt=identity+'Use the same flat pale blue-gray background over the entire image in every frame. One continuous physical support gesture by the existing operator. He bends his elbows and shoulders, leans his torso over the existing rear handle and visibly works that handle with both original hands through the middle of the video, then smoothly stands back in his supplied initial stance. Exactly two arms, two legs, one head, one cape. The blue cape follows his body and settles. The launcher carriage itself stays in exactly its initial attitude and position: both wheels and axle, all three star feet, round mirror, long blue front rod and short amber rear rod stay stationary, solid and attached throughout. Only the operator and existing small rear handle articulate. No mirror tilt, whole-carriage pitch, growing parts, pose replacement, camera motion, symbols, light rings, rays, projectiles or flashes.',
        correction_of='cast_h3_v2', control_reassessment='Remove separate interior peak; same ready original endpoints, operator-only motion.',
        visual_review='pending original video; unchanged ready original already personally reviewed', selection='not_selected')
    folder = S/'cast_h3_v3'; folder.mkdir(exist_ok=True)
    assert not (folder/'sampling_submission.json').exists()
    p.write(folder/'config.json', c); p.prepare(folder,c); p.verify(folder,c)
    print('BRACE53_SOURCE_QUALIFIED; SUPPORT_V2_REJECTED; SUPPORT_V3_CONTROL_REASSESSED_PREPARED', flush=True)


if __name__ == '__main__':
    main()
