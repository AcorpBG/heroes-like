#!/usr/bin/env python3
"""Make explicit near/far-limb pose references, never shipped sprite artwork.

The SVG is an authoring diagram for original raster generation. Coordinates are
fixed across phases; equipment identity comes from a separate curated reference.
No source painting is read, altered, mirrored or warped by this tool.
"""
import argparse
from pathlib import Path
import subprocess

POSES = (
    ("A contact / blue forward", [(240, 306), (294, 392), (347, 476)],
     [(264, 306), (208, 390), (166, 470)]),
    ("A passing / blue supports", [(240, 306), (260, 390), (258, 476)],
     [(264, 306), (303, 368), (252, 407)]),
    ("B contact / orange forward", [(240, 306), (197, 389), (155, 470)],
     [(264, 306), (308, 391), (359, 476)]),
    ("B passing / orange supports", [(240, 306), (294, 362), (263, 412)],
     [(264, 306), (261, 391), (264, 476)]),
)


def limb(points, color):
    line = " ".join(f"{x},{y}" for x, y in points)
    joints = "".join(f'<circle cx="{x}" cy="{y}" r="9" fill="white" stroke="{color}" stroke-width="5"/>'
                     for x, y in points)
    x, y = points[-1]
    return (f'<polyline points="{line}" fill="none" stroke="{color}" stroke-width="27" stroke-linecap="round" stroke-linejoin="round"/>'
            + joints + f'<path d="M{x-9} {y}h40" stroke="{color}" stroke-width="17" stroke-linecap="round"/>')


def guide(phase=None):
    selected = POSES if phase is None else [POSES[phase]]
    width = len(selected)*512
    parts = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="600" viewBox="0 0 {width} 600">',
             f'<rect width="{width}" height="600" fill="white"/>',
             '<g font-family="DejaVu Sans" fill="#1b2330">']
    for i, (name, near, far) in enumerate(selected):
        parts += [f'<g transform="translate({i*512},0)">',
                  f'<text x="22" y="35" font-size="21">{name}</text>',
                  '<path d="M35 488H480" stroke="#9ba9ba" stroke-width="2"/>',
                  limb(far, '#e08020'),
                  '<path d="M216 180L273 180L290 294L261 317L219 303Z" fill="#d5dce5" stroke="#586879" stroke-width="3"/>',
                  '<ellipse cx="251" cy="139" rx="32" ry="39" fill="#d5dce5" stroke="#586879" stroke-width="3"/>',
                  '<path d="M281 132L298 146L281 149" fill="#d5dce5" stroke="#586879" stroke-width="3"/>',
                  '<path d="M227 195L210 247L273 265 M271 198L304 235L293 265" fill="none" stroke="#586879" stroke-width="18" stroke-linecap="round"/>',
                  limb(near, '#147dc1'),
                  '<text x="55" y="545" font-size="18">BLUE = near leg; ORANGE = far leg</text>',
                  '<text x="55" y="575" font-size="17">Fixed camera / body faces RIGHT</text>', '</g>']
    return "\n".join(parts + ['</g></svg>'])


def quadruped(phase):
    """Single side-on four-limb gait reference; not a rendered unit sprite."""
    # Anatomical attachment coordinates stay fixed. Separate fore/hind pairs
    # make near/far ownership explicit without mirroring the creature's torso.
    phases = (
        ([(365,260),(407,348),(440,455)], [(395,252),(354,347),(330,450)],
         [(145,260),(96,330),(78,455)], [(175,252),(198,338),(226,450)]),
        ([(365,260),(365,355),(365,455)], [(395,252),(424,328),(390,393)],
         [(145,260),(200,335),(175,400)], [(175,252),(160,350),(170,450)]),
        ([(365,260),(313,354),(280,455)], [(395,252),(442,342),(470,450)],
         [(145,260),(210,324),(230,455)], [(175,252),(115,320),(90,450)]),
        ([(365,260),(409,327),(373,397)], [(395,252),(395,350),(395,450)],
         [(145,260),(133,350),(145,455)], [(175,252),(225,325),(210,390)]),
    )
    nf, ff, nh, fh = phases[phase]
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="600" height="600" viewBox="0 0 600 600">'
            '<rect width="600" height="600" fill="white"/>'
            '<g font-family="DejaVu Sans" fill="#1b2330">'
            f'<text x="20" y="35" font-size="21">Four-legged gait / phase {phase}</text>'
            '<path d="M30 468H570" stroke="#9ba9ba" stroke-width="2"/>'
            + limb(ff, '#e08020') + limb(fh, '#e08020') +
            '<ellipse cx="265" cy="225" rx="145" ry="62" fill="#d5dce5" stroke="#586879" stroke-width="3"/>'
            '<path d="M352 203L385 117L422 95L450 129L416 186L407 258" fill="#d5dce5" stroke="#586879" stroke-width="3"/>'
            '<path d="M418 91L490 110L517 143L476 161L433 142Z" fill="#d5dce5" stroke="#586879" stroke-width="3"/>'
            + limb(nf, '#147dc1') + limb(nh, '#147dc1') +
            '<text x="20" y="520" font-size="18">BLUE = both near limbs</text>'
            '<text x="20" y="550" font-size="18">ORANGE = both far limbs</text>'
            '<text x="20" y="580" font-size="18">Pose guide only; original art supplies identity</text></g></svg>')


def near_arm_punch():
    """Authoring reference for a near/right punch with far/left weapon support."""
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="600" height="600" viewBox="0 0 600 600">'
            '<rect width="600" height="600" fill="white"/>'
            '<g font-family="DejaVu Sans" fill="#1b2330">'
            '<text x="20" y="35" font-size="21">Near RIGHT punch / far LEFT supports</text>'
            '<path d="M30 498H570" stroke="#9ba9ba" stroke-width="2"/>'
            '<path d="M230 326L206 409L156 488 M280 326L322 413L351 488" stroke="#586879" stroke-width="30" fill="none" stroke-linecap="round"/>'
            '<path d="M214 193L284 195L295 322L267 346L218 327Z" fill="#d5dce5" stroke="#586879" stroke-width="3"/>'
            '<ellipse cx="265" cy="144" rx="35" ry="41" fill="#d5dce5" stroke="#586879" stroke-width="3"/>'
            '<path d="M297 135L316 152L296 155" fill="#d5dce5" stroke="#586879" stroke-width="3"/>'
            '<path d="M280 211L307 276L336 304" stroke="#e08020" stroke-width="25" fill="none" stroke-linecap="round" stroke-linejoin="round"/>'
            '<path d="M248 299L445 314L443 340L246 326Z" fill="#bfc9d3" stroke="#586879" stroke-width="3"/>'
            '<circle cx="337" cy="318" r="13" fill="#e08020"/>'
            '<path d="M226 212L316 222L436 217" stroke="#147dc1" stroke-width="29" fill="none" stroke-linecap="round" stroke-linejoin="round"/>'
            '<circle cx="226" cy="212" r="10" fill="white" stroke="#147dc1" stroke-width="5"/>'
            '<circle cx="316" cy="222" r="9" fill="white" stroke="#147dc1" stroke-width="5"/>'
            '<circle cx="443" cy="216" r="19" fill="#147dc1"/>'
            '<text x="20" y="535" font-size="18">BLUE = near RIGHT arm across chest</text>'
            '<text x="20" y="563" font-size="18">ORANGE = far LEFT arm under weapon</text>'
            '<text x="20" y="590" font-size="17">Authoring only / face and body point RIGHT</text></g></svg>')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--png', action='store_true', help='Also rasterize the reference diagram with ImageMagick')
    parser.add_argument('--phase', type=int, choices=range(4), help='One diagram as the primary edit target')
    parser.add_argument('--body', choices=['biped', 'quadruped'], default='biped')
    parser.add_argument('--action', choices=['walk', 'near-arm-punch'], default='walk')
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    if args.action == 'near-arm-punch':
        if args.body != 'biped' or args.phase is not None:
            parser.error('Near-arm punch uses a biped without --phase')
        svg = args.output / 'biped-near-arm-punch.svg'
        svg.write_text(near_arm_punch())
        if args.png:
            subprocess.run(['convert', '-background', 'white', str(svg), str(svg.with_suffix('.png'))], check=True)
        print(svg)
        return
    if args.body == 'quadruped' and args.phase is None:
        parser.error('A quadruped guide requires one --phase')
    name = f'{args.body}-walk-guide' if args.phase is None else f'{args.body}-walk-phase-{args.phase}'
    svg = args.output / (name+'.svg')
    svg.write_text(guide(args.phase) if args.body == 'biped' else quadruped(args.phase))
    if args.png:
        subprocess.run(['convert', '-background', 'white', str(svg), str(svg.with_suffix('.png'))], check=True)
    print(svg)


if __name__ == '__main__':
    main()
