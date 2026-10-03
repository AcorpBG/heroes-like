"""Preserve actual review verdicts and prepare a less constrained collapse."""
import copy
import json
import produce as p


def main():
    S = p.SOURCE_DIR
    p.write(S/'hit_h3_v2/visual_review.json', dict(
        status='qualified_source_pending_runtime', reviewer='coordinator',
        examined='All124 original RGB in chronological order; all124 alpha on alternating dark/light; all124 fixed native128 in each facing.',
        findings='One physical operator and mount recoil. Operator begins leaning back around24..39, reaches the brief rearward reaction40..44, restores grip and torso45..58, then settles. Both crystal tips remain solid and attached throughout; two wheels, round mirror and three planted star feet retain identity. No beam, flash or generated external impact. Matte preserves thin rods, feet, operator and both wheel gaps.',
        selection_reason='24..60 preserves onset, brief recoiled hold and complete recovery. Keep all37 consecutive observed frames at42ms; no interpolation, reversal or splice.',
        review_limits='Chronological frame inspection, not continuous video playback or a manual game test. Actual native runtime and published import/map/reduced checks remain required.'))
    p.write(S/'hit_h3_v2/selection.json', dict(
        source_frames=list(range(24,61)), frame_msec=42,
        review_note='37 consecutive original poses retain physical recoil and recovery. No baked shot. Source-qualified; actual runtime pending.'))
    p.write(S/'death_h3_v1/visual_review.json', dict(
        status='rejected_at_original_RGB_review', reviewer='coordinator',
        examined='All124 original RGB in chronological order.',
        defect='Source26..27 abruptly substitutes the tilted carriage attitude at the interior guide. After a long operator hold under the tilted carriage,75..76 substitutes the final flat operator/corpse pose rather than continuously lowering the body. Intermediate wheel/strut proportions also change during the first forced tilt. Endpoint correctness does not repair these missing collapse transitions.',
        selection=[], alpha_native_acceptance='Not performed or claimed after RGB rejection.',
        correction='Remove all interior collapse guides. Retain initial ready and terminal wreck originals at their fixed scale/origin, giving the model the entire interval for a continuous physical loss of support, operator fall, carriage tilt and grounded settling.',
        preservation='Original lossless video, latent, all124 original-frame hashes and semantic mattes, guides and prompt provenance retained.'))
    name='death_h3_v2'
    c=copy.deepcopy(json.loads((S/'death_h3_v1/config.json').read_bytes()))
    identity=c['prompt'].split('Use the same flat pale blue-gray background')[0]
    c['references']=[c['references'][0],c['references'][-1]]
    c.update(seed=2026100387, guides=[], last=1,
        prompt=identity+'Use the same flat pale blue-gray background over the entire image in every frame. One continuous physical mechanical collapse. The operator loses his grip, bends at hips and knees, and gradually falls beside and underneath the tilting carriage, keeping exactly two arms and two legs. The three original star-foot struts buckle along their existing joints; the single axle and both original blue-gold wheels tilt together with the carriage, preserving wheel diameters and spoke count. The round mirror lowers naturally with the original mount and gradually becomes dark. Both long blue front and short amber rear crystal rods remain attached. The operator and carriage come to rest together on the ground in the supplied terminal wreck pose by the end. Use visibly intermediate angles and anatomical contacts throughout the fall. No sudden replacement of the operator or carriage, no camera rotation, no explosions, flashes, projectile, extra parts, growing wheels, added limbs or return to ready.',
        correction_of='death_h3_v1', visual_review='pending original video; endpoint originals personally inspected', selection='not_selected')
    folder=S/name;folder.mkdir(exist_ok=True)
    assert not (folder/'sampling_submission.json').exists()
    p.write(folder/'config.json',c);p.prepare(folder,c);p.verify(folder,c)
    print('HIT37_SOURCE_QUALIFIED_PENDING_RUNTIME; DEATH_V1_REJECTED; DEATH_V2_PREPARED_UNSUBMITTED',flush=True)


if __name__=='__main__':main()
