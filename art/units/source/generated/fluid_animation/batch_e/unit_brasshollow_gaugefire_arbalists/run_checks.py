"""Bounded Godot GPU stages for the selected Gaugefire delivery only."""
import argparse,os,subprocess,sys
from pathlib import Path
ROOT=next(p for p in Path(__file__).resolve().parents if (p/'project.godot').exists())
OUT=Path(__file__).resolve().parent
UID='unit_brasshollow_gaugefire_arbalists'
BASE=ROOT/'.artifacts/parallel_animation_20261002'/UID
GODOT=Path('D:/Games/godot/Godot_v4.6.2-stable_win64_console.exe' if os.name=='nt' else 'godot')
sys.path.insert(0,str(ROOT/'tools'))
from creature_animation_lock import exclusive
import stage_video

def fixture(script,name,live=False):
 command=[sys.executable,str(OUT/script),'--godot',str(GODOT),'--unit',UID,'--render','--output',str(BASE/name)]
 command+=['--live'] if live else ['--handoff',str(OUT/'handoff.json')]
 subprocess.run(command,cwd=ROOT,check=True)

def imported():
 profile=BASE/'import_profile';profile.mkdir(parents=True,exist_ok=True)
 env=dict(os.environ,APPDATA=str(profile),XDG_DATA_HOME=str(profile))
 for name,args in [('import',['--editor','--import','--quit']),('imported_atlas',['--script',str(OUT/'verify_imported_atlas.gd')])]:
  command=[str(GODOT),'--path',str(ROOT),'--headless','--audio-driver','Dummy','--log-file',str(BASE/(name+'.log')),*args]
  with (BASE/(name+'_console.log')).open('w',encoding='utf-8') as log:
   subprocess.run(command,cwd=ROOT,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=180,creationflags=subprocess.CREATE_NO_WINDOW if os.name=='nt' else 0,check=True)
  result=(BASE/(name+'_console.log')).read_text(encoding='utf-8');print(result,flush=True)
  if name=='imported_atlas':assert 'GAUGEFIRE_IMPORTED_ATLAS_OK' in result

if __name__=='__main__':
 parser=argparse.ArgumentParser();parser.add_argument('mode',choices=['candidate','ranged','live']);parser.add_argument('--godot',type=Path,default=GODOT);a=parser.parse_args();GODOT=a.godot
 BASE.mkdir(parents=True,exist_ok=True)
 with exclusive('gpu'):
  stage_video.release_models()
  if a.mode=='candidate':
   fixture('run_native_review.py','candidate');fixture('run_mirrored_native.py','mirrored')
  elif a.mode=='ranged':fixture('run_ranged_native.py','ranged')
  else:
   imported();fixture('run_native_review.py','live',live=True)
 print('FOCUSED_STAGE_COMPLETE',a.mode,flush=True)
