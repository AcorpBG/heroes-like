"""Record exact immutable imagegen guide attempts; no acceptance by generation."""
import json
import hashlib
from pathlib import Path

ROOT=next(x for x in Path(__file__).resolve().parents if (x/'project.godot').exists())
HERE=Path(__file__).resolve().parent
INITIAL=HERE.parent/'move_h3_v1/guide_1_rgba.png'
def record(path):return {'path':path.relative_to(ROOT).as_posix(),'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
for version in range(1,5):
    name=f'opposed_attempt_v{version}'
    image=HERE/(name+'.png');prompt=HERE/(name+'.prompt.txt')
    reference=INITIAL if version<3 else HERE/'opposed_attempt_v2.png'
    note={1:'Rejected: repeats initial same-leg arrangement.',2:'Opposite visible knee arrangement but soft diffuse background glow; rejected as a guide.',3:'Background-removal edit retained diffuse glow and changed framing; rejected.',4:'Flat green cleanup of attempt2; pending anatomical scale registration and enlarged/native guide review, not accepted.'}[version]
    data={'provider':'built-in image_gen.imagegen','image':record(image),'prompt':record(prompt),'reference':record(reference),'transparent_background_requested':version<4,'status':'rejected' if version<4 else 'pending','review_note':note}
    (HERE/(name+'.generation.json')).write_text(json.dumps(data,indent=2)+'\n',encoding='utf-8')
