"""Complete chronological soft-alpha review at actual 128px reference scale."""
import argparse,json
from PIL import Image,ImageDraw,ImageOps
import produce as p

def run(take):
 out=p.SOURCE_DIR/take;target=p.ROOT/'.artifacts/parallel_animation_20261002'/p.SOURCE_DIR.name/take;target.mkdir(parents=True,exist_ok=True)
 record=json.loads((out/('matte.json' if (out/'matte.json').exists() else 'failed_matte.json')).read_bytes())
 indices=[i for i,value in enumerate(record['rgba_sha256']) if value]
 for reflected in [False,True]:
  for page in range((len(indices)+15)//16):
   sheet=Image.new('RGB',(1024,800),(33,41,38));draw=ImageDraw.Draw(sheet)
   for local,i in enumerate(indices[page*16:(page+1)*16]):
    path=out/'matte'/f'rgba_{i:03}.png';assert p.sha(path)==record['rgba_sha256'][i]
    im=Image.open(path).convert('RGBA').resize((240,160),Image.Resampling.LANCZOS)
    if reflected:im=ImageOps.mirror(im)
    x=local%4*256;y=local//4*200
    if local%2:sheet.paste((221,214,197),(x,y,x+256,y+200))
    sheet.paste(im,(x+8,y+28),im);draw.text((x+8,y+6),str(i),fill=(173,119,72))
   sheet.save(target/f'complete_native_{int(reflected)}_{page}.png')
 print('COMPLETE_NATIVE_ALPHA_REVIEW',take,len(indices),'frames per facing',flush=True)

if __name__=='__main__':
 parser=argparse.ArgumentParser();parser.add_argument('takes',nargs='+');args=parser.parse_args()
 for take in args.takes:run(take)
