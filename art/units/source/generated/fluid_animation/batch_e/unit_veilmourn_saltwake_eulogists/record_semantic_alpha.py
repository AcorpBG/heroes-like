"""Verify retained initial NN opacity against the original extraction recipe."""
import argparse,json,hashlib
from PIL import Image
import produce as p
if __name__=='__main__':
 a=argparse.ArgumentParser();a.add_argument('take');args=a.parse_args();out=p.SOURCE_DIR/args.take;edge=json.loads((out/'edge_despill.json').read_bytes());frames=[]
 for i in range(124):
  f=out/'semantic_alpha'/f'alpha_{i:03}.png';alpha=Image.open(f).convert('L');h=hashlib.sha256(alpha.tobytes()).hexdigest();assert h==edge['details'][i]['alpha_sha256'];frames.append(dict(source_frame=i,file_sha256=p.sha(f),original_alpha_sha256=h))
 p.write(out/'semantic_alpha.json',dict(frames=frames,original_lossless_sha256=p.sha(out/'original_lossless.mkv'),original_semantic_recipe_sha256=p.sha(out/'matte_semantic.json'),tool_sha256=p.sha(p.SOURCE_DIR/'record_semantic_alpha.py')));print('ORIGINAL_SEMANTIC_ALPHA_VERIFIED',args.take,len(frames))
