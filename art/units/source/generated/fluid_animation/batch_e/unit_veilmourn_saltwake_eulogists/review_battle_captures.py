"""Unscaled crops from all actual battle captures after whole-board inspection."""
import argparse,math
from pathlib import Path
from PIL import Image,ImageDraw
a=argparse.ArgumentParser();a.add_argument('directory',type=Path);args=a.parse_args();files=sorted(args.directory.glob('battle-phase-*.png'))
assert len(files)==8,len(files)
sheet=Image.new('RGB',(1000,math.ceil(len(files)/2)*205),(25,30,25));d=ImageDraw.Draw(sheet)
for i,f in enumerate(files):
 crop=Image.open(f).crop((350,210,850,395));x=i%2*500;y=i//2*205;sheet.paste(crop,(x,y+20));d.text((x+4,y+3),f.name,fill='white')
sheet.save(args.directory/'battle_unscaled.png');print('REVIEW_ALL_ACTUAL_CAPTURES',len(files))
