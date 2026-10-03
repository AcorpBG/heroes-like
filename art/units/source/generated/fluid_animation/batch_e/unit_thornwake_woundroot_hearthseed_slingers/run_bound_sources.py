"""One retained waiter, at most two complete originals including decode/matte."""
import argparse,json,subprocess,sys
import produce as p
import stage_video
from creature_animation_lock import exclusive

if __name__=='__main__':
 parser=argparse.ArgumentParser();parser.add_argument('takes',nargs='+');args=parser.parse_args()
 assert 1<=len(args.takes)<=2 and len(args.takes)==len(set(args.takes))
 for take in args.takes:assert (p.SOURCE_DIR/take/'config.json').exists()
 with exclusive('gpu'):
  for i,take in enumerate(args.takes):stage_video.run(take,phase='sample',release=i==0)
  for i,take in enumerate(args.takes):stage_video.run(take,phase='decode',release=i==0)
  pending=[take for take in args.takes if not (p.SOURCE_DIR/take/'matte.json').exists()]
  if pending:subprocess.run([sys.executable,str(p.SOURCE_DIR/'segment.py'),*pending],cwd=p.ROOT,check=True)
  stage_video.release_models()
 print('COMPLETE_BOUNDED_SOURCES',args.takes,flush=True)
 # A new lease is a separate explicit invocation after personal CPU review.
 for take in args.takes:subprocess.run([sys.executable,str(p.SOURCE_DIR/'review_originals.py'),'raw',take],cwd=p.ROOT,check=True)
