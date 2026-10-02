"""Split complete native overview PNGs into unscaled, readable review pages."""
import argparse
from pathlib import Path
from PIL import Image

def run(directory):
 for source in directory.glob('*-overview.png'):
  image=Image.open(source).convert('RGBA')
  # The focused fixture has a 35px heading followed by exact 190px rows.
  assert (image.height-35)%190==0
  top=0;part=0
  while top<image.height:
   # Four rows stay below the image viewer's pixel budget at original width.
   # Keep every native sprite pixel unscaled during personal acceptance.
   end=min(image.height,35+4*190 if part==0 else top+4*190)
   page=image.crop((0,top,image.width,end))
   page.save(directory/(source.stem+f'-native-page-{part}.png'))
   print(source.stem,part,[top,end],page.size)
   top=end;part+=1

if __name__=='__main__':
 parser=argparse.ArgumentParser();parser.add_argument('directory',type=Path)
 run(parser.parse_args().directory)
