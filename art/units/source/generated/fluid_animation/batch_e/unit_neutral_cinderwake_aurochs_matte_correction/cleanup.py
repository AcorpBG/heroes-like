"""Remove only completed task-owned diagnostic/render copies, preserving sources/caches."""
from pathlib import Path
import json,os,shutil,subprocess
R=next(p for p in Path(__file__).resolve().parents if (p/'project.godot').exists());S=Path(__file__).parent
completion=json.loads((S/'completion.json').read_bytes());assert completion['status']=='complete_selected_unit'
result=subprocess.run(['powershell','-NoProfile','-Command',"Get-CimInstance Win32_Process | Where-Object {$_.Name -match 'python|godot'} | Select-Object ProcessId,CommandLine | ConvertTo-Json -Compress"],capture_output=True,text=True,check=True)
rows=json.loads(result.stdout or '[]');rows=rows if isinstance(rows,list) else [rows]
for row in rows:
 if row['ProcessId']==os.getpid():continue
 command=(row.get('CommandLine') or '').replace('\\','/').lower()
 assert 'cinderwake_aurochs_matte_correction/' not in command and 'cinderwake-correction' not in command,(row['ProcessId'],command)
targets=[R/'.artifacts/parallel_animation_20261002/middle53_completion_audit'/name for name in ['cinderwake-correction','cinderwake-diagnosis']]
records=[]
for target in targets:
 assert target.resolve().is_relative_to(R/'.artifacts/parallel_animation_20261002/middle53_completion_audit') and target.name in ['cinderwake-correction','cinderwake-diagnosis']
 assert not target.is_symlink()
 if not target.exists():continue
 paths=list(target.rglob('*'));assert not any(p.is_symlink() for p in paths)
 files=[p for p in paths if p.is_file()];records.append(dict(path=target.relative_to(R).as_posix(),files=len(files),bytes=sum(p.stat().st_size for p in files)))
 shutil.rmtree(target);assert not target.exists()
completion['cleanup']=dict(records=records,files=sum(r['files'] for r in records),bytes=sum(r['bytes'] for r in records),rebuildable=True,preserved='All original RGB videos/mattes/provenance, exact derived alpha, source/tools, game import caches, saves, other audit evidence and unrelated work retained.')
(S/'completion.json').write_text(json.dumps(completion,indent=2)+'\n')
print('CINDERWAKE_EXACT_CLEANUP',json.dumps(completion['cleanup']),flush=True)
