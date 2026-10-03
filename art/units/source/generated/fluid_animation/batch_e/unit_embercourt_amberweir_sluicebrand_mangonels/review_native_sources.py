"""CPU source previews at the game's fixed 128px reference height, both facings."""
import argparse,json
from pathlib import Path
from PIL import Image,ImageDraw,ImageOps
import produce as p
from integrate_fluid_creature_animation import source_pose

def run(take,indices):
 out=p.SOURCE_DIR/take;c=json.loads((out/'config.json').read_bytes())
 target=p.ROOT/'.artifacts/parallel_animation_20261002'/p.SOURCE_DIR.name/take;target.mkdir(parents=True,exist_ok=True)
 if not indices:
  selection=out/'selection.json';indices=json.loads(selection.read_bytes())['source_frames'] if selection.exists() else list(range(124))
 for reflected in [False,True]:
  for part,start in enumerate(range(0,len(indices),48)):
   poses=indices[start:start+48];sheet=Image.new('RGB',(1760,1080),(28,33,38));d=ImageDraw.Draw(sheet)
   for j,i in enumerate(poses):
    f=dict(name=str(i),source=(out/'matte_v3'/f'rgba_{i:03}.png').relative_to(p.ROOT).as_posix(),rects=[[0,0,*c['canvas']]],anchor=c['anchor'],scale=c['scale']*128/256)
    im,(x,y)=source_pose(f,0)
    if reflected:im=ImageOps.mirror(im);x=-x-im.width
    cell=Image.new('RGBA',(220,180),(231,225,212,255) if j%2 else (28,33,38,255))
    assert x+110>=0 and y+165>=0 and x+110+im.width<=220 and y+165+im.height<=180,(take,i,im.size,(x,y))
    cell.alpha_composite(im,(110+x,165+y));sheet.paste(cell.convert('RGB'),(j%8*220,j//8*180));d.text((j%8*220+5,j//8*180+5),str(i),fill='white')
   sheet.save(target/f'source_actual128_{"reflected" if reflected else "right"}_{part}.png')
 print('FIXED_128_SOURCE_REVIEW',take,len(indices),'poses in each facing',flush=True)
if __name__=='__main__':
 a=argparse.ArgumentParser();a.add_argument('take');a.add_argument('indices',type=int,nargs='*');args=a.parse_args();run(args.take,args.indices)
