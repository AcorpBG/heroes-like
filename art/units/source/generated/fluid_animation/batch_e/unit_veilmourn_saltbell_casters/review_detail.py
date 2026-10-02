"""Rebuildable CPU anatomy enlargements and unscaled 128px grounded sprite review."""
import argparse,json,av
from PIL import Image,ImageDraw,ImageOps
import produce as p

def run(take,indices,raw=False):
 out=p.SOURCE_DIR/take;target=p.ROOT/'.artifacts/parallel_animation_20261002'/p.SOURCE_DIR.name/take
 target.mkdir(parents=True,exist_ok=True)
 if raw:
  with av.open(str(out/'original_lossless.mkv')) as video:frames=[f.to_image().convert('RGB') for f in video.decode(video=0)]
  assert len(frames)==124
  box=(240,128,780,640);width=box[2]-box[0];height=box[3]-box[1]
  sheet=Image.new('RGB',(4*width,((len(indices)+3)//4)*(height+24)),(39,47,39));d=ImageDraw.Draw(sheet)
  for j,i in enumerate(indices):
   x=j%4*width;y=j//4*(height+24);sheet.paste(frames[i].crop(box),(x,y+24));d.text((x+6,y+5),str(i),fill='white')
  sheet.save(target/'raw_enlarged_details.png');print('ORIGINAL_DETAIL',take,indices);return
 record=json.loads((out/('matte.json' if (out/'matte.json').exists() else 'failed_matte.json')).read_bytes())
 available=[i for i,value in enumerate(record['rgba_sha256']) if value]
 for flip in [False,True]:
  for part in range((len(available)+61)//62):
   sheet=Image.new('RGB',(8*256,8*200),(39,47,39));d=ImageDraw.Draw(sheet)
   for j,i in enumerate(available[part*62:(part+1)*62]):
    im=Image.open(out/'matte'/f'rgba_{i:03}.png').convert('RGBA').resize((240,160),Image.Resampling.LANCZOS)
    if flip:im=ImageOps.mirror(im)
    x=j%8*256;y=j//8*200
    if j%2:sheet.paste((219,211,193),(x,y,x+256,y+200))
    sheet.paste(im,(x+8,y+26),im);d.text((x+6,y+5),str(i),fill=(160,110,65))
   sheet.save(target/f'native_all_{int(flip)}_{part}.png')
 bounds=[Image.open(out/'matte'/f'rgba_{i:03}.png').getbbox() for i in indices]
 box=(min(b[0] for b in bounds)-10,min(b[1] for b in bounds)-10,max(b[2] for b in bounds)+10,max(b[3] for b in bounds)+10)
 width=box[2]-box[0];height=box[3]-box[1]
 sheet=Image.new('RGB',(4*width,((len(indices)+3)//4)*(height+24)),(219,211,193));d=ImageDraw.Draw(sheet)
 for j,i in enumerate(indices):
  im=Image.open(out/'matte'/f'rgba_{i:03}.png').convert('RGBA').crop(box);x=j%4*width;y=j//4*(height+24)
  sheet.paste(im,(x,y+24),im);d.text((x+6,y+5),str(i),fill=(80,65,45))
 sheet.save(target/'enlarged_details.png')
 print('CPU_NATIVE_BOTH_FACINGS',take,len(available)*2,'DETAILS',indices)

if __name__=='__main__':
 a=argparse.ArgumentParser();a.add_argument('take');a.add_argument('indices',nargs='+',type=int);a.add_argument('--raw',action='store_true');args=a.parse_args();run(args.take,args.indices,args.raw)
