"""Rebuild the explicitly partial pending candidate after original-frame review."""
import json
import produce as p

SELECTIONS={
 'attack_h3_v1':dict(source_frames=[24,26,28,30,32,34,36,38,40,42,44,55,75,77,79,81,83,85,87,89,92,96],frame_msec=55,contact_frame=10,
   review_note='Reviewed all 124 chronological original and matte frames, plus enlarged two grips, hook, rope, legs and cloth. One windup, two-hand short thrust and recovery. Contact is first full extension at original frame44 (1.833s). Four-source-pixel boundary-only despill addresses magenta rim without changing alpha/body geometry. Original long contact hold is shortened; source holds55/75 retain only their observed pixels. Continuous source/retimed playback unavailable; coordinator native review and final acceptance pending.'),
 'defend_h3_v1':dict(source_frames=[16,18,20,21,22,23,24,26,28,30,35,58],frame_msec=60,
   review_note='Reviewed all 124 chronological original/matte frames and enlarged original16,18,20,22,24,26,28,35,58,80,110. Both knees lower into dedicated brace; two hands retain one hook pole; guard remains low and readable. Final four-source-pixel boundary-only despill reviewed again over all124 matte frames and enlarged details; alpha/body geometry and genuine opaque teal unchanged. Stable green plate. Select articulated descent16-35 and held pose58, with the original long hold compressed. Continuous playback unavailable; coordinator native review and final acceptance pending.'),
 'cast_h3_v1':dict(source_frames=[26,28,30,32,34,36,38,40,42,44,47,84,86,88,90,92,94,96,98],frame_msec=65,contact_frame=10,
   review_note='Reviewed all 124 chronological original/matte frames and enlarged arms/grips at26,30,34,38,42,47,55,70,84,88,92,96. Noncaster physical signal visibly raises the same two-hand hook pole above the head, with both elbows extended, then recovers. No invented magic/projectile/equipment. Peak original47 (1.958s); source prolonged overhead hold compressed into authored held duration. Stable green plate. Continuous playback unavailable; coordinator native review and final acceptance pending.'),
 'death_h3_v1':dict(source_frames=[20,21,22,23,24,25,26,28,30,35,46,48,50,52,55,60,64,68,70,72,74,76,79,83,90,123],frame_msec=65,
   review_note='Reviewed all 124 chronological original/matte frames and enlarged20,23,26,30,40,46,49,55,66,70,75,83,95,123. Knees buckle, both hands lower one pole, hips lower onto side, torso settles with head right and pole grounded alongside. Two legs/two arms and rope survive. Last original123 is persistent corpse; no standing prop. Fixed .5 extraction scale/470,560 anchor, no posture normalization. Long kneel/corpse holds shortened. Stable green plate. Continuous playback unavailable; coordinator native review and final acceptance pending.')
}

if __name__=='__main__':
    for take,selection in SELECTIONS.items():
        durations=[selection['frame_msec']]*len(selection['source_frames'])
        if take=='attack_h3_v1':durations[10]=100;durations[11]=85
        if take=='defend_h3_v1':durations[-1]=160
        if take=='cast_h3_v1':durations[10]=200
        if take=='death_h3_v1':durations[-1]=120
        selection['frame_durations_msec']=durations
        out=p.SOURCE_DIR/take
        p.write(out/'selection.json',selection)
        p.build(out,json.loads((out/'config.json').read_bytes()))
    previous=json.loads((p.SOURCE_DIR/'delivery.json').read_bytes())
    initial=previous.get('initial_takes',previous['takes'])
    delivery=dict(previous,initial_takes=initial,takes=list(SELECTIONS),
        rejected_takes={
          'move_h3_v1':'Original plate cycles green/orange/magenta. Opposed gait contacts remain unproven; legacy gather and extension references pin the same forward shin. Requires new original opposed-contact/grounded-passing guide and measured green regeneration.',
          'hit_h3_v1':'Original plate alternates cyan/magenta through recoil/hold/recovery; cyan overlaps teal costume. No safe complete recoil+recovery matte. Requires measured green regeneration; preserve original recoil guide.'},
        visual_review=dict(status='pending',notes='Explicit partial four-action candidate: attack/defend/physical support/death. All six original sequences124 each inspected; eight reviewed original articulated idle poses preserved. Move/hit excluded. Original+matte chronological views and enlarged anatomy inspected; continuous playback unavailable. Source hold compression and Normal/Fast/reduced/save/corpse/native checks require coordinator review before acceptance/publication.'))
    p.write(p.SOURCE_DIR/'delivery.json',delivery)
    p.assemble()
