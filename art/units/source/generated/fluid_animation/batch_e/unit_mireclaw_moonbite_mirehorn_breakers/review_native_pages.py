"""Crop tall actual-engine phase contacts into unscaled review pages."""
import argparse
from pathlib import Path
from PIL import Image
if __name__=='__main__':
 a=argparse.ArgumentParser();a.add_argument('directory',type=Path);args=a.parse_args();root=args.directory.resolve();target=root/'unscaled_pages';target.mkdir(exist_ok=True)
 for f in sorted(root.glob('unit_mireclaw_moonbite_mirehorn_breakers-*.png')):
  im=Image.open(f)
  for i,y in enumerate(range(0,im.height,1200)):
   im.crop((0,y,im.width,min(y+1200,im.height))).save(target/f'{f.stem}-{i}.png')
  print(f.name,im.size,'unscaled pages',i+1)
