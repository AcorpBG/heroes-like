"""CPU pages of all source poses at the actual128-reference battle scale."""
import argparse,json
from PIL import Image,ImageDraw,ImageOps
import produce as p
if __name__=='__main__':
 a=argparse.ArgumentParser();a.add_argument('take');args=a.parse_args();d=p.SOURCE_DIR/args.take;c=json.loads((d/'config.json').read_bytes());m=json.loads((d/'matte.json').read_bytes());target=p.ROOT/'.artifacts/parallel_animation_20261002'/c['unit_id']/args.take;target.mkdir(exist_ok=True)
 for facing in ['normal','reflected']:
  for page in range(8):
   sheet=Image.new('RGB',(960,768),(31,40,32));draw=ImageDraw.Draw(sheet)
   for j,i in enumerate(range(page*16,min(124,(page+1)*16))):
    im=Image.open(d/m['matte_directory']/f'rgba_{i:03}.png').convert('RGBA');assert im.size==tuple(c['canvas'])
    # Source960x640 -> runtime fixed .5 -> reference128/256; one fixed .25
    # scale for every phase. Reflection affects drawing only, not source pixels.
    im=im.resize((round(im.width*c['scale']*.5),round(im.height*c['scale']*.5)),Image.Resampling.LANCZOS)
    if facing=='reflected':im=ImageOps.mirror(im)
    x,y=j%4*240,j//4*192
    if j%2:sheet.paste((218,211,193),(x,y,x+240,y+192))
    sheet.paste(im,(x,y+25),im);draw.text((x+5,y+5),f'{i} {facing}',fill=(160,110,65))
   sheet.save(target/f'source_native_{facing}_{page}.png')
 print('Native128 reference pages:',args.take,124,'poses per facing')
