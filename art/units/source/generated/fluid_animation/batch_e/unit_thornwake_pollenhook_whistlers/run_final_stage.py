"""Bounded final import/live review; caller must hold shared GPU through exit."""
import os,subprocess,sys
from pathlib import Path

if __name__=='__main__':
    source=Path(__file__).resolve().parent
    for script,args in [('run_import_stage.py',[]),('run_review_stage.py',['live'])]:
        subprocess.run([sys.executable,str(source/script),*args],check=True,
                       creationflags=subprocess.CREATE_NO_WINDOW if os.name=='nt' else 0)
    print('FINAL_IMPORT_LIVE_STAGE_OK',flush=True)
