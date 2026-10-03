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
 import segment,subprocess,sys,json,torch
 net=segment.model();failed=[]
 try:
  for take in args.takes:
   out=p.SOURCE_DIR/take
   try:
    segment.run(net,take)
    if not (out/'edge_despill.json').exists():
     subprocess.run([sys.executable,str(p.SOURCE_DIR/'edge_despill.py'),take],check=True)
   except Exception as error:
    partial=sorted((out/'matte').glob('rgba_*.png'))
    p.write(out/'extraction_failure.json',dict(error=str(error),status='requires_original_frame_review',preserved_original_rgb_frames=json.loads((out/'original.json').read_bytes())['frames'],partial_mattes=[dict(file=f.relative_to(out).as_posix(),sha256=p.sha(f)) for f in partial],first_unwritten_source_index=next((i for i in range(124) if not (out/'matte'/f'rgba_{i:03}.png').exists()),None),rule='Unchanged strict extraction; preserve failure and originals, never fallback or accept automatically. Continue only the other already-decoded source within this same bounded pair.'))
    failed.append(take);print('PRESERVED_EXTRACTION_FAILURE',take,str(error),flush=True)
   p.write(out/'bounded_session.json',dict(sampling_release=released_sampling,decode_release=released_decode,actions=args.takes,matte_completed=take not in failed,rule='Complete bounded sampling, terminal waits, model releases, separate preserved-latent decode and semantic matting held within one shared GPU lease; maximum two actions.'))
 finally:
  del net
  torch.cuda.empty_cache()
 if failed:raise RuntimeError('Original review required for failed strict mattes: '+', '.join(failed))
 print('BOUNDED_ACTIONS_COMPLETED',args.takes,flush=True)
