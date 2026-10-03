"""Record personal source review; never imply published runtime acceptance."""
import shutil
from PIL import Image
import produce as p


def main():
    S = p.SOURCE_DIR
    p.write(S/'attack_h3_v1/visual_review.json', {
        'status': 'qualified_source_pending_runtime',
        'reviewer': 'coordinator',
        'examined': 'All124 original RGB chronologically; all124 alpha on dark/light backgrounds; all124 fixed128-native in EACH facing; original-size64,65,66,67 contact transition.',
        'findings': 'The observed action is a physical mounted launcher nose jab, rather than the requested front-foot counterthrust. Operator lowers and leans forward, then the mounted assembly pitches forward/down sharply at65..66, holds its lowered contact attitude and recovers84..96. Both original crystal tips, round mirror, two wheels, three star-foot struts and single operator remain continuous. Feet remain grounded; mirror occludes part of the crouched operator naturally. No shot, glow, projectile or added equipment. Clean matte retains all feet and narrow rods.',
        'selection_reason': 'Source28..96 retains the complete anticipatory operator lean, fast physical jab, held contact and return to ready. It is one chronological observed action, with no splice/reversal/interpolation. Source65..66 is the fastest assembly pitch and must be checked at actual Strike timing before final acceptance.',
        'contact_source_frame': 66,
        'review_limits': 'This was chronological original-frame inspection, not continuous video playback or a manual game test. Actual Godot native playback, both facings, contact, published import/map/reduced motion checks remain required.',
    })
    p.write(S/'attack_h3_v1/selection.json', {
        'source_frames': list(range(28,97)), 'frame_msec': 42,
        'contact_frame': 38,
        'review_note': '69 observed consecutive poses, source28..96. Source66/index38 is the physical jab contact;30 subsequent poses retain held contact and return to ready. Dedicated original melee source; runtime acceptance pending.',
    })
    p.write(S/'hit_h3_v1/visual_review.json', {
        'status': 'rejected_at_original_RGB_review', 'reviewer': 'coordinator',
        'examined': 'All124 original RGB chronologically.',
        'defect': 'Gold/white firing beam and flash across source23..33; blue front crystal tip is obscured/lost at25..26. This is not a clean physical recoil reaction.',
        'selection': [],
        'alpha_native_acceptance': 'Not performed or claimed after original RGB rejection.',
        'correction': 'Use the same original physical recoil guide with inert rods and a brief rearward carriage/operator jolt. Avoid firing or external impact semantics. Preserve the complete recovery rather than trimming away the flash and pretending the reaction is complete.',
        'preservation': 'All original videos, latents, guides,124 decoded RGB frames and124 mattes retained.',
    })
    original=p.Path('C:/Users/acorp/.codex/generated_images/01a0965d-a98e-7560-8e9d-802269b3760b/exec-dde6f8e3-7110-47ce-b077-65a0163fa6eb.png')
    folder=S/'rolling_rotation_key_v3';folder.mkdir(exist_ok=True)
    file=folder/'original.png'
    if not file.exists():shutil.copyfile(original,file)
    assert p.sha(file)==p.sha(original)
    shutil.copyfile(S/'rolling_rotation_key_v3.prompt.txt',folder/'prompt.txt')
    ref=S/'move_h3_v2/guide_0_chroma.png'
    p.write(folder/'generation.json',dict(tool='built-in image_gen.imagegen',original_tool_path=str(original),original_sha256=p.sha(file),prompt_path=(folder/'prompt.txt').relative_to(p.ROOT).as_posix(),prompt_sha256=p.sha(folder/'prompt.txt'),references=[dict(source=ref.relative_to(p.ROOT).as_posix(),sha256=p.sha(ref))],transparent_background=False,original_size=list(Image.open(file).size)))
    print('MELEE69_SOURCE_QUALIFIED_PENDING_RUNTIME; HIT_REJECTED; WHEEL_V3_ORIGINAL_PRESERVED',flush=True)


if __name__=='__main__':main()
