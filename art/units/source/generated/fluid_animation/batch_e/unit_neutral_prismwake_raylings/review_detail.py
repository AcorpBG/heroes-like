"""Rebuildable full-canvas, original-scale anatomy review without clipped appendages."""
import argparse,av
from PIL import Image,ImageDraw,ImageOps
import produce as p

def run(take,indices,raw=False):
 out=p.SOURCE_DIR/take;target=p.ROOT/'.artifacts/parallel_animation_20261002'/p.SOURCE_DIR.name/take
 target.mkdir(parents=True,exist_ok=True)
 if raw:
  with av.open(str(out/'original_lossless.mkv')) as video:frames=[f.to_image().convert('RGB') for f in video.decode(video=0)]
  assert len(frames)==124
 else:
  frames={i:Image.open(out/'matte'/f'rgba_{i:03}.png').convert('RGBA') for i in indices}
 for reflected in ([False] if raw else [False,True]):
  for page in range((len(indices)+1)//2):
   sheet=Image.new('RGB',(1920,664),(221,214,197));draw=ImageDraw.Draw(sheet)
   for j,i in enumerate(indices[page*2:page*2+2]):
    im=frames[i];assert im.size==(960,640)
    if reflected:im=ImageOps.mirror(im)
    if raw:sheet.paste(im,(j*960,24))
    else:sheet.paste(im,(j*960,24),im)
    draw.text((j*960+8,6),f'{take} frame {i}',fill=(60,51,43))
   sheet.save(target/f'{"raw" if raw else "alpha"}_original_scale_{int(reflected)}_{page}.png')
 print('FULL_ORIGINAL_SCALE',take,indices,'RAW' if raw else 'ALPHA_BOTH_FACINGS',flush=True)

if __name__=='__main__':
 a=argparse.ArgumentParser();a.add_argument('take');a.add_argument('indices',nargs='+',type=int);a.add_argument('--raw',action='store_true');args=a.parse_args();run(args.take,args.indices,args.raw)
