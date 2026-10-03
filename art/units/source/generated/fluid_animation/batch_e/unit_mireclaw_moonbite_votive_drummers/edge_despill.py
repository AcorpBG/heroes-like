"""Remove non-costume chroma spill only in a two-source-pixel alpha boundary."""
import json,sys
import numpy as np
from PIL import Image
from scipy.ndimage import distance_transform_edt
import produce as p
def apply(im):
 a=np.array(im.convert('RGBA'));alpha=a[:,:,3].copy();color=a[:,:,:3].astype(np.float32)
 # Green is legitimate reed clothing and moss. Never despill green or opaque
 # RGB; only the absent magenta plate can be removed from soft edge pixels.
 edge=(distance_transform_edt(alpha<250)<=2)&(alpha<250)&(alpha>0)
 magenta=np.maximum(np.minimum(color[:,:,0],color[:,:,2])-color[:,:,1],0)*edge;color[:,:,0]-=magenta;color[:,:,2]-=magenta
 original=a[:,:,:3].copy()
 a[:,:,:3]=np.clip(color,0,255).astype(np.uint8);assert np.array_equal(a[:,:,3],alpha)
 assert np.array_equal(a[:,:,:3][alpha>=250],original[alpha>=250])
 return Image.fromarray(a)
def run(take):
 out=p.SOURCE_DIR/take;record=json.loads((out/'matte.json').read_bytes())
 if record.get('boundary_despill_source_pixels')==2:return
 if (out/'semantic_matte_initial.json').exists():
  initial=json.loads((out/'semantic_matte_initial.json').read_bytes());assert initial['rgba_sha256']==record['rgba_sha256']
 else:p.write(out/'semantic_matte_initial.json',record)
 hashes=[]
 for i,before in enumerate(record['rgba_sha256']):
  file=out/'matte'/f'rgba_{i:03}.png';assert p.sha(file)==before
  apply(Image.open(file)).save(file);hashes.append(p.sha(file))
 record['rgba_sha256']=hashes;record['boundary_despill_source_pixels']=2
 record['edge_despill_recipe']='After semantic alpha and measured plate unmix, reduce min(red,blue)-green only on soft nonzero alpha<250 edge pixels within two source pixels of the opaque boundary. Preserve legitimate green reed clothing/moss and all opaque RGB. Alpha, coordinates, anatomy, mallet, buckler and waist drum retained; no motion synthesis.'
 record['edge_despill_tool_sha256']=p.sha(p.SOURCE_DIR/'edge_despill.py');record['semantic_matte_initial_sha256']=p.sha(out/'semantic_matte_initial.json')
 p.write(out/'matte.json',record);p.review(out,json.loads((out/'config.json').read_bytes()));print('EDGE_DESPILL',take,124,flush=True)
if __name__=='__main__':
 for take in sys.argv[1:]:run(take)
