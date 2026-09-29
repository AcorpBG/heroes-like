"""Recover the missing visible hammer arc using three original video guides."""
import json
import produce as p
from prepare import IDENTITY, PLATE

if __name__ == '__main__':
    original = p.SOURCE_DIR / 'attack_h3_v1'
    out = p.SOURCE_DIR / 'attack_swing_h3_v1'
    out.mkdir(exist_ok=False)
    c = json.loads((original / 'config.json').read_bytes())
    c.update(seed=2026093301, guides=[[30, 1]], last=2)
    c['references'] = [dict(
        source=(original / 'matte' / f'rgba_{i:03}.png').relative_to(p.ROOT).as_posix(),
        rects=[[0, 0, 960, 640]], anchor=c['anchor'], scale=c['scale'],
        alpha_noise_cutoff=0) for i in [44, 46, 54]]
    c['prompt'] = IDENTITY + (
        'Begin with the right elbow bent and the hammer above the shoulder. '
        'Perform only the downward swing, gradually in slow motion over the whole shot. '
        'First extend the right forearm forward and upward to the supplied upright-hammer guide. '
        'Then visibly rotate the right shoulder and elbow, carrying the rigid hammer head in '
        'one continuous curved arc DOWN IN FRONT OF THE SHIELD toward the final low position. '
        'The right hand, forearm, handle and hammer head remain visible in front of the shield '
        'through the middle of the arc. The closed right hand grips the same handle throughout. '
        'Bend the knees and lean forward gradually with the swing. End in the supplied low '
        'follow-through pose. No sudden jump from raised hammer to lowered hammer. '
        'No recovery, no second swing. One clearly visible slow downward arc. '
    ) + PLATE
    c['correction_reason'] = 'Original attack frames 46-48 hide the hammer and right forearm in an abrupt swing. Retain windup/recovery; regenerate only the visible downward arc.'
    c['prompt'] = c['prompt'].strip()
    p.prepare(out, c)
    p.write(out / 'config.json', c)
    print('Prepared targeted swing correction; no generation submitted.')
