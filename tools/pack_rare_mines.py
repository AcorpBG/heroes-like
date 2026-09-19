"""Register the six original rare-mine paintings and detached machinery.

Uses the same transparent canvas, ground anchor and scale as the common mines.
Source art and full generation prompts live beside the source layers.
"""
from pack_unified_mines import ROOT, pack_mines


def wheel(center, size, speed=1.1):
    return {'crop': [1155, 0, 1536, 570], 'center': center, 'size': size,
            'mode': 1, 'speed': speed}


def lift(center, size, rope=None, travel=42):
    result = {'crop': [1155, 570, 1536, 1024], 'center': center, 'size': size,
              'mode': 2, 'speed': .8, 'travel': [0, travel]}
    if rope is not None:
        result['rope'] = rope
    return result


SPECS = {
    'aetherglass': {
        'chimney': [249, 85], 'lights': [[368, 655], [628, 690]],
        'parts': [wheel([254, 650], [140, 210]),
                  lift([1100, 645], [120, 150], [1098, 515])],
    },
    'embergrain': {
        'chimney': [272, 62], 'lights': [[588, 742], [850, 704]],
        'parts': [wheel([232, 520], [145, 210], -.9),
                  lift([1115, 560], [130, 140], [1120, 447])],
    },
    'peatwax': {
        'file': 'peatwax-layers-transparent.png',
        'chimney': [902, 81], 'lights': [[440, 678], [679, 710], [856, 726]],
        'parts': [wheel([246, 526], [160, 225]),
                  lift([1110, 665], [100, 130], [1100, 472])],
    },
    'verdant_grafts': {
        'chimney': [264, 82], 'lights': [[390, 636], [618, 708]],
        'parts': [wheel([1044, 522], [110, 160], .85),
                  lift([917, 790], [135, 140], [919, 696], 30)],
    },
    'brass_scrip': {
        'chimney': [232, 67], 'lights': [[373, 615], [674, 652], [163, 693]],
        'parts': [wheel([1040, 652], [110, 160], -1.2),
                  lift([893, 697], [105, 165], travel=25)],
    },
    'memory_salt': {
        'chimney': [368, 71], 'lights': [[369, 655], [662, 699]],
        'parts': [wheel([225, 631], [135, 200]),
                  lift([1073, 647], [110, 145], [1074, 526])],
    },
}
for resource, spec in SPECS.items():
    boundary = 1190 if resource == 'brass_scrip' else 1155
    spec['building_crop'] = [0, 0, boundary, 1024]
    for part in spec['parts']:
        part['crop'][0] = boundary


if __name__ == '__main__':
    pack_mines(SPECS, ROOT / 'art/overworld/source/generated/mines/rare_20260920',
               ROOT / 'art/overworld/rare_mines.json', 'unified_rare_mines_v1', 'mapobj_rare')
