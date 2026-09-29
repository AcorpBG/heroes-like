"""Replace detached-hair recoil frames while retaining the original recovery."""
import json
import produce as p
from prepare import IDENTITY, PLATE

if __name__ == '__main__':
    original = p.SOURCE_DIR / 'hit_h3_v1'
    out = p.SOURCE_DIR / 'hit_recoil_h3_v1'
    out.mkdir(exist_ok=False)
    c = json.loads((original / 'config.json').read_bytes())
    c.update(seed=2026093302, guides=[[35, 1]], last=2)
    c['references'] = [dict(
        source=(original / 'matte' / f'rgba_{i:03}.png').relative_to(p.ROOT).as_posix(),
        rects=[[0, 0, 960, 640]], anchor=c['anchor'], scale=c['scale'],
        alpha_noise_cutoff=0) for i in [18, 25, 45]]
    c['prompt'] = IDENTITY + (
        'Perform just the backward recoil, slowly and continuously. Start upright. '
        'Gradually bend both knees, tilt the shoulders backward and lift the chin, '
        'ending in the supplied off-balance but supported standing pose. '
        'Hair stays attached to the scalp in the same short tousled silhouette. '
        'No loose curls, flying particles or detached fragments. The right hand '
        'keeps the hammer low; the shield stays on the left forearm. Both boots '
        'support the body. Show continuous intermediate shoulder, elbow and knee '
        'positions, with no sudden head jerk. End at the recoil extreme and hold. '
        'No recovery in this shot. '
    ) + PLATE
    c['correction_reason'] = 'Original hit frames 26-32 contain a detached floating hair fragment. Preserve recovery; replace the active recoil with attached-hair motion.'
    c['prompt'] = c['prompt'].strip()
    p.prepare(out, c)
    p.write(out / 'config.json', c)
    print('Prepared targeted recoil correction; no generation submitted.')
