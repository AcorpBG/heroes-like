"""Stage exact original sources and only this UID in shared HEAD catalogs."""
import argparse,hashlib,json,os,subprocess,sys,time
from pathlib import Path
ROOT=next(p for p in Path(__file__).resolve().parents if (p/'project.godot').exists())
OUT=Path(__file__).resolve().parent
UID='unit_neutral_gaugecoil_orewyrms'
sys.path.insert(0,str(ROOT/'tools'))
from creature_animation_lock import exclusive
def repair_stale_lock():
 # Called only inside the shared Git mutex, after a child Git has exited.
 lock=ROOT/'.git/index.lock'
 assert lock.resolve()==(ROOT.resolve()/'.git/index.lock')
 command="""$ErrorActionPreference='Stop';$deadline=[DateTime]::UtcNow.AddSeconds(60);do{$active=@(Get-CimInstance Win32_Process | Where-Object {$_.Name -match '^git.*\\.exe$'});if(-not $active.Count){break};Start-Sleep -Seconds 2}while([DateTime]::UtcNow-lt $deadline);if($active.Count){throw 'Active Git process; preserve lock'};$p='D:/Games/godot/heroes-like/.git/index.lock';if(Test-Path -LiteralPath $p){$f=[IO.File]::Open($p,[IO.FileMode]::Open,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None);try{if($f.Length-ne 0){throw 'Nonempty lock; preserve'}}finally{$f.Dispose()};Remove-Item -LiteralPath $p;Write-Output 'Proved inactive Git and exclusive zero-byte handle; removed exact index.lock.'}"""
 result=subprocess.run(['powershell','-NoProfile','-Command',command],cwd=ROOT,stdout=subprocess.PIPE,stderr=subprocess.PIPE,creationflags=subprocess.CREATE_NO_WINDOW)
 print(result.stdout.decode(errors='replace'),flush=True)
 if result.returncode:print(result.stderr.decode(errors='replace'),flush=True);result.check_returncode()

def git(*args,data=None):
 for attempt in range(3):
  r=subprocess.run(['git','-c','gc.auto=0','-c','maintenance.auto=false',*args],cwd=ROOT,input=data,stdout=subprocess.PIPE,stderr=subprocess.PIPE,env=dict(os.environ,GIT_OPTIONAL_LOCKS='0'))
  if r.returncode==0:return r.stdout
  if b'index.lock' in r.stderr and b'File exists' in r.stderr and attempt<2:
   time.sleep(1);repair_stale_lock();continue
  print(r.stderr.decode(errors='replace'),flush=True);r.check_returncode()
def read(p):return json.loads(p.read_bytes())
def stage_blob(path,data):
 h=git('hash-object','-w','--stdin',data=data).decode().strip();git('update-index','--add','--cacheinfo',f'100644,{h},{path}')
 assert git('cat-file','blob',':'+path)==data
if __name__=='__main__':
 parser=argparse.ArgumentParser();parser.add_argument('--resume-partial',action='store_true');options=parser.parse_args()
 completion=read(OUT/'completion.json');assert completion['status']=='complete_selected_unit' and not completion['validation']['failures']
 with exclusive('content'):
  owned_catalog=next(r for r in read(ROOT/'content/unit_animation_manifest.json')['items'] if r['unit_id']==UID)
  owned_map=read(ROOT/'art/overworld/creature_idle.json')['units'][UID]
 with exclusive('git'):
  initial=git('diff','--cached','--name-only').decode().splitlines()
  assert not initial or (options.resume_partial and set(initial)=={'.gitattributes','content/unit_animation_manifest.json'}),'Shared index occupied; preserve'
  if (ROOT/'.git/index.lock').exists():repair_stale_lock()
  assert git('branch','--show-current').decode().strip()=='main'
  head=git('rev-parse','HEAD').decode().strip()
  source=OUT.relative_to(ROOT).as_posix();rules=[source+'/** -text',f'art/animation/source/fluid/{UID}/*.json -text']
  liveattrs=(ROOT/'.gitattributes').read_text();headattrs=git('show','HEAD:.gitattributes').decode()
  for rule in rules:
   if rule not in liveattrs.splitlines():liveattrs=liveattrs.rstrip()+'\n'+rule+'\n'
   if rule not in headattrs.splitlines():headattrs=headattrs.rstrip()+'\n'+rule+'\n'
  if initial:assert git('cat-file','blob',':.gitattributes')==headattrs.encode(),'Staged attributes are not our exact HEAD plus own rules'
  if (ROOT/'.gitattributes').read_text()!=liveattrs:(ROOT/'.gitattributes').write_text(liveattrs,encoding='utf-8')
  stage_blob('.gitattributes',headattrs.encode())
  for path,kind in [('content/unit_animation_manifest.json','catalog'),('art/overworld/creature_idle.json','map')]:
   baseline=json.loads(git('show','HEAD:'+path));old=json.loads(json.dumps(baseline))
   if kind=='catalog':
    own=owned_catalog
    for i,row in enumerate(baseline['items']):
     if row['unit_id']==UID:baseline['items'][i]=own;break
    assert [r for r in old['items'] if r['unit_id']!=UID]==[r for r in baseline['items'] if r['unit_id']!=UID]
    data=(json.dumps(baseline,separators=(',',':'))+'\n').encode()
   else:
    baseline['units'][UID]=owned_map
    assert {k:v for k,v in old['units'].items() if k!=UID}=={k:v for k,v in baseline['units'].items() if k!=UID}
    data=(json.dumps(baseline,indent=2)+'\n').encode()
   if path in initial:assert git('cat-file','blob',':'+path)==data,'Staged catalog is not our exact HEAD plus UID'
   stage_blob(path,data)
  paths=[source,f'art/animation/runtime/fluid/{UID}.png',f'art/animation/source/fluid/{UID}',f'art/overworld/runtime/creature_idle/{UID}.png']
  git('add','--',*paths)
  staged=git('diff','--cached','--name-only').decode().splitlines()
  for path in staged:
   assert path in ['.gitattributes','content/unit_animation_manifest.json','art/overworld/creature_idle.json'] or any(path==p or path.startswith(p+'/') for p in paths),path
   if path not in ['.gitattributes','content/unit_animation_manifest.json','art/overworld/creature_idle.json']:
    assert hashlib.sha256(git('cat-file','blob',':'+path)).digest()==hashlib.sha256((ROOT/path).read_bytes()).digest(),path
  for record in read(OUT/'handoff.json')['units'][0]['provenance'].values():assert hashlib.sha256((ROOT/record['path']).read_bytes()).hexdigest()==record['sha256'],record['path']
  print('Exact indexed originals verified:',len(staged),'paths; other HEAD rows preserved.',flush=True)
  git('-c','user.name=AcorpBG','-c','user.email=10956556+AcorpBG@users.noreply.github.com','commit','--quiet','-m','Complete Gaugecoil Orewyrms original H3 action animation')
  commit=git('rev-parse','HEAD').decode().strip();assert not git('diff','--cached','--name-only').strip()
  print('COMMITTED',commit,flush=True)
  try:
   output=git('-c','http.version=HTTP/1.1','-c','http.postBuffer=1073741824','push','origin','main');print(output.decode(),flush=True)
   print('PUSHED',commit,flush=True)
  except subprocess.CalledProcessError as e:
   print('PUSH_FAILED',e.stderr.decode(),flush=True);raise
  print('FINAL_GIT_STATUS',git('status','--short').decode(),flush=True)
