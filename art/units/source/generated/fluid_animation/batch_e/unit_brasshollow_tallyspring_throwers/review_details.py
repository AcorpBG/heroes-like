import argparse,json,av
from PIL import Image,ImageDraw
import produce as p
if __name__=='__main__':
 a=argparse.ArgumentParser();a.add_argument('take');a.add_argument('indices',type=int,nargs='+');args=a.parse_args();d=p.SOURCE_DIR/args.take;folder=d/json.loads((d/'matte.json').read_bytes())['matte_directory'];dest=p.ROOT/'.artifacts/parallel_animation_20261002/unit_brasshollow_tallyspring_throwers'/args.take;dest.mkdir(exist_ok=True)
 with av.open(str(d/'original_lossless.mkv')) as v:raw=[f.to_image().convert('RGB') for f in v.decode(video=0)]
 for page in range((len(args.indices)+3)//4):
  ids=args.indices[page*4:(page+1)*4];bounds=[Image.open(folder/f'rgba_{i:03}.png').getbbox() for i in ids];crop=(min(b[0] for b in bounds)-8,min(b[1] for b in bounds)-8,max(b[2] for b in bounds)+8,max(b[3] for b in bounds)+8);w,h=crop[2]-crop[0],crop[3]-crop[1];sheet=Image.new('RGB',(w*4,(h+22)*2),(217,211,195));draw=ImageDraw.Draw(sheet)
  for j,i in enumerate(ids):
   x=j%2*w*2;y=j//2*(h+22);draw.text((x+4,y+3),str(i),fill='black');sheet.paste(raw[i].crop(crop),(x,y+22));im=Image.open(folder/f'rgba_{i:03}.png').crop(crop);sheet.paste(im,(x+w,y+22),im)
  sheet.save(dest/f'detail_{page}.png')
