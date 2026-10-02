"""Chronological source RGB reviews: no extraction or motion editing."""
import argparse,json
from PIL import Image,ImageDraw
import av,numpy as np
import produce as p
if __name__=='__main__':
 a=argparse.ArgumentParser();a.add_argument('takes',nargs='+');args=a.parse_args()
 for name in args.takes:
  out=p.SOURCE_DIR/name;target=p.ROOT/'.artifacts/parallel_animation_20261002/unit_veilmourn_saltwake_eulogists'/name;target.mkdir(parents=True,exist_ok=True)
  frames=[f.to_image().convert('RGB') for f in av.open(str(out/'original_lossless.mkv')).decode(video=0)];assert len(frames)==124
  bounds=[]
  for im in frames:
   a=np.asarray(im).astype(float);bg=np.median(a[:20,:20].reshape(-1,3),axis=0);mask=np.linalg.norm(a-bg,axis=2)>80;ys,xs=np.nonzero(mask);bounds.append((int(xs.min()),int(ys.min()),int(xs.max()+1),int(ys.max()+1)))
  crop=(max(0,min(b[0] for b in bounds)-24),max(0,min(b[1] for b in bounds)-24),min(frames[0].width,max(b[2] for b in bounds)+24),min(frames[0].height,max(b[3] for b in bounds)+24))
  for part in range(2):
   sheet=Image.new('RGB',(1600,1760),(35,35,40));d=ImageDraw.Draw(sheet)
   for j,i in enumerate(range(part*62,min((part+1)*62,124))):
    im=frames[i].crop(crop);im.thumbnail((196,192),Image.Resampling.LANCZOS);x=j%8*200;y=j//8*220;sheet.paste(im,(x+(200-im.width)//2,y+24));d.text((x+4,y+4),str(i),fill='white')
   sheet.save(target/f'original_rgb_{part}.png')
  print('Raw124 frame review ready',name)
