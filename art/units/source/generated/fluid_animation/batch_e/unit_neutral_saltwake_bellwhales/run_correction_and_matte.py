"""One corrected source plus one reviewed existing-source matte in one lease."""
import json,subprocess,sys
import stage_video as stage
import produce as p
if __name__=='__main__':
 corrected='attack_h3_v2';existing='ranged_h3_v2'
 assert (p.SOURCE_DIR/existing/'original.json').exists()
 initial_release=stage.release_models()
 stage.run(corrected,phase='sample',release=False)
 sampled_release=stage.release_models()
 stage.run(corrected,phase='decode',release=False)
 import segment
 net=segment.model()
 for take in [existing,corrected]:
  segment.run(net,take)
  subprocess.run([sys.executable,str(p.SOURCE_DIR/'edge_despill.py'),take],check=True)
  p.write(p.SOURCE_DIR/take/'bounded_session.json',dict(sampling_release=initial_release,decode_release=sampled_release,actions=[existing,corrected],generated_sources=[corrected],rule='One corrected original sampled and decoded, plus semantic matting of one previously decoded/reviewed original. Terminal completion, release and matting all held within one shared GPU lease.'))
 del net
 import torch
 torch.cuda.empty_cache()
 print('CORRECTION_AND_EXISTING_MATTE_COMPLETED',[existing,corrected],flush=True)
