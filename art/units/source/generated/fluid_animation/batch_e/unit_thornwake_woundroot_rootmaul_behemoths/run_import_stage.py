"""Refresh actual Godot texture import and prove imported RGBA, under GPU lease."""
import os,subprocess,sys
from pathlib import Path
import produce as p
if __name__=='__main__':
 out=p.ROOT/'.artifacts/parallel_animation_20261002/unit_thornwake_woundroot_rootmaul_behemoths/import';out.mkdir(parents=True,exist_ok=True)
 env=dict(os.environ,APPDATA=str(out/'profile'),XDG_DATA_HOME=str(out/'profile'))
 binary='D:/Games/godot/Godot_v4.6.2-stable_win64_console.exe';flags=subprocess.CREATE_NO_WINDOW if os.name=='nt' else 0
 jobs=[('editor',[binary,'--path',str(p.ROOT),'--headless','--import','--audio-driver','Dummy','--log-file',str(out/'editor-engine.log')]),('pixels',[binary,'--path',str(p.ROOT),'--headless','--script','res://'+(p.SOURCE_DIR/'verify_imported_atlas.gd').relative_to(p.ROOT).as_posix(),'--audio-driver','Dummy','--log-file',str(out/'pixels-engine.log')])]
 for name,cmd in jobs:
  r=subprocess.run(cmd,env=env,capture_output=True,text=True,timeout=180,creationflags=flags);(out/(name+'.log')).write_text(r.stdout+r.stderr,encoding='utf-8');print(r.stdout+r.stderr,flush=True);assert r.returncode==0,(name,r.returncode)
  if name=='pixels':
   errors=[line for line in (r.stdout+r.stderr).splitlines() if 'ERROR' in line and 'Failed to read the root certificate store.' not in line]
   assert 'ROOTMAUL_BEHEMOTH_IMPORTED_ATLAS_OK ' in r.stdout and not errors,errors
 print('IMPORTED_EXACT_RGBA_VERIFIED',flush=True)
