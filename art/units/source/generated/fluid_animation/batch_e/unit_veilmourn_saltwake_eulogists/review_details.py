"""Review selected original details without re-rendering or source changes."""
import argparse
from PIL import Image,ImageDraw
import av
import produce as p
if __name__=='__main__':
 a=argparse.ArgumentParser();a.add_argument('take');a.add_argument('indices',nargs='+',type=int);args=a.parse_args()
 out=p.SOURCE_DIR/args.take;frames={i:f.to_image().convert('RGB') for i,f in enumerate(av.open(str(out/'original_lossless.mkv')).decode(video=0)) if i in args.indices}
 target=p.ROOT/'.artifacts/parallel_animation_20261002/unit_veilmourn_saltwake_eulogists'/args.take;target.mkdir(parents=True,exist_ok=True)
 sheet=Image.new('RGB',(960,((len(args.indices)+2)//3)*540),(30,30,35));draw=ImageDraw.Draw(sheet)
 for j,i in enumerate(args.indices):
  # Common guide envelope shows complete original anatomy and equipment.
  im=frames[i].crop((220,130,760,638));im.thumbnail((320,500),Image.Resampling.LANCZOS);x=j%3*320;y=j//3*540;sheet.paste(im,(x,y+28));draw.text((x+4,y+4),str(i),fill='white')
 sheet.save(target/'enlarged_details.png')
