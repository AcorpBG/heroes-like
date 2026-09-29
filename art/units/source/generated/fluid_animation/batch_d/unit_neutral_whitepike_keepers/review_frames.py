"""Rebuild disposable chronological/contact previews from preserved originals."""
import argparse
import json
import av
from PIL import Image, ImageDraw
import produce as p

if __name__=='__main__':
 parser=argparse.ArgumentParser();parser.add_argument('take');parser.add_argument('--frames',type=int,nargs='*');parser.add_argument('--raw',action='store_true');args=parser.parse_args()
 out=p.SOURCE_DIR/args.take;config=json.loads((out/'config.json').read_bytes())
 selected=args.frames if args.frames else list(range(124));images={}
 if args.raw:
  with av.open(str(out/'original_lossless.mkv')) as video:
   for i,f in enumerate(video.decode(video=0)):
    if i in selected:images[i]=f.to_image().convert('RGB')
 else:
  for i in selected:images[i]=Image.open(out/'matte'/f'rgba_{i:03}.png').convert('RGBA')
 # Use one common crop across the sequence, so posture changes retain scale.
 if args.raw:crop=(80,80,900,640)
 else:
  boxes=[im.getbbox() for im in images.values()];crop=(max(0,min(b[0] for b in boxes)-12),max(0,min(b[1] for b in boxes)-12),min(960,max(b[2] for b in boxes)+12),min(640,max(b[3] for b in boxes)+12))
 target=p.ROOT/'.artifacts/whitepike_h3'/args.take;target.mkdir(parents=True,exist_ok=True)
 cols,rows=(4,4) if args.frames else (6,7);cellw,cellh=(400,400) if args.frames else (266,250)
 for start in range(0,len(selected),cols*rows):
  sheet=Image.new('RGB',(cols*cellw,rows*cellh),(39,47,37));d=ImageDraw.Draw(sheet)
  for j,i in enumerate(selected[start:start+cols*rows]):
   x,y=j%cols*cellw,j//cols*cellh
   if j%2:sheet.paste((218,211,193),(x,y,x+cellw,y+cellh))
   im=images[i].crop(crop);im.thumbnail((cellw-8,cellh-28),Image.Resampling.LANCZOS)
   sheet.paste(im,(x+(cellw-im.width)//2,y+24),im if im.mode=='RGBA' else None);d.text((x+4,y+4),str(i),fill=(169,105,50))
  sheet.save(target/('%s_%s_%s.png'%('raw' if args.raw else 'detail','selected' if args.frames else 'all',start)))
