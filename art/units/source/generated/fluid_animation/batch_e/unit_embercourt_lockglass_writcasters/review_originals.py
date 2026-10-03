"""Rebuild temporary chronological raw/native/mirrored pages without altering source."""
import argparse,json
from PIL import Image,ImageDraw,ImageOps
import av
import produce as p
A=p.ROOT/'.artifacts/parallel_animation_20261002'/p.SOURCE_DIR.name

def raw(take):
 out=p.SOURCE_DIR/take;c=json.loads((out/'config.json').read_bytes());crop=(200,120,920,630)
 images=[]
 with av.open(str(out/'original_lossless.mkv')) as video:
  for f in video.decode(video=0):images.append(f.to_image().convert('RGB'))
 assert len(images)==124
 for part in range(4):
  page=Image.new('RGB',(1800,1800),(30,35,35));d=ImageDraw.Draw(page)
  for j,i in enumerate(range(part*32,min(124,(part+1)*32))):
   im=images[i].crop(crop);im.thumbnail((220,210));x=j%8*225;y=j//8*450;page.paste(im,(x,y+24));d.text((x+4,y+4),str(i),fill='white')
  (A/take).mkdir(parents=True,exist_ok=True);page.save(A/take/f'raw_chronological_{part}.png')

def native(take):
 out=p.SOURCE_DIR/take;c=json.loads((out/'config.json').read_bytes());indices=json.loads((out/'selection.json').read_bytes())['source_frames'];scale=c['scale']*128/256
 for mirrored in [False,True]:
  for background_phase in [0,1]:
   for part in range((len(indices)+47)//48):
    page=Image.new('RGB',(1800,1200),(30,35,35));d=ImageDraw.Draw(page)
    for j,i in enumerate(indices[part*48:(part+1)*48]):
     im=Image.open(out/'matte'/f'rgba_{i:03}.png');im=im.resize((round(im.width*scale),round(im.height*scale)),Image.Resampling.LANCZOS)
     if mirrored:im=ImageOps.mirror(im)
     x=j%8*225;y=j//8*200
     if (j+background_phase)%2:page.paste((225,215,202),(x,y,x+225,y+200))
     page.paste(im,(x+112-round(im.width/2),y+175-round(c['anchor'][1]*scale)),im);d.text((x+4,y+4),str(i),fill=(150,95,55));d.line((x,y+175,x+225,y+175),fill=(90,110,80))
    page.save(A/take/f'native_{"mirrored" if mirrored else "right"}_{part}{"_opposite" if background_phase else ""}.png')

def enlarged(take,indices):
 out=p.SOURCE_DIR/take;images=[Image.open(out/'matte'/f'rgba_{i:03}.png').convert('RGBA') for i in indices]
 bounds=[im.getbbox() for im in images];assert all(bounds)
 crop=(max(0,min(b[0] for b in bounds)-12),max(0,min(b[1] for b in bounds)-12),min(images[0].width,max(b[2] for b in bounds)+12),min(images[0].height,max(b[3] for b in bounds)+12))
 (A/take).mkdir(parents=True,exist_ok=True)
 for part in range((len(indices)+3)//4):
  page=Image.new('RGB',(1200,1280),(30,35,35));d=ImageDraw.Draw(page)
  for j,(i,im) in enumerate(zip(indices[part*4:(part+1)*4],images[part*4:(part+1)*4])):
   x=j%2*600;y=j//2*640
   if j%2:page.paste((225,215,202),(x,y,x+600,y+640))
   im=im.crop(crop);im.thumbnail((580,600),Image.Resampling.LANCZOS);page.paste(im,(x+(600-im.width)//2,y+30),im)
   d.text((x+5,y+5),str(i),fill=(150,95,55))
  page.save(A/take/f'enlarged_matte_{part}.png')

def raw_enlarged(take,indices):
 out=p.SOURCE_DIR/take;images={}
 with av.open(str(out/'original_lossless.mkv')) as video:
  for i,frame in enumerate(video.decode(video=0)):
   if i in indices:images[i]=frame.to_image().convert('RGB')
 assert set(images)==set(indices)
 (A/take).mkdir(parents=True,exist_ok=True)
 for part in range((len(indices)+3)//4):
  page=Image.new('RGB',(1520,1312),(30,35,35));d=ImageDraw.Draw(page)
  for j,i in enumerate(indices[part*4:(part+1)*4]):
   # Fixed full-height crop includes the raised rifle and complete boots/tag.
   im=images[i].crop((180,0,940,640));x=j%2*760;y=j//2*656
   page.paste(im,(x,y+16));d.text((x+5,y+2),str(i),fill='white')
  page.save(A/take/f'enlarged_raw_{part}.png')

if __name__=='__main__':
 parser=argparse.ArgumentParser();parser.add_argument('verb',choices=['raw','native','enlarged','raw_enlarged']);parser.add_argument('take');parser.add_argument('--frames',default='0,24,48,64,78,96,112,123');a=parser.parse_args()
 if a.verb=='enlarged':enlarged(a.take,[int(i) for i in a.frames.split(',')])
 elif a.verb=='raw_enlarged':raw_enlarged(a.take,[int(i) for i in a.frames.split(',')])
 else:globals()[a.verb](a.take)
