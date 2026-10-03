"""Full chronological original RGB/RGBA sheets; no source or motion changes."""
import argparse,json,hashlib
from PIL import Image,ImageDraw
import av
import produce as p
UID='unit_neutral_saltwake_bellwhales'
def run(take,rgb_only=False):
 out=p.SOURCE_DIR/take;target=p.ROOT/'.artifacts/parallel_animation_20261002'/UID/take;target.mkdir(parents=True,exist_ok=True)
 rec=json.loads((out/'original.json').read_bytes());raw=[f.to_image().convert('RGB') for f in av.open(str(out/'original_lossless.mkv')).decode(video=0)]
 assert len(raw)==124 and [hashlib.sha256(im.tobytes()).hexdigest() for im in raw]==rec['decoded_rgb_sha256']
 series=[('rgb',raw)]
 if not rgb_only:
  matte=json.loads((out/'matte.json').read_bytes());rgba=[]
  for i in range(124):
   if not matte['rgba_sha256'][i]:rgba.append(None);continue
   file=out/'matte'/f'rgba_{i:03}.png';assert p.sha(file)==matte['rgba_sha256'][i];rgba.append(Image.open(file).convert('RGBA'))
  series.append(('rgba',rgba))
 for kind,frames in series:
  for page in range(4):
   sheet=Image.new('RGB',(1536,2240),(33,38,38));d=ImageDraw.Draw(sheet)
   for j,i in enumerate(range(page*31,(page+1)*31)):
    x=j%4*384;y=j//4*280
    if kind=='rgba' and j%2:sheet.paste((210,200,185),(x,y,x+384,y+280))
    if frames[i] is None:d.text((x+4,y+4),f'{take} {i} excluded held plate',fill=(230,130,80));continue
    im=frames[i].resize((384,256),Image.Resampling.LANCZOS)
    sheet.paste(im,(x,y+24),im if kind=='rgba' else None);d.text((x+4,y+4),f'{take} {i}',fill=(230,130,80))
   sheet.save(target/f'{kind}_{page}.png')
 # Enlarged actual pixels, selected landmarks but also both earliest/latest seam.
 for kind,frames in series:
  available=[i for i,f in enumerate(frames) if f is not None]
  indices=sorted(set([i for i in [0,16,30,45,60,75,90,108,123] if i in available]+[available[-1]]));sheet=Image.new('RGB',(1920,2040),(30,35,35));d=ImageDraw.Draw(sheet)
  for j,i in enumerate(indices):
   x=j%3*640;y=j//3*680;im=frames[i].crop((80,0,880,640)).resize((640,512),Image.Resampling.NEAREST)
   sheet.paste(im,(x,y+28),im if kind=='rgba' else None);d.text((x+4,y+4),f'{take} {kind} {i}',fill='white')
  sheet.save(target/f'{kind}_details.png')
 print('SOURCE_REVIEW_READY',take,'124 original RGB',('and '+str(sum(im is not None for im in rgba))+' extracted alpha' if not rgb_only else 'only'),flush=True)
if __name__=='__main__':
 a=argparse.ArgumentParser();a.add_argument('takes',nargs='+');a.add_argument('--rgb-only',action='store_true');args=a.parse_args()
 for take in args.takes:run(take,args.rgb_only)
