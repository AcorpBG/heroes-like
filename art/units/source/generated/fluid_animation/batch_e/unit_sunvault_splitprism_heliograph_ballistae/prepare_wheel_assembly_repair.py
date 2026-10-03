"""Reassess failed rolling by isolating its physical wheel assembly control."""
import json
import produce as p

PROMPT='''Edit the supplied original fantasy siege-cart image. Isolate ONLY its two original cobalt-blue spoked wheels, ivory-and-gold studded wheel rims, gold central hubs and the horizontal connecting axle. Remove the entire launcher, operator, round mirror, crystal rods, stabilizer legs, platform and central shield. Keep the original near-right wheel and far-left wheel in exactly their existing relative positions and original three-quarter LEFT-facing wheel planes, circumference, thickness, eight-spoke design, materials and painting style. Keep the original foreshortening and relative size: the near-right wheel is slightly larger, while the far-left wheel is slightly smaller and higher. The two wheels must remain parallel on a single gold axle. Do not invent extra wheels, fingers, scenery, text, effects, shadows on a background, or supporting stand. Preserve the visible gaps between the eight blue spokes. Leave ample transparent empty margin around the complete two-wheel assembly. This is an original mechanical subassembly control for a wheel-rotation video, not a redesign of the cart. Transparent background.'''

def main():
    S=p.SOURCE_DIR
    p.write(S/'move_h3_v5/visual_review.json',dict(
        status='rejected_at_original_RGB_review',reviewer='coordinator',
        examined='All124 original RGB frames in eight chronological pages and all124 enlarged original near-wheel hub-following detail frames. Observer translation is only a review aid, never accepted extraction.',
        defect='The carriage translates left by approximately450px but its spokes oscillate through a small angle about their original positions. There is no sustained counterclockwise wheel revolution. This is sliding, not physical rolling.',
        source_quality='Operator cranking, original body, rods, mirror, wheel diameters and raised supports remain usable. Preserve these originals rather than regenerating good actions.',
        selection=[],alpha_native_acceptance='Not performed or claimed after original-RGB rejection.',
        reassessment='Animate the original two-wheel/axle subassembly as a close-up separate H3 source with one fixed perspective and wheel hubs. If actual sustained rotation is observed, combine only these new original wheel pixels with preserved body/operator video using personally reviewed anatomical axle contacts; never software-rotate or interpolate the old wheel image.',
        preservation='All original videos,latents,124matte frames,prompts,guides and RGB hashes retained.'))
    folder=S/'wheel_assembly_key_v1'
    folder.mkdir(exist_ok=True)
    assert not (folder/'original.png').exists()
    (folder/'prompt.txt').write_text(PROMPT+'\n',encoding='utf-8')
    reference=S/'move_h3_v5/matte/rgba_000.png'
    p.write(folder/'reference.json',dict(path=reference.relative_to(p.ROOT).as_posix(),sha256=p.sha(reference),
        role='Original wheel design and relative axle geometry; isolate without changing the rest of the accepted cart.'))
    print('MOVE5_REJECTED; ORIGINAL_WHEEL_ASSEMBLY_CONTROL_PROMPT_READY',flush=True)

if __name__=='__main__':main()
