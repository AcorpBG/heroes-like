"""Split native phase overview into row-aligned pages without resampling."""
from pathlib import Path
import sys
from PIL import Image

ROOT = next(p for p in Path(__file__).resolve().parents if (p / 'project.godot').exists())
out = Path(sys.argv[1]) if len(sys.argv)>1 else ROOT / '.artifacts/harbor_h3/candidate_runtime_direct'
source = Image.open(out / 'unit_neutral_harbor_polearms-overview.png')
for page, first in enumerate(range(0, 19, 4)):
    last = min(19, first + 4)
    view = Image.new(source.mode, (source.width, 35 + (last-first)*190))
    view.paste(source.crop((0, 0, source.width, 35)), (0, 0))
    view.paste(source.crop((0, 35+first*190, source.width, 35+last*190)), (0, 35))
    view.save(out / f'native-page-{page}.png')
