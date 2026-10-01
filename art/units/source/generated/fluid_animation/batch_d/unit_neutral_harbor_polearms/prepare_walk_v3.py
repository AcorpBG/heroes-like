"""Register reviewed opposite contact, preserving original source pixels."""
import json
import av
import numpy as np
from PIL import Image, ImageDraw
from scipy.ndimage import binary_erosion
import produce as p
from prepare_h3 import ref, IDENTITY, PLATE
from integrate_fluid_creature_animation import source_pose

def main():
    master = p.SOURCE_DIR / 'walk_opposed_contact_v5.png'
    opposite = dict(name='reviewed_opposite_foreground_trailing_contact_v5',
                    source=master.relative_to(p.ROOT).as_posix(),
                    rects=[[0, 0, 1536, 1024]], anchor=[785, 956],
                    scale=.204, alpha_noise_cutoff=8)
    ready = ref(13)
    # The first original movement's source20 unambiguously leads with the
    # foreground leg. Its pixels and the new genuinely opposite contact
    # establish both limb chains rather than re-labelling the same leg.
    observed = p.SOURCE_DIR / 'move_h3_v2/matte/rgba_020.png'
    if not observed.exists():
        take = observed.parent.parent
        original = json.loads((take/'original.json').read_bytes())
        assert p.sha(take/'original_lossless.mkv') == original['sha256']
        previous_config = json.loads((take/'config.json').read_bytes())
        with av.open(str(take/'original_lossless.mkv')) as video:
            for index, frame in enumerate(video.decode(video=0)):
                if index == 20:
                    rgba, _ = p.key(frame.to_image().convert('RGB'), previous_config)
                    observed.parent.mkdir(exist_ok=True)
                    rgba.save(observed)
                    break
        matte = json.loads((take/'matte.json').read_bytes())
        assert p.sha(observed) == matte['rgba_sha256'][20], 'Restored guide pixels differ'
    near = dict(name='observed_foreground_leading_contact_020',
                source=observed.relative_to(p.ROOT).as_posix(),
                rects=[[0, 0, 960, 640]], anchor=[420, 560], scale=.5,
                alpha_noise_cutoff=0, video_frame=20,
                video_time_seconds=20/24)
    out = p.SOURCE_DIR / 'move_h3_v3'
    assert not (out/'submission.json').exists(), 'Submitted take is immutable'
    out.mkdir(exist_ok=True)
    config = json.loads((p.SOURCE_DIR / 'move_h3_v2/config.json').read_bytes())
    config.update(references=[ready, near, opposite], last=0,
                  seed=2026100230,
                  guides=[[20, 1], [40, 0], [65, 2], [90, 0]],
                  prompt=(IDENTITY +
                    ' Perform one continuous walking-in-place cycle with TWO opposite leg contacts. '
                    'At20 the foreground near hip-to-knee-to-boot chain leads toward screen right; '
                    'the background far leg trails. Load the near heel, flex the far knee and pass '
                    'through the two-foot ready stance at40. Next the foreground near leg swings '
                    'BACK toward screen left while the background far leg swings FORWARD toward '
                    'screen right, to the exact supplied opposite contact at65. Load the far heel, '
                    'keep its boot grounded as the near knee passes forward, then return through '
                    'double support at90 and finish in the original ready stance. Knees and ankles '
                    'trace continuous arcs between these contacts, never swap or teleport. '
                    'Keep the pelvis centered, body proportions unchanged, and the full rigid '
                    'boarding pole in its original two separate grips. The foreground broad tan '
                    'trouser leg must trail at65, unlike its forward-leading contact at20. ' + PLATE).strip())
    p.prepare(out, config)
    bands = []
    for i in range(3):
        arr = np.asarray(Image.open(out/f'guide_{i}_rgba.png')).astype(float)
        inside = binary_erosion(arr[:, :, 3] > 240, iterations=3)
        bands.append(float((arr[:, :, 1]-np.maximum(arr[:, :, 0], arr[:, :, 2]))[inside].max()))
    config['protected_foreground_chroma'] = max(0, int(max(bands)) + 2)
    config['foreground_measurement'] = dict(per_guide_max=bands,
        rule='Eroded opaque green-minus-max(red,blue) maximum plus two across all three guides.')
    config['guide_scale_reason'] = (
        'Generated full-body master .204 uniformly registers its cap-to-ground span '
        'to the retained191px idle, with torso/buckler/shaft sizes reviewed at native scale. '
        'Original accepted idle .44 and observed video .5 unchanged. Fixed root785,956 '
        'places both legitimate opposing contact boots on the same plane. No per-frame normalization.')
    config['guide_registration_review'] = dict(status='approved_for_H3_reference_only',
        master_sha256=p.sha(master), source_scale=.204, source_anchor=[785,956],
        findings='Exactly two traceable legs: broad foreground thigh extends to trailing screen-left boot; occluded background thigh extends to screen-right leading boot. Both hands keep the single rigid pole; forearm buckler, cap, coat, belt lantern and rope intact. Raw backdrop RGB has alpha0 and is composited away. Native light/dark alpha and accepted-body scale reviewed. Video motion remains pending.')
    p.write(out/'config.json', config)
    sheet = Image.new('RGB', (1200,420), (35,44,35))
    draw = ImageDraw.Draw(sheet)
    for i, label in enumerate(['Accepted ready', 'Observed foreground leads', 'New background leads']):
        frame = [ready, near, opposite][i]
        pose, offset = source_pose(frame, frame['alpha_noise_cutoff'])
        sheet.paste(pose, (i*400+200+offset[0], 350+offset[1]), pose)
        draw.text((i*400+10,10), label)
        draw.line((i*400+30,352,i*400+370,352), fill=(110,110,65))
    artifact = p.ROOT/'.artifacts/creature_sets_20261001/harbor_walk_v3_registration.png'
    sheet.save(artifact)
    p.write(out/'registration_review.json', config['guide_registration_review'])
    print('Registered original opposite-contact reference; no GPU submission.')

if __name__ == '__main__':
    main()
