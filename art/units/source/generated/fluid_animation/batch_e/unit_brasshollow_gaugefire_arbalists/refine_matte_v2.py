"""Edge despill on original RGB with the unchanged reviewed semantic alpha.

The first semantic unmix over-subtracted saturated plates and created their
complementary edge colors. Retain that reproducible trial and all source RGB;
this revision uses original RGB and a bounded two-pixel edge-only despill.
No mask erosion, invented anatomy, stabilization or motion processing.
"""
import argparse,hashlib,json
from pathlib import Path
import av,numpy as np
from PIL import Image,ImageDraw
from scipy.ndimage import distance_transform_edt
import produce as p
def read(f):return json.loads(f.read_bytes())
def run(take):
 out=p.SOURCE_DIR/take;original=read(out/'original.json');trial=read(out/'matte.json')
 target=out/'matte_v2';target.mkdir(exist_ok=True);hashes=[];details=[]
 with av.open(str(out/'original_lossless.mkv')) as video:
  for i,f in enumerate(video.decode(video=0)):
   rgb=np.asarray(f.to_image().convert('RGB')).astype(np.float32)
   assert hashlib.sha256(rgb.astype('uint8').tobytes()).hexdigest()==original['decoded_rgb_sha256'][i]
   old=out/'matte'/f'rgba_{i:03}.png';assert p.sha(old)==trial['rgba_sha256'][i]
   alpha=np.asarray(Image.open(old).convert('RGBA'))[:,:,3]
   bg=np.array(trial['background_frames'][i]['background_rgb'])
   axes={'magenta':min(bg[0],bg[2])-bg[1],'yellow':min(bg[0],bg[1])-bg[2],'green':bg[1]-max(bg[0],bg[2]),'blue':bg[2]-max(bg[0],bg[1])}
   axis=max(axes,key=axes.get);assert axes[axis]>=80,(i,bg)
   edge=(distance_transform_edt(alpha>=250)<=2)&(alpha>=8)
   color=rgb.copy()
   if axis=='magenta':
    spill=np.maximum(np.minimum(color[:,:,0],color[:,:,2])-color[:,:,1],0)*edge
    color[:,:,0]-=spill;color[:,:,2]-=spill
   elif axis=='green':color[:,:,1]-=np.maximum(color[:,:,1]-np.maximum(color[:,:,0],color[:,:,2]),0)*edge
   elif axis=='blue':color[:,:,2]-=np.maximum(color[:,:,2]-np.maximum(color[:,:,0],color[:,:,1]),0)*edge
   else:
    # Original warm brass has a red-over-green band; protect that legitimate
    # material while neutralizing the nearly equal R/G saturated yellow plate.
    strength=np.clip((12-(color[:,:,0]-color[:,:,1]))/12,0,1)
    spill=np.maximum(np.minimum(color[:,:,0],color[:,:,1])-color[:,:,2],0)*edge*strength
    color[:,:,0]-=spill;color[:,:,1]-=spill
   rgba=np.dstack([color,alpha]).astype('uint8');rgba[alpha<8]=0
   path=target/f'rgba_{i:03}.png';Image.fromarray(rgba).save(path);hashes.append(p.sha(path))
   assert np.array_equal(rgba[:,:,3],alpha)
   opaque=(alpha==255)&~edge;assert np.array_equal(rgba[opaque,:3],rgb.astype('uint8')[opaque])
   details.append(dict(background_rgb=bg.tolist(),plate_axis=axis,edge_pixels=int(edge.sum())))
 recipe=dict(frames=124,fps=24,rgba_sha256=hashes,background_frames=details,semantic_trial_sha256=p.sha(out/'matte.json'),source_sha256=original['sha256'],tool_sha256=p.sha(Path(__file__)),recipe='Unchanged pinned semantic alpha. Original RGB retained outside two-source-pixel contour band; edge-only measured-plate despill. Magenta/green/blue removed only on their corresponding chroma axes; yellow despill protects red-over-green>=12 warm brass. No alpha geometry changes, no source coordinate changes, no articulation synthesis.')
 p.write(out/'matte_v2.json',recipe)
 # Reuse chronological overview spacing while explicitly selecting v2 files.
 directory=p.ROOT/'.artifacts/parallel_animation_20261002'/p.SOURCE_DIR.name/take;directory.mkdir(parents=True,exist_ok=True)
 bounds=[Image.open(target/f'rgba_{i:03}.png').getbbox() for i in range(124)]
 crop=(min(b[0] for b in bounds)-8,min(b[1] for b in bounds)-8,max(b[2] for b in bounds)+8,max(b[3] for b in bounds)+8)
 for part in range(2):
  sheet=Image.new('RGB',(1600,1760),(30,40,30));d=ImageDraw.Draw(sheet)
  for j,i in enumerate(range(part*62,(part+1)*62)):
   x,y=j%8*200,j//8*220
   if j%2:sheet.paste((218,211,193),(x,y,x+200,y+220))
   im=Image.open(target/f'rgba_{i:03}.png').crop(crop);im.thumbnail((196,195));sheet.paste(im,(x+(200-im.width)//2,y+22),im);d.text((x+5,y+4),str(i),fill=(160,110,65))
  sheet.save(directory/f'chronological_v2_{part}.png')
 print('REFINED_UNCHANGED_ALPHA',take,124,flush=True)
if __name__=='__main__':
 parser=argparse.ArgumentParser();parser.add_argument('takes',nargs='+');args=parser.parse_args()
 for take in args.takes:run(take)
