"""Register reciprocal walking paintings without resampling existing approved art."""
import hashlib
import json
from pathlib import Path
from PIL import Image

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[6]
uid = HERE.name
sources = [
    ('move_v4', 'exec-7fcad160-b847-448c-8dd9-0a4606c299ba.png', 'idle_v2.png'),
    ('move_v5', 'exec-29cae9a1-96a8-4fd4-a535-620c0025a0c2.png', 'move_v4.png'),
    ('move_v6', 'exec-b6475038-8ca7-4ff8-a0ba-8d418dd6db7e.png', 'move_v5.png'),
    ('move_v7', 'exec-8f61b549-4451-4e78-90bb-7e7a4d90d9d0.png', 'move_v6.png'),
]
entry = dict(unit_id=uid, reference_height=256, source_facing='right',
             frames=[], clips={}, source_scale_by_image={},
             source_scale_reason='Fixed 0.66 scale preserves the same helmet and boiler size as reviewed idle_v2; no per-frame resizing.',
             provenance=dict(tool='builtin_image_gen', sources=[]))
for stem, output, reference in sources:
    src = HERE / (stem + '.png')
    prompt = HERE / (stem + '.prompt.txt')
    entry['provenance']['sources'].append(dict(
        image=src.relative_to(ROOT).as_posix(), sha256=hashlib.sha256(src.read_bytes()).hexdigest(),
        prompt=prompt.relative_to(ROOT).as_posix(), prompt_sha256=hashlib.sha256(prompt.read_bytes()).hexdigest(),
        reference=(HERE / reference).relative_to(ROOT).as_posix(),
        supporting_references=[(HERE / 'move_v4.png').relative_to(ROOT).as_posix()] if stem == 'move_v7' else [],
        generation_output='C:/Users/acorp/.codex/generated_images/01a0965d-a98e-7560-8e9d-802269b3760b/' + output))
# Source cells are registered by pelvis and common floor, not bounding-box centre.
phases = [('move_v6', 0), ('move_v4', 2), ('move_v7', 2), ('move_v6', 7),
          ('move_v6', 4), ('move_v6', 5), ('move_v6', 6), ('move_v6', 3)]
for index, (stem, cell) in enumerate(phases):
    src = HERE / (stem + '.png')
    w, h = Image.open(src).size
    col, row = cell % 4, cell // 4
    rect = [round(w*col/4), round(h*row/2), round(w*(col+1)/4), round(h*(row+1)/2)]
    path = src.relative_to(ROOT).as_posix()
    entry['source_scale_by_image'][path] = .66
    entry['frames'].append(dict(name=f'move_{index}', clip='move', source=path,
                               rects=[rect], anchor=[238 + round(w*col/4), 408 if row == 0 else 831],
                               scale=.66, alpha_noise_cutoff=8))
entry['clips']['move'] = dict(indices=list(range(8)), frame_msec=100, loop=True,
    painted_phase_order=['far contact', 'far support / near heel lifted', 'near knee forward',
                         'near reach', 'near contact', 'near support / far heel lifted',
                         'far knee forward', 'far reach'])
entry['visual_review'] = dict(status='pending', notes='Opposed contacts and articulated passing/reaching poses; native review required.')
(HERE / 'move_handoff.json').write_text(json.dumps(dict(schema_version=1, units=[entry]), indent=2) + '\n', encoding='utf-8')
