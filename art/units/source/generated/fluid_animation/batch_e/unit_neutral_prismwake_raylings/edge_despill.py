"""Preserve legitimate rainbow colours after semantic gray-plate alpha unmix."""
import json,sys
import numpy as np
from PIL import Image
import produce as p

def apply(im):
 # Pink and magenta occur naturally in beak, membranes and tendril tips.
 # Semantic extraction already unmixes the measured neutral plate. Do not
 # suppress any colour channel in this creature's genuine painted palette.
 return im.convert('RGBA').copy()

def run(take):
 out=p.SOURCE_DIR/take;record=json.loads((out/'matte.json').read_bytes())
 if record.get('boundary_despill_source_pixels')==0:return
 if (out/'semantic_matte_initial.json').exists():
  initial=json.loads((out/'semantic_matte_initial.json').read_bytes());assert initial['rgba_sha256']==record['rgba_sha256']
 else:p.write(out/'semantic_matte_initial.json',record)
 hashes=[]
 for i,before in enumerate(record['rgba_sha256']):
  file=out/'matte'/f'rgba_{i:03}.png';assert p.sha(file)==before
  original=Image.open(file).convert('RGBA');result=apply(original)
  assert np.array_equal(np.asarray(original),np.asarray(result))
  result.save(file);hashes.append(p.sha(file))
 record['rgba_sha256']=hashes;record['boundary_despill_source_pixels']=0
 record['edge_despill_recipe']='No additional channel despill: preserve legitimate pink/magenta/rainbow membranes and beak. Pinned semantic soft alpha already unmixes the measured neutral gray plate. All semantic RGBA pixels and coordinates are unchanged.'
 record['edge_despill_tool_sha256']=p.sha(p.SOURCE_DIR/'edge_despill.py');record['semantic_matte_initial_sha256']=p.sha(out/'semantic_matte_initial.json')
 p.write(out/'matte.json',record);p.review(out,json.loads((out/'config.json').read_bytes()));print('RAINBOW_RGBA_UNCHANGED',take,124,flush=True)
if __name__=='__main__':
 for take in sys.argv[1:]:run(take)
