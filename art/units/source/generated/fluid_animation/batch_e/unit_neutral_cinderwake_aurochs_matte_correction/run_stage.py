"""Bounded Cinderwake correction verification; GPU lock lasts through terminal exit."""
from pathlib import Path
import json,subprocess,sys,os
R=next(p for p in Path(__file__).resolve().parents if (p/'project.godot').exists());S=Path(__file__).parent
sys.path.insert(0,str(R/'tools'));sys.path.insert(0,str(R/'tests'))
from creature_animation_lock import exclusive
UID='unit_neutral_cinderwake_aurochs';OUT=R/'.artifacts/parallel_animation_20261002/middle53_completion_audit/cinderwake-correction'
def render(mode,facing):
 import fluid_creature_animation_regression as f
 needle='func cell_width()->int:return maxi(155,';assert f.SCRIPT.count(needle)==1;f.SCRIPT=f.SCRIPT.replace(needle,'func cell_width()->int:return maxi(260,')
 if facing=='reflected':
  needle='var rect:Rect2=Pose.grounded_rect(ground,128,region,row)';assert f.SCRIPT.count(needle)==1;f.SCRIPT=f.SCRIPT.replace(needle,needle[:-1]+',true)')
  needle='\t\t\t\tdraw_texture_rect_region(sheet,rect,region)';assert f.SCRIPT.count(needle)==2
  f.SCRIPT=f.SCRIPT.replace(needle,'\t\t\t\tdraw_set_transform(Vector2(rect.end.x,0),0,Vector2(-1,1))\n\t\t\t\tdraw_texture_rect_region(sheet,Rect2(Vector2(0,rect.position.y),rect.size),region)\n\t\t\t\tdraw_set_transform(Vector2.ZERO,0,Vector2.ONE)')
 # Fix capture ordering in this private fixture only, observing actual shell clock.
 sys.path.insert(0,str(R/'art/units/source/generated/fluid_animation/batch_e/unit_thornwake_woundroot_rootmaul_behemoths'))
 from capture_clock import observe_after_draw
 observe_after_draw(f)
 out=OUT/(mode+'-'+facing);out.mkdir(parents=True,exist_ok=True)
 sys.argv=[__file__,'--godot','D:/Games/godot/Godot_v4.6.2-stable_win64_console.exe','--unit',UID,'--render','--overview-only','--output',str(out)]+(['--live'] if mode=='live' else ['--handoff',str(S/'candidate_handoff.json')])
 code=f.main();assert code==0
 reports=[json.loads(x.split('FLUID_ANIMATION_REPORT ',1)[1]) for x in (out/'console.log').read_text().splitlines() if x.startswith('FLUID_ANIMATION_REPORT ')];assert len(reports)==1 and not reports[0]['failures'];(out/'result.json').write_text(json.dumps(reports[0],indent=2)+'\n')
 print('CORRECTION_RENDER_TERMINAL',mode,facing,reports[0]['checks'],flush=True)
if __name__=='__main__':
 mode=sys.argv[1]
 if len(sys.argv)>2:render(mode,sys.argv[2]);raise SystemExit(0)
 assert mode in ['candidate','live']
 with exclusive('gpu'):
  import urllib.request
  q=json.load(urllib.request.urlopen('http://127.0.0.1:8189/queue'));assert not q['queue_running'] and not q['queue_pending']
  if mode=='live':
   profile=OUT/'import-profile';profile.mkdir(parents=True,exist_ok=True)
   os.environ.update(APPDATA=str(profile),XDG_DATA_HOME=str(profile))
   from prepare_lossless_texture_imports import prepare,exported_pngs
   assert all(Path(str(p)+'.import').is_file() for p in exported_pngs(R)),'Refuse broad initialization; only own existing texture caches may be refreshed'
   result=prepare(R,'D:/Games/godot/Godot_v4.6.2-stable_win64_console.exe',OUT/'focused-import.json',only=['art/animation/runtime/fluid/'+UID+'.png','art/overworld/runtime/creature_idle/'+UID+'.png']);assert result['ok'] and result['selected']==2
   print('FOCUSED_TWO_TEXTURE_IMPORT_OK',result['reimported'],result['cache_hits'],flush=True)
   env=dict(os.environ,APPDATA=str(OUT/'import-profile'),XDG_DATA_HOME=str(OUT/'import-profile'))
   r=subprocess.run(['D:/Games/godot/Godot_v4.6.2-stable_win64_console.exe','--headless','--path',str(R),'--script','res://'+(S/'verify_imported_atlas.gd').relative_to(R).as_posix(),'--audio-driver','Dummy'],env=env,capture_output=True,text=True,timeout=60,creationflags=subprocess.CREATE_NO_WINDOW)
   (OUT/'exact-import.log').write_text(r.stdout+r.stderr);assert r.returncode==0 and 'CINDERWAKE_IMPORTED_ATLAS_OK ' in r.stdout,(r.returncode,r.stdout,r.stderr);print(r.stdout,flush=True)
  for facing in ['normal','reflected']:subprocess.run([sys.executable,'-B',__file__,mode,facing],check=True)
 print('CORRECTION_BOUNDED_LEASE_RELEASED',mode,flush=True)
