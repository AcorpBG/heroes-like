"""Exact enlarged original RGB and alpha crops for every H3 companion frame."""
from pathlib import Path
import json,sys,hashlib
import av
from PIL import Image,ImageDraw
R=next(p for p in Path(__file__).resolve().parents if (p/'project.godot').exists());S=Path(__file__).parent;take=sys.argv[1];T=S/take;O=R/'.artifacts/parallel_animation_20261002/middle53_completion_audit/cliffhawk-correction'/take;O.mkdir(parents=True,exist_ok=True)
record=json.loads((T/'original.json').read_bytes());matte=json.loads((T/'matte.json').read_bytes());assert hashlib.sha256((T/'original_lossless.mkv').read_bytes()).hexdigest()==record['sha256']
with av.open(str(T/'original_lossless.mkv')) as video:raw=[f.to_image().convert('RGB') for f in video.decode(video=0)]
assert [hashlib.sha256(im.tobytes()).hexdigest() for im in raw]==record['decoded_rgb_sha256'];assert len(raw)==124
frames=[];boxes=[]
for i,rgb in enumerate(raw):
 p=T/matte.get('matte_directory','matte')/f'rgba_{i:03}.png';assert hashlib.sha256(p.read_bytes()).hexdigest()==matte['rgba_sha256'][i];rgba=Image.open(p).convert('RGBA');box=rgba.getchannel('A').point(lambda a:255 if a>=8 else 0).getbbox();assert box;boxes.append(box)
 assert box[2]-box[0]<=240 and box[3]-box[1]<=224,(i,'scale or foreign foreground exceeds original bird envelope',box)
 x=max(0,min(960-256,(box[0]+box[2])//2-128));y=max(0,min(544-240,(box[1]+box[3])//2-120));crop=(x,y,x+256,y+240)
 plate=Image.new('RGBA',rgba.size,(218,211,193,255) if i%2 else (24,30,24,255));plate.alpha_composite(rgba);frames.append((i,box,rgb.crop(crop),plate.convert('RGB').crop(crop)))
for start in range(0,124,15):
 chunk=frames[start:start+15];page=Image.new('RGB',(1536,35+264*((len(chunk)+2)//3)),(24,30,24));d=ImageDraw.Draw(page);d.text((4,4),take+' original RGB / alpha, exact source pixels; frame '+str(start)+'+',fill=(240,240,220))
 for j,(i,box,rgb,alpha) in enumerate(chunk):
  x=j%3*512;y=35+j//3*264;page.paste(rgb,(x,y));page.paste(alpha,(x+256,y));assert page.crop((x,y,x+256,y+240)).tobytes()==rgb.tobytes();d.text((x+4,y+241),str(i)+' bbox '+str(box)+' / original RGB | alpha',fill=(240,240,220))
 page.save(O/f'original-enlarged-{start//15}.png')
(T/'foreground_bounds.json').write_text(json.dumps(dict(bounds=boxes,safe_full_canvas=all(b[0]>16 and b[1]>16 and b[2]<944 and b[3]<528 for b in boxes),max_width=max(b[2]-b[0] for b in boxes),max_height=max(b[3]-b[1] for b in boxes)),indent=2)+'\n');print('EXACT_ALL_COMPANION_SOURCE_PAGES',take,len(frames),9,flush=True)
