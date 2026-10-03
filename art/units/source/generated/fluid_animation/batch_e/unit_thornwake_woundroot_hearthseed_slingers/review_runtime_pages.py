"""Split tall actual Godot native phase output into unchanged-size review pages."""
import argparse
from pathlib import Path
from PIL import Image
a=argparse.ArgumentParser();a.add_argument('overview',type=Path);args=a.parse_args()
im=Image.open(args.overview).convert('RGB');assert (im.height-35)%190==0
rows=(im.height-35)//190
for start in range(0,rows,6):
 count=min(6,rows-start);page=Image.new('RGB',(im.width,35+count*190))
 page.paste(im.crop((0,0,im.width,35)),(0,0))
 page.paste(im.crop((0,35+start*190,im.width,35+(start+count)*190)),(0,35))
 page.save(args.overview.with_name(args.overview.stem+f'-page-{start//6}.png'))
print(rows,'native rows;',((rows+5)//6),'pages; original scale retained')
