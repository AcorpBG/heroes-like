"""Finish remaining Ironback sources in separately locked bounded groups."""
import subprocess,sys,time
import produce as p
from creature_animation_lock import exclusive

if __name__=='__main__':
    for takes in [['defend_h3_v1','cast_h3_v1'],['death_h3_v1']]:
        if all((p.SOURCE_DIR/take/'edge_matte.json').exists() for take in takes):continue
        with exclusive('gpu'):
            subprocess.run([sys.executable,str(p.SOURCE_DIR/'run_actions.py'),*takes],cwd=p.ROOT,check=True)
        print('SOURCES_READY',takes,flush=True)
        time.sleep(2)
