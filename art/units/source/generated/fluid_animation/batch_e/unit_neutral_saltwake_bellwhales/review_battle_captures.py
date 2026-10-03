"""Present all actual battle capture regions without resizing sprite pixels."""
import argparse
from PIL import Image, ImageDraw
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('directory', type=Path)
args = parser.parse_args()
files = sorted(args.directory.glob('battle-phase-*.png'))
assert len(files) == 8, files
result = Image.new('RGB', (1760, 480), '#202b1a')
labels = ImageDraw.Draw(result)
for index, source in enumerate(files):
    x, y = index % 4 * 440, index // 4 * 240
    labels.text((x, y + 6), source.name, fill='white')
    result.paste(Image.open(source).crop((400, 210, 840, 420)), (x, y + 30))
result.save(args.directory / 'combat_review.png')
