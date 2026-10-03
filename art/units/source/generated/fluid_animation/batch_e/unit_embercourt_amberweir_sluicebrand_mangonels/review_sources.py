"""CPU chronological original-RGB review and enlarged untouched-alpha comparisons."""
import argparse,json
from pathlib import Path
import av
from PIL import Image,ImageDraw
import produce as p

def run(take,indices):
 out=p.SOURCE_DIR/take;target=p.ROOT/'.artifacts/parallel_animation_20261002'/p.SOURCE_DIR.name/take;target.mkdir(parents=True,exist_ok=True)
 mattes=[Image.open(out/'matte_v3'/f'rgba_{i:03}.png').convert('RGBA') for i in range(124)]
 bounds=[im.getbbox() for im in mattes];crop=(max(0,min(b[0] for b in bounds)-8),max(0,min(b[1] for b in bounds)-8),min(960,max(b[2] for b in bounds)+8),min(544,max(b[3] for b in bounds)+8))
 with av.open(str(out/'original_lossless.mkv')) as v:originals=[f.to_image().convert('RGB') for f in v.decode(video=0)]
 assert len(originals)==124
 for part in range(2):
  sheet=Image.new('RGB',(1600,1760),(26,32,28));d=ImageDraw.Draw(sheet)
  for j,i in enumerate(range(part*62,(part+1)*62)):
   x,y=j%8*200,j//8*220;im=originals[i].crop(crop);im.thumbnail((196,195));sheet.paste(im,(x+(200-im.width)//2,y+22));d.text((x+5,y+4),str(i),fill=(225,220,210))
  sheet.save(target/f'original_chronological_{part}.png')
 for i in indices:
  sheet=Image.new('RGB',(1920,1088),(28,42,30));d=ImageDraw.Draw(sheet)
  sheet.paste(originals[i],(0,0));sheet.paste(mattes[i],(960,0),mattes[i]);sheet.paste((224,218,204),(0,544,960,1088));sheet.paste(mattes[i],(0,544),mattes[i]);sheet.paste((22,25,30),(960,544,1920,1088));sheet.paste(mattes[i],(960,544),mattes[i]);d.text((5,5),f'{take} original RGB / original semantic alpha plus palette processing, frame {i}',fill='white');sheet.save(target/f'enlarged_{i:03}.png')
 print('CPU_REVIEW_PAGES',take,indices,flush=True)
if __name__=='__main__':
 a=argparse.ArgumentParser();a.add_argument('take');a.add_argument('indices',type=int,nargs='*');args=a.parse_args();run(args.take,args.indices)
