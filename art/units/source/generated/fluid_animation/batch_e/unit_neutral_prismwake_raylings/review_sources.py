"""CPU review exports of the complete original canvas, never hidden cropped edges."""
import argparse,json
import av
from PIL import Image,ImageDraw
import produce as p

def run(take):
 out=p.SOURCE_DIR/take;target=p.ROOT/'.artifacts/parallel_animation_20261002'/p.SOURCE_DIR.name/take;target.mkdir(parents=True,exist_ok=True)
 with av.open(str(out/'original_lossless.mkv')) as video:originals=[f.to_image().convert('RGB') for f in video.decode(video=0)]
 assert len(originals)==124
 for part in range(8):
  sheet=Image.new('RGB',(4*240,4*184),(42,45,51));draw=ImageDraw.Draw(sheet)
  for j,i in enumerate(range(part*16,min((part+1)*16,124))):
   im=originals[i].resize((240,160),Image.Resampling.LANCZOS);x=j%4*240;y=j//4*184;sheet.paste(im,(x,y+24));draw.text((x+4,y+4),str(i),fill='white')
  sheet.save(target/f'full_original_{part}.png')
 print('FULL_CANVAS_REVIEW',take,124)

if __name__=='__main__':
 a=argparse.ArgumentParser();a.add_argument('takes',nargs='+');args=a.parse_args()
 for take in args.takes:run(take)
