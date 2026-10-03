"""Prepare a close-up H3 control for genuine original wheel rotation."""
import json
import numpy as np
from PIL import Image
from scipy.ndimage import label
import produce as p

def main():
    S=p.SOURCE_DIR;key=S/'wheel_assembly_key_v1'
    im=Image.open(key/'original.png').convert('RGBA');a=np.asarray(im).copy()
    labels,n=label(a[:,:,3]>=8,structure=np.ones((3,3),dtype=np.uint8))
    counts=np.bincount(labels.ravel());counts[0]=0;major=int(counts.argmax())
    assert counts[major]>170000
    assert all(counts[i]<=3 for i in range(1,n+1) if i!=major)
    # A single connected mechanical assembly was personally inspected; the
    # only detached alpha specks contain at most three pixels each.
    a[labels!=major]=0
    Image.fromarray(a,'RGBA').save(key/'assembly_alpha.png')
    p.write(key/'generation.json',dict(tool='built-in image_gen',
        original_sha256=p.sha(key/'original.png'),prompt_sha256=p.sha(key/'prompt.txt'),
        reference=json.loads((key/'reference.json').read_bytes()),
        tool_output='exec-ee2f0cd9-2a35-45f6-9779-63eedb3fe4e6.png',
        status='reviewed_component_control_only; full-unit integration still pending',
        observed='Two parallel blue eight-spoked wheels, ivory/gold rims and a gold connecting axle; one near-right and one far-left. Main wheel material/perspective retained. Relative vertical offset differs from the original chassis and must be matched to its actual separate axle contacts during any later source compositing. This key alone does not qualify movement.',
        alpha_recipe=dict(threshold=8,keep_component=major,
            detached_component_limit_pixels=3,retained_pixels=int(counts[major]),
            derived_sha256=p.sha(key/'assembly_alpha.png'),
            rule='Retained connected assembly RGB/alpha bytes unchanged; only isolated alpha specks and alpha<8 plate noise cleared. Original immutable.')))
    folder=S/'wheel_assembly_h3_v1';folder.mkdir(exist_ok=True)
    assert not (folder/'sampling_submission.json').exists()
    ref=dict(name='original_isolated_two_wheel_axle',
        source=(key/'assembly_alpha.png').relative_to(p.ROOT).as_posix(),
        source_sha256=p.sha(key/'assembly_alpha.png'),rects=[[496,279,1256,743]],
        anchor=[874,741],scale=.15,alpha_noise_cutoff=0)
    c=dict(unit_id=S.name,action='move',component='two_wheel_axle',
        canvas=[960,704],scale=.15,anchor=[480,576],key_rgb=[190,206,222],
        seed=2026100392,references=[ref],guides=[],last=None,
        tiled_decode=dict(tile_size=512,overlap=64,temporal_size=16,temporal_overlap=4),
        prompt='Close-up of this ORIGINAL MECHANICAL TWO-WHEEL AXLE assembly. The TWO blue eight-spoked cart wheels ROTATE continuously COUNTERCLOCKWISE in their original wheel planes. Over five seconds every gold rim stud and blue spoke travels through FOUR full turns around its gold hub. The gold axle and both hub CENTERS remain fixed and horizontal relative to this image. Only the blue spoked wheels and their ivory-gold outer rims spin around the stationary axle. The near-right wheel and far-left wheel spin together at the same angular rate. Their circular geometry, diameter, eight solid spokes, visible rim thickness, existing inclined elliptical perspective and original blue/ivory/gold materials remain unchanged. The wheel planes stay PARALLEL and in their supplied three-quarter LEFT-facing view, with no steering, tipping or orbiting. Fixed camera, no pan, zoom, translation or viewpoint rotation. One coherent original physical wheel rotation for the whole clip. Plain pale blue-gray empty backdrop, no chassis, people, launcher, scenery, extra wheels, stand, particles, text or effects.',
        control_reassessment='Isolate the mechanism so operator cranking cannot substitute for wheel rotation. First-frame only; no matching-endpoint freeze. Qualification requires chronological original spoke/stud rotation proof, stable wheel hubs and original rim geometry, then personal full-unit composite review.',
        visual_review='pending original video',selection='not_selected')
    p.write(folder/'config.json',c);p.prepare(folder,c);p.verify(folder,c)
    print('FOCUSED_ORIGINAL_TWO_WHEEL_H3_CONTROL_PREPARED',flush=True)

if __name__=='__main__':main()
