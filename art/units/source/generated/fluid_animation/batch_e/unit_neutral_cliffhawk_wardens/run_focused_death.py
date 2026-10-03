"""Render only corrected death/corpse; refresh only the changed battle texture."""
from pathlib import Path
import json,subprocess,sys,os
R=next(p for p in Path(__file__).resolve().parents if (p/'project.godot').exists());S=Path(__file__).parent
sys.path.insert(0,str(R/'tools'));sys.path.insert(0,str(R/'tests'))
from creature_animation_lock import exclusive
UID='unit_neutral_cliffhawk_wardens';OUT=R/'.artifacts/parallel_animation_20261002/middle53_completion_audit/cliffhawk-correction';GODOT='D:/Games/godot/Godot_v4.6.2-stable_win64_console.exe'
def render(mode,facing):
 import fluid_creature_animation_regression as f
 needle='func cell_width()->int:return maxi(155,';assert f.SCRIPT.count(needle)==1;f.SCRIPT=f.SCRIPT.replace(needle,'func cell_width()->int:return maxi(260,')
 needle='\t\t\tif "idle" not in overview.names:\n\t\t\t\toverview.names.push_front("idle");overview.existing_idle=true\n';assert f.SCRIPT.count(needle)==1;f.SCRIPT=f.SCRIPT.replace(needle,'')
 if facing=='reflected':
  needle='var rect:Rect2=Pose.grounded_rect(ground,128,region,row)';assert f.SCRIPT.count(needle)==1;f.SCRIPT=f.SCRIPT.replace(needle,needle[:-1]+',true)')
  needle='\t\t\t\tdraw_texture_rect_region(sheet,rect,region)';assert f.SCRIPT.count(needle)==2
  f.SCRIPT=f.SCRIPT.replace(needle,'\t\t\t\tdraw_set_transform(Vector2(rect.end.x,0),0,Vector2(-1,1))\n\t\t\t\tdraw_texture_rect_region(sheet,Rect2(Vector2(0,rect.position.y),rect.size),region)\n\t\t\t\tdraw_set_transform(Vector2.ZERO,0,Vector2.ONE)')
 out=OUT/(mode+'-'+facing);out.mkdir(parents=True,exist_ok=True)
 if mode=='live':
  row=next(r for r in json.loads((R/'content/unit_animation_manifest.json').read_bytes())['items'] if r['unit_id']==UID)
  patch=dict(schema_version=1,units=[dict(unit_id=UID,animation=row,replaced_clips=['death','dead'])]);path=out/'live_changed_patch.json';path.write_text(json.dumps(patch)+'\n')
  # Use actual imported textures without rerendering unchanged map or moveset.
  f.SCRIPT=f.SCRIPT.replace('OS.get_environment("FLUID_LIVE")=="1"','true')
  start=f.SCRIPT.index('\t\tif true:\n\t\t\tvar idle=Idle.new()');end=f.SCRIPT.index('\tvar board=Board.new()',start);f.SCRIPT=f.SCRIPT[:start]+f.SCRIPT[end:]
 else:path=OUT/'candidate/manifest_patch.json'
 sys.argv=[__file__,'--godot',GODOT,'--unit',UID,'--render','--contacts-only','--overview-only','--output',str(out),'--patch',str(path)]
 assert f.main()==0
 reports=[json.loads(x.split('FLUID_ANIMATION_REPORT ',1)[1]) for x in (out/'console.log').read_text().splitlines() if x.startswith('FLUID_ANIMATION_REPORT ')];assert len(reports)==1 and not reports[0]['failures'];(out/'result.json').write_text(json.dumps(reports[0],indent=2)+'\n')
 print('CLIFFHAWK_DEATH_RENDER_TERMINAL',mode,facing,reports[0]['checks'],flush=True)
if __name__=='__main__':
 mode=sys.argv[1];assert mode in ['candidate','live']
 if len(sys.argv)>2:render(mode,sys.argv[2]);raise SystemExit(0)
 with exclusive('gpu'):
  import urllib.request
  q=json.load(urllib.request.urlopen('http://127.0.0.1:8189/queue'));assert not q['queue_running'] and not q['queue_pending']
  if mode=='live':
   profile=OUT/'import-profile';profile.mkdir(parents=True,exist_ok=True);os.environ.update(APPDATA=str(profile),XDG_DATA_HOME=str(profile))
   from prepare_lossless_texture_imports import prepare
   result=prepare(R,GODOT,OUT/'focused-import.json',only=['art/animation/runtime/fluid/'+UID+'.png']);assert result['ok'] and result['selected']==1
   print('FOCUSED_CHANGED_TEXTURE_IMPORT_OK',result['reimported'],result['cache_hits'],flush=True)
   r=subprocess.run([GODOT,'--headless','--path',str(R),'--script','res://'+(S/'verify_imported_atlas.gd').relative_to(R).as_posix(),'--audio-driver','Dummy'],capture_output=True,text=True,timeout=60,creationflags=subprocess.CREATE_NO_WINDOW)
   (OUT/'exact-import.log').write_text(r.stdout+r.stderr);assert r.returncode==0 and 'CLIFFHAWK_IMPORTED_ATLAS_OK' in r.stdout,(r.returncode,r.stdout,r.stderr);print(r.stdout,flush=True)
  for facing in ['normal','reflected']:subprocess.run([sys.executable,'-B',__file__,mode,facing],check=True)
 print('CLIFFHAWK_FOCUSED_LEASE_RELEASED',mode,flush=True)
