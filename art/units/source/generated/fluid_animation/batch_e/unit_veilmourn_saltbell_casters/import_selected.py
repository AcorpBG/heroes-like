"""Ordinary Godot import of only this unit's textures, with existing settings."""
import argparse,os,re,shutil,subprocess
from pathlib import Path
import produce as p
from creature_animation_lock import exclusive

def run(godot):
 with exclusive('gpu'):
  target=p.ROOT/'.artifacts/parallel_animation_20261002'/p.SOURCE_DIR.name/'focused_import';target.mkdir(parents=True,exist_ok=True)
  work=target/'project';assert not work.exists(),'Preserve existing import attempt before retry';work.mkdir()
  setting='textures/webp_compression/lossless_compression_factor'
  original=(p.ROOT/'project.godot').read_text();factor=re.search('^'+re.escape(setting)+r'=(.+)$',original,re.M);assert factor
  (work/'project.godot').write_text('config_version=5\n[application]\nconfig/name="Saltbell focused ordinary import"\n[rendering]\n'+setting+'='+factor[1]+'\n')
  sources=[f'art/animation/runtime/fluid/{p.SOURCE_DIR.name}.png',f'art/overworld/runtime/creature_idle/{p.SOURCE_DIR.name}.png']
  expected={}
  for name in sources:
   source=p.ROOT/name;destination=work/name;destination.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(source,destination)
   expected[name]=p.sha(source)
   importer=Path(str(source)+'.import')
   if importer.exists():shutil.copyfile(importer,Path(str(destination)+'.import'));expected[name+'.import']=p.sha(importer)
  env=dict(os.environ,APPDATA=str(target/'profile'),XDG_DATA_HOME=str(target/'profile'))
  with (target/'import.log').open('w',encoding='utf-8') as log:
   result=subprocess.run([godot,'--headless','--path',str(work),'--editor','--import','--quit'],env=env,stdout=log,stderr=subprocess.STDOUT,timeout=180,creationflags=subprocess.CREATE_NO_WINDOW if os.name=='nt' else 0)
  output=(target/'import.log').read_text();assert result.returncode==0 and not any(line.startswith(('ERROR:','SCRIPT ERROR:')) for line in output.splitlines()),output[-5000:]
  for name in sources:
   assert p.sha(p.ROOT/name)==expected[name]
   imported=Path(str(work/name)+'.import');text=imported.read_text()
   if name+'.import' in expected:assert p.sha(imported)==expected[name+'.import'],'Existing importer options or UID changed'
   cache=re.search(r'^path="res://([^"\n]+)"$',text,re.M);assert cache
   relative=Path(cache[1]);assert relative.parts[:2]==('.godot','imported') and relative.name.startswith(p.SOURCE_DIR.name+'.png-')
   for item in [relative,relative.with_suffix('.md5')]:
    source=work/item;destination=p.ROOT/item;assert source.is_file();destination.parent.mkdir(parents=True,exist_ok=True)
    temporary=destination.with_name(destination.name+'.saltbell-import');shutil.copyfile(source,temporary);temporary.replace(destination)
   if name+'.import' not in expected:shutil.copyfile(imported,Path(str(p.ROOT/name)+'.import'))
  print('SALTBELL_FOCUSED_ORDINARY_IMPORT_OK',len(sources),'existing lossless factor',factor[1],flush=True)

if __name__=='__main__':
 a=argparse.ArgumentParser();a.add_argument('--godot',required=True);args=a.parse_args();run(args.godot)
