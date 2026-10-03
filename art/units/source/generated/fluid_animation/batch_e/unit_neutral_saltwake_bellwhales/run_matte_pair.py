"""Extract at most two reviewed existing originals under an outer GPU lease."""
import argparse,subprocess,sys,json
import produce as p
import segment
parser=argparse.ArgumentParser();parser.add_argument('takes',nargs='+');args=parser.parse_args()
assert 1<=len(args.takes)<=2
assert all((p.SOURCE_DIR/t/'original.json').exists() for t in args.takes)
net=segment.model()
for take in args.takes:
 segment.run(net,take)
 subprocess.run([sys.executable,str(p.SOURCE_DIR/'edge_despill.py'),take],check=True)
 p.write(p.SOURCE_DIR/take/'bounded_matte_session.json',dict(actions=args.takes,rule='Original-only extraction, unchanged strict uniform plate samples and pinned semantic model; terminal process holds GPU for maximum two takes.'))
del net
import torch
torch.cuda.empty_cache()
print('BOUNDED_MATTE_COMPLETED',args.takes,flush=True)
