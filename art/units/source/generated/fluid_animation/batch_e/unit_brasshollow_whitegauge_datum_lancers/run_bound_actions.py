"""Complete one/two original actions under an outer GPU lease."""
import argparse,json,subprocess,sys
import stage_video as stage
import produce as p
if __name__=='__main__':
 parser=argparse.ArgumentParser();parser.add_argument('takes',nargs='+');parser.add_argument('--rematte',action='append',default=[]);a=parser.parse_args();assert 1<=len(a.takes)<=2
 if a.rematte:subprocess.run([sys.executable,str(p.SOURCE_DIR/'segment.py'),*a.rematte],check=True,stdout=sys.stdout,stderr=sys.stderr,creationflags=subprocess.CREATE_NO_WINDOW if sys.platform=='win32' else 0)
 for i,t in enumerate(a.takes):stage.run(t,phase='sample',release=i==0)
 for i,t in enumerate(a.takes):stage.run(t,phase='decode',release=i==0)
 missing=[t for t in a.takes if not (p.SOURCE_DIR/t/'matte.json').exists()]
 if missing:
  subprocess.run([sys.executable,str(p.SOURCE_DIR/'segment.py'),*missing],check=True,stdout=sys.stdout,stderr=sys.stderr,creationflags=subprocess.CREATE_NO_WINDOW if sys.platform=='win32' else 0)
