"""Two-action maximum, complete sampling/decode/matte within one GPU lease."""
import argparse
import stage_video as stage
import produce as p
if __name__=='__main__':
 parser=argparse.ArgumentParser();parser.add_argument('takes',nargs='+');args=parser.parse_args();assert 1<=len(args.takes)<=2
 released_sampling=stage.release_models()
 for take in args.takes:stage.run(take,phase='sample',release=False)
 released_decode=stage.release_models()
 for take in args.takes:stage.run(take,phase='decode',release=False)
 import segment
 net=segment.model()
 for take in args.takes:
  segment.run(net,take)
  p.write(p.SOURCE_DIR/take/'bounded_session.json',dict(sampling_release=released_sampling,decode_release=released_decode,actions=args.takes,rule='Complete bounded sampling, terminal waits, model releases, separate preserved-latent decode and semantic matting held within one shared GPU lease; maximum two actions.'))
 del net
 import subprocess,sys
 for take in args.takes:
  if not (p.SOURCE_DIR/take/'edge_despill.json').exists():
   subprocess.run([sys.executable,str(p.SOURCE_DIR/'edge_despill.py'),take],check=True)
 import torch
 torch.cuda.empty_cache()
 print('BOUNDED_ACTIONS_COMPLETED',args.takes,flush=True)
