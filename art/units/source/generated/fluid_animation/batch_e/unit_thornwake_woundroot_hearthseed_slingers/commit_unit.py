"""Scoped main commit: current HEAD blobs plus this UID; no other live rows staged."""
import json,subprocess,sys,hashlib,os,time,ctypes
from ctypes import wintypes as w
from pathlib import Path
ROOT=next(p for p in Path(__file__).resolve().parents if (p/'project.godot').exists());SOURCE=Path(__file__).resolve().parent;UID=SOURCE.name
sys.path.insert(0,str(ROOT/'tools'))
from creature_animation_lock import exclusive
CONFIG=['git','-c','gc.auto=0','-c','maintenance.auto=false']
def git(*args,input=None):
 for attempt in range(5):
  r=subprocess.run(CONFIG+list(args),cwd=ROOT,env=dict(os.environ,GIT_OPTIONAL_LOCKS='0'),input=input,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
  if not r.returncode:return r.stdout
  if r.returncode==128 and b'index.lock' in r.stderr and attempt<4:
   recover_own_empty_lock();continue
  print(r.stderr.decode(errors='replace'),file=sys.stderr,flush=True);r.check_returncode()
def index_blob(path,raw):
 blob=git('hash-object','-w','--stdin',input=raw).decode().strip();git('update-index','--add','--cacheinfo','100644,'+blob+','+path);assert git('show',':'+path)==raw

def recover_own_empty_lock(expected_utc=None):
 index=ROOT/'.git/index';index_before=hashlib.sha256(index.read_bytes()).hexdigest()
 path=ROOT/'.git/index.lock'
 try:before=path.stat()
 except FileNotFoundError:
  assert hashlib.sha256(index.read_bytes()).hexdigest()==index_before,'Index changed while lock disappeared'
  return
 assert path.resolve()==ROOT.resolve()/'.git/index.lock' and before.st_size==0
 if expected_utc is not None:assert time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime(before.st_mtime))==expected_utc
 def inactive():
  script="@(Get-CimInstance Win32_Process | Where-Object { $_.ProcessId -ne "+str(os.getpid())+" -and ($_.Name -eq 'git.exe' -or ($_.Name -match 'python' -and $_.CommandLine -match 'commit_unit|update-index|hash-object|git push|git commit')) } | Select-Object ProcessId,ParentProcessId,Name,CommandLine) | ConvertTo-Json -Compress"
  deadline=time.monotonic()+120
  while True:
   r=subprocess.run(['pwsh','-NoProfile','-Command',script],capture_output=True,text=True,check=True)
   assert not r.stderr.strip(),r.stderr
   if not r.stdout.strip() or json.loads(r.stdout)==[]:return
   assert time.monotonic()<deadline,('Git remains active; empty lock retained',r.stdout)
   time.sleep(2)
 inactive();inactive()
 class Info(ctypes.Structure):
  _fields_=[('attr',w.DWORD),('created',w.FILETIME),('accessed',w.FILETIME),('written',w.FILETIME),('volume',w.DWORD),('size_high',w.DWORD),('size_low',w.DWORD),('links',w.DWORD),('index_high',w.DWORD),('index_low',w.DWORD)]
 class Disposition(ctypes.Structure):
  _fields_=[('DeleteFile',w.BOOL)]
 k=ctypes.WinDLL('kernel32',use_last_error=True)
 k.CreateFileW.argtypes=[w.LPCWSTR,w.DWORD,w.DWORD,ctypes.c_void_p,w.DWORD,w.DWORD,w.HANDLE];k.CreateFileW.restype=w.HANDLE
 k.GetFileInformationByHandle.argtypes=[w.HANDLE,ctypes.POINTER(Info)];k.GetFileInformationByHandle.restype=w.BOOL
 k.ReadFile.argtypes=[w.HANDLE,ctypes.c_void_p,w.DWORD,ctypes.POINTER(w.DWORD),ctypes.c_void_p];k.ReadFile.restype=w.BOOL
 k.SetFileInformationByHandle.argtypes=[w.HANDLE,ctypes.c_int,ctypes.c_void_p,w.DWORD];k.SetFileInformationByHandle.restype=w.BOOL
 k.CloseHandle.argtypes=[w.HANDLE];k.CloseHandle.restype=w.BOOL
 handle=k.CreateFileW(str(path),0x80010000,0,None,3,0x00200000,None)
 if handle in [None,ctypes.c_void_p(-1).value] and ctypes.get_last_error()==2 and not path.exists():
  assert hashlib.sha256(index.read_bytes()).hexdigest()==index_before,'Index changed while lock disappeared'
  return
 assert handle not in [None,ctypes.c_void_p(-1).value],ctypes.get_last_error()
 try:
  a=Info();assert k.GetFileInformationByHandle(handle,ctypes.byref(a));assert a.size_high==a.size_low==0 and not a.attr&0x400
  identity=lambda i:(i.volume,i.index_high,i.index_low,i.created.dwHighDateTime,i.created.dwLowDateTime,i.written.dwHighDateTime,i.written.dwLowDateTime)
  data=ctypes.create_string_buffer(1);count=w.DWORD();assert k.ReadFile(handle,data,1,ctypes.byref(count),None) and count.value==0
  inactive();b=Info();assert k.GetFileInformationByHandle(handle,ctypes.byref(b)) and identity(a)==identity(b) and b.size_high==b.size_low==0
  disposition=Disposition(True);assert k.SetFileInformationByHandle(handle,4,ctypes.byref(disposition),ctypes.sizeof(disposition)),ctypes.get_last_error()
 finally:k.CloseHandle(handle)
 assert not path.exists()
 assert hashlib.sha256(index.read_bytes()).hexdigest()==index_before,'Index changed during empty lock recovery'
 print('OWN_FAILED_EMPTY_LOCK_RECOVERED',expected_utc,flush=True)

if __name__=='__main__':
 with exclusive('git'):
  recovery=[arg.split('=',1)[1] for arg in sys.argv[1:] if arg.startswith('--recover-own-empty-lock=')]
  assert len(recovery)<=1
  if recovery:recover_own_empty_lock(recovery[0])
  prior=git('diff','--cached','--name-only').decode().splitlines()
  own_prefixes=[SOURCE.relative_to(ROOT).as_posix(),'art/animation/source/fluid/'+UID]
  own_files=['.gitattributes','content/unit_animation_manifest.json','art/overworld/creature_idle.json','art/animation/runtime/fluid/'+UID+'.png','art/animation/runtime/fluid/'+UID+'.png.import','art/overworld/runtime/creature_idle/'+UID+'.png','art/overworld/runtime/creature_idle/'+UID+'.png.import']
  if prior:
   assert '--resume-own-index' in sys.argv[1:] and all(path in own_files or any(path.startswith(prefix+'/') for prefix in own_prefixes) for path in prior),'Shared index includes unknown work; preserve it'
  assert git('branch','--show-current').decode().strip()=='main','Existing checkout must be main'
  if '--commit-own-staged' in sys.argv[1:]:
   assert prior and '--resume-own-index' in sys.argv[1:]
   git('add','--',SOURCE.relative_to(ROOT).as_posix()+'/commit_unit.py')
   staged=git('diff','--cached','--name-only').decode().splitlines()
   assert all(path in own_files or any(path.startswith(prefix+'/') for prefix in own_prefixes) for path in staged)
   assert all('__pycache__' not in Path(path).parts and not path.endswith('.pyc') for path in staged)
   for path in staged:
    if any(path.startswith(prefix+'/') for prefix in own_prefixes):assert git('show',':'+path)==(ROOT/path).read_bytes(),path
   for path,key in [('content/unit_animation_manifest.json','items'),('art/overworld/creature_idle.json','units')]:
    head=json.loads(git('show','HEAD:'+path));indexed=json.loads(git('show',':'+path));live=json.loads((ROOT/path).read_bytes())
    if key=='items':
     assert [r for r in head[key] if r['unit_id']!=UID]==[r for r in indexed[key] if r['unit_id']!=UID]
     assert next(r for r in indexed[key] if r['unit_id']==UID)==next(r for r in live[key] if r['unit_id']==UID)
    else:
     assert {k:v for k,v in head[key].items() if k!=UID}=={k:v for k,v in indexed[key].items() if k!=UID}
     assert indexed[key][UID]==live[key][UID]
   expected=git('show','HEAD:.gitattributes')
   for rule in [SOURCE.relative_to(ROOT).as_posix()+'/** -text','art/animation/source/fluid/'+UID+'/*.json -text']:
    if rule.encode() not in expected.splitlines():expected+=b'\n'+rule.encode()+b'\n'
   assert git('show',':.gitattributes')==expected
   lock=ROOT/'.git/index.lock'
   if lock.exists():recover_own_empty_lock(time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime(lock.stat().st_mtime)))
   git('-c','user.name=AcorpBG','-c','user.email=10956556+AcorpBG@users.noreply.github.com','commit','--quiet','-m','Animate Hearthseed Slinger battle actions from original H3 sources')
   sha=git('rev-parse','HEAD').decode().strip();print('COMMITTED',sha,len(staged),'paths',flush=True)
   git('-c','http.version=HTTP/1.1','-c','http.postBuffer=1073741824','push','origin','main');print('PUSHED',sha,flush=True)
   raise SystemExit(0)
  rules=[SOURCE.relative_to(ROOT).as_posix()+'/** -text','art/animation/source/fluid/'+UID+'/*.json -text']
  work=ROOT/'.gitattributes';text=work.read_bytes()
  for rule in rules:
   if rule.encode() not in text.splitlines():text+=b'\n'+rule.encode()+b'\n'
  work.write_bytes(text)
  head=git('show','HEAD:.gitattributes')
  for rule in rules:
   if rule.encode() not in head.splitlines():head+=b'\n'+rule.encode()+b'\n'
  index_blob('.gitattributes',head)
  paths=[SOURCE.relative_to(ROOT).as_posix(),'art/animation/runtime/fluid/'+UID+'.png','art/animation/source/fluid/'+UID,'art/overworld/runtime/creature_idle/'+UID+'.png']
  for path in list(paths[1:2])+list(paths[3:]):
   if (ROOT/(path+'.import')).exists():paths.append(path+'.import')
  source_prefix=SOURCE.relative_to(ROOT).as_posix()
  ordinary=[path for path in paths if not path.endswith('.import')]
  imports=[path for path in paths if path.endswith('.import')]
  git('add','--',*ordinary,':(glob,exclude)'+source_prefix+'/**/__pycache__/**',':(glob,exclude)'+source_prefix+'/**/*.pyc')
  if imports:git('add','-f','--',*imports)
  for path,key in [('content/unit_animation_manifest.json','items'),('art/overworld/creature_idle.json','units')]:
   base=json.loads(git('show','HEAD:'+path));live=json.loads((ROOT/path).read_bytes())
   if key=='items':
    before=[r for r in base[key] if r['unit_id']!=UID];own=next(r for r in live[key] if r['unit_id']==UID);base[key]=[own if r['unit_id']==UID else r for r in base[key]];assert before==[r for r in base[key] if r['unit_id']!=UID]
   else:
    before={k:v for k,v in base[key].items() if k!=UID};base[key][UID]=live[key][UID];assert before=={k:v for k,v in base[key].items() if k!=UID}
   index_blob(path,(json.dumps(base,separators=(',',':'))+'\n').encode())
  staged=git('diff','--cached','--name-only').decode().splitlines()
  assert all('__pycache__' not in Path(path).parts and not path.endswith('.pyc') for path in staged),'Preserve caches without committing them'
  allowed=lambda p:p in ['.gitattributes','content/unit_animation_manifest.json','art/overworld/creature_idle.json'] or any(p==x or p.startswith(x+'/') for x in paths)
  assert staged and all(allowed(path) for path in staged),staged
  for path in staged:
   if path.startswith(SOURCE.relative_to(ROOT).as_posix()+'/') or path.startswith('art/animation/source/fluid/'+UID+'/'):
    assert git('show',':'+path)==(ROOT/path).read_bytes(),path+' indexed bytes'
  git('-c','user.name=AcorpBG','-c','user.email=10956556+AcorpBG@users.noreply.github.com','commit','--quiet','-m','Animate Hearthseed Slinger battle actions from original H3 sources')
  sha=git('rev-parse','HEAD').decode().strip();print('COMMITTED',sha,len(staged),'paths',flush=True)
  git('-c','http.version=HTTP/1.1','-c','http.postBuffer=1073741824','push','origin','main');print('PUSHED',sha,flush=True)
