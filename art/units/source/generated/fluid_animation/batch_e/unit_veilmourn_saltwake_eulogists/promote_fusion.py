"""Retain original semantic masks and recover enclosed, source-backed glass."""
import argparse,json,hashlib,av
from PIL import Image
import produce as p
from fusion_matting import fuse
from edge_despill import clean
if __name__=='__main__':
 a=argparse.ArgumentParser();a.add_argument('take');args=a.parse_args();out=p.SOURCE_DIR/args.take
 assert not (out/'fusion_matting.json').exists(),'Already promoted; use exact rebuild tool'
 prior=json.loads((out/'matte.json').read_bytes());edge=json.loads((out/'edge_despill.json').read_bytes());original=json.loads((out/'original.json').read_bytes());c=json.loads((out/'config.json').read_bytes())
 p.write(out/'matte_semantic.json',prior);alpha_dir=out/'semantic_alpha';alpha_dir.mkdir(exist_ok=True);alphas=[];details=[];hashes=[]
 with av.open(str(out/'original_lossless.mkv')) as video:
  for i,frame in enumerate(video.decode(video=0)):
   rgb=frame.to_image().convert('RGB');assert hashlib.sha256(rgb.tobytes()).hexdigest()==original['decoded_rgb_sha256'][i]
   f=out/'matte'/f'rgba_{i:03}.png';assert p.sha(f)==prior['rgba_sha256'][i];semantic=Image.open(f).convert('RGBA');alpha=semantic.getchannel('A');ah=hashlib.sha256(alpha.tobytes()).hexdigest();assert ah==edge['details'][i]['alpha_sha256']
   af=alpha_dir/f'alpha_{i:03}.png';alpha.save(af);alphas.append(dict(source_frame=i,file_sha256=p.sha(af),original_alpha_sha256=ah))
   im,detail=fuse(rgb,semantic,c,prior['background_frames'][i]['background_rgb']);im,_=clean(im,prior['background_frames'][i]['background_rgb']);im.save(f);hashes.append(p.sha(f));details.append(dict(source_frame=i,**detail))
 p.write(out/'semantic_alpha.json',dict(frames=alphas,original_lossless_sha256=p.sha(out/'original_lossless.mkv'),original_semantic_recipe_sha256=p.sha(out/'matte_semantic.json')))
 p.write(out/'fusion_matting.json',dict(rule='Original RGB uniform-plate opacity inside closed semantic alpha>=128 only; every outside alpha byte exact. Unsafe plate retains semantic alpha. No dilation or invented color/anatomy.',details=details,tool_sha256=p.sha(p.SOURCE_DIR/'fusion_matting.py'),promotion_tool_sha256=p.sha(p.SOURCE_DIR/'promote_fusion.py'),original_semantic_recipe_sha256=p.sha(out/'matte_semantic.json')))
 prior['rgba_sha256']=hashes;prior['recipe']+=' Enclosed source-color opacity recovery; original semantic alpha retained for exact CPU rebuild.';p.write(out/'matte.json',prior);p.review(out,c);print('PROMOTED_SOURCE_FUSION',args.take,sum(d['recovered_pixels'] for d in details),flush=True)
