"""Enlarged original handler grips and beast anatomy, chronological CPU review."""
import argparse,json
from PIL import Image,ImageDraw
import av
import produce as p
UID='unit_mireclaw_moonbite_mirehorn_breakers'
def run(take,indices,matte=False):
 out=p.SOURCE_DIR/take;target=p.ROOT/'.artifacts/parallel_animation_20261002'/UID/take;target.mkdir(exist_ok=True)
 if matte:
  recipe=json.loads((out/'matte.json').read_bytes());raw=[]
  for i in range(124):
   f=out/'matte'/f'rgba_{i:03}.png';assert p.sha(f)==recipe['rgba_sha256'][i]
   rgba=Image.open(f).convert('RGBA');bg=Image.new('RGB',rgba.size,(218,211,193) if i%2 else (32,37,33));bg.paste(rgba,(0,0),rgba);raw.append(bg)
 else:raw=[f.to_image().convert('RGB') for f in av.open(str(out/'original_lossless.mkv')).decode(video=0)]
 for label,crop in [('grips',(50,260,470,640)),('beast',(280,120,850,630))]:
  for start in range(0,len(indices),20):
   selected=indices[start:start+20];sheet=Image.new('RGB',(1680,1900),(32,37,33));d=ImageDraw.Draw(sheet)
   for j,i in enumerate(selected):
    x=j%4*420;y=j//4*380
    im=raw[i].crop(crop);im.thumbnail((420,350),Image.Resampling.NEAREST);sheet.paste(im,(x,y+25));d.text((x+3,y+4),f'{take} {"alpha" if matte else "original RGB"} {i} {label}',fill=(240,170,80))
   sheet.save(target/f'trouble_{"alpha_" if matte else ""}{label}_{start//20}.png')
 print('ENLARGED_ORIGINAL_TROUBLE_READY',take,len(indices),flush=True)
if __name__=='__main__':
 a=argparse.ArgumentParser();a.add_argument('take');a.add_argument('--indices',nargs='+',type=int);a.add_argument('--matte',action='store_true');v=a.parse_args();run(v.take,v.indices or list(range(124)),v.matte)
