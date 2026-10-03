"""Refresh imports and verify this actual imported atlas under an outer GPU lease."""
import os,subprocess
import produce as p
target=p.ROOT/'.artifacts/parallel_animation_20261002/unit_mireclaw_moonbite_mirehorn_breakers/import';target.mkdir(parents=True,exist_ok=True)
env=dict(os.environ,APPDATA=str(target/'profile'),XDG_DATA_HOME=str(target/'profile'))
godot='D:/Games/godot/Godot_v4.6.2-stable_win64_console.exe'
for name,flags in [('refresh',['--editor','--quit']),('pixels',['--script','res://'+(p.SOURCE_DIR/'verify_imported_atlas.gd').relative_to(p.ROOT).as_posix()])]:
 result=subprocess.run([godot,'--path',str(p.ROOT),'--headless','--audio-driver','Dummy',*flags],cwd=p.ROOT,env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=240,creationflags=subprocess.CREATE_NO_WINDOW)
 text=result.stdout.decode('utf-8',errors='replace');(target/f'{name}.log').write_text(text,encoding='utf-8');print(text,flush=True);assert result.returncode==0,(name,result.returncode)
 if name=='pixels':assert 'MIREHORN_BREAKER_IMPORTED_ATLAS_OK' in text
print('SCOPED_IMPORT_EXACT_PIXELS_COMPLETED',flush=True)
