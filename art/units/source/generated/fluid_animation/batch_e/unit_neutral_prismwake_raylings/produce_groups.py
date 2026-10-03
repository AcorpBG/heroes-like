"""Owner-approved bounded two-action GPU groups through exact source matting."""
import argparse,subprocess,sys,time
import produce as p
import stage_video as stage
from creature_animation_lock import exclusive
def finish_tool(name,group):
 target=p.ROOT/'.artifacts/parallel_animation_20261002/unit_neutral_prismwake_raylings';target.mkdir(parents=True,exist_ok=True)
 log=target/(name+'-'+'-'.join(group)+'.log')
 with log.open('w',encoding='utf-8') as stream:
  result=subprocess.run([sys.executable,str(p.SOURCE_DIR/(name+'.py')),*group],stdout=stream,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW if sys.platform=='win32' else 0)
 print(log.read_text(encoding='utf-8')[-6000:],flush=True)
 result.check_returncode()

def run(takes):
 for start in range(0,len(takes),2):
  group=takes[start:start+2]
  with exclusive('gpu'):
   for i,take in enumerate(group):stage.run(take,phase='sample',release=i==0)
   for i,take in enumerate(group):stage.run(take,phase='decode',release=i==0)
   finish_tool('segment',group)
   finish_tool('edge_despill',group)
  print('BOUNDED_GROUP_COMPLETE',group,flush=True)
  # Native Windows mutex acquisition is not FIFO. Let queued first-turn
  # workers wake before this producer can immediately reacquire.
  time.sleep(2)
if __name__=='__main__':
 a=argparse.ArgumentParser();a.add_argument('takes',nargs='+');args=a.parse_args();run(args.takes)
