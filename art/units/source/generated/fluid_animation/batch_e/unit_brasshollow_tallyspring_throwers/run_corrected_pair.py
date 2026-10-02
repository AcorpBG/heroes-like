"""One reviewed guard interval plus two new original actions; outer GPU lease."""
import subprocess,sys
import produce as p
if __name__=='__main__':
 for script,args in [('segment_guard_interval.py',[]),('run_bound_actions.py',['hit_h3_v2','cast_h3_v1'])]:
  subprocess.run([sys.executable,str(p.SOURCE_DIR/script),*args],check=True,stdout=sys.stdout,stderr=sys.stderr,creationflags=subprocess.CREATE_NO_WINDOW if sys.platform=='win32' else 0)
