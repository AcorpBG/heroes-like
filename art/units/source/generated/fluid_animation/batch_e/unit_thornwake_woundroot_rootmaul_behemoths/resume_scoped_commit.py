"""Index only this UID against current HEAD; preserve the shared working tree."""
import json,subprocess,sys
from pathlib import Path
R=Path.cwd();UID='unit_thornwake_woundroot_rootmaul_behemoths';SOURCE='art/units/source/generated/fluid_animation/batch_e/'+UID
sys.path.insert(0,str(R/'tools'))
from creature_animation_lock import exclusive
def git(*args,input=None):
 import time
 for attempt in range(20):
  r=subprocess.run(['git','-c','gc.auto=0','-c','maintenance.auto=false',*args],input=input,capture_output=True)
  if r.returncode==0:return r.stdout
  message=r.stderr.decode(errors='replace')
  if 'index.lock' not in message or 'File exists' not in message:raise AssertionError(message+r.stdout.decode(errors='replace'))
  try:remove_empty_index_lock()
  except AssertionError as error:
   if 'Git active' not in str(error):raise
  time.sleep(1)
 raise AssertionError('Persistent index.lock contention; no foreign process interrupted')
def blob(path,data):
 value=git('hash-object','-w','--stdin',input=data).decode().strip();git('update-index','--add','--cacheinfo','100644',value,path);assert git('show',':'+path)==data

def remove_empty_index_lock():
 lock=R/'.git/index.lock'
 if not lock.exists():return
 from ctypes import WinDLL,Structure,c_ubyte,sizeof,byref,c_longlong,c_void_p,WinError
 from ctypes import wintypes
 check=subprocess.run(['powershell','-NoProfile','-Command',"if (@(Get-CimInstance Win32_Process | Where-Object {$_.Name -match '^git(?:-.*)?\\.exe$'}).Count -gt 0) {throw 'Git active'}"],capture_output=True)
 assert check.returncode==0,check.stderr.decode(errors='replace')
 k=WinDLL('kernel32',use_last_error=True)
 k.CreateFileW.argtypes=[wintypes.LPCWSTR,wintypes.DWORD,wintypes.DWORD,c_void_p,wintypes.DWORD,wintypes.DWORD,wintypes.HANDLE];k.CreateFileW.restype=wintypes.HANDLE
 k.GetFileSizeEx.argtypes=[wintypes.HANDLE,c_void_p];k.GetFileSizeEx.restype=wintypes.BOOL
 k.SetFileInformationByHandle.argtypes=[wintypes.HANDLE,wintypes.DWORD,c_void_p,wintypes.DWORD];k.SetFileInformationByHandle.restype=wintypes.BOOL
 k.CloseHandle.argtypes=[wintypes.HANDLE];k.CloseHandle.restype=wintypes.BOOL
 handle=k.CreateFileW(str(lock),0x80010000,0,None,3,0x80,None)
 if handle==c_void_p(-1).value:raise WinError()
 class Disposition(Structure):_fields_=[('DeleteFile',c_ubyte)]
 try:
  size=c_longlong()
  if not k.GetFileSizeEx(handle,byref(size)):raise WinError()
  assert size.value==0,'Nonempty lock; refuse deletion'
  disposition=Disposition(1)
  if not k.SetFileInformationByHandle(handle,4,byref(disposition),sizeof(disposition)):raise WinError()
 finally:k.CloseHandle(handle)
 assert not lock.exists(),'Index lock remains'


import time
SOURCE='art/units/source/generated/fluid_animation/batch_e/'+UID
with exclusive('git'):
 assert git('branch','--show-current').strip()==b'main'
 staged=git('diff','--cached','--name-only').decode().splitlines();assert staged,'Own staged index expected'
 allowed={'.gitattributes','content/unit_animation_manifest.json','art/overworld/creature_idle.json','art/animation/runtime/fluid/'+UID+'.png','art/overworld/runtime/creature_idle/'+UID+'.png'}
 assert all(x in allowed or x.startswith(SOURCE+'/') or x.startswith('art/animation/source/fluid/'+UID+'/') or x in {f+'.import' for f in allowed if f.endswith('.png')} for x in staged),staged
 completion=json.loads((R/SOURCE/'completion.json').read_bytes());assert completion['status']=='complete_selected_unit' and not completion['validation']['failures']
 git('add','--',SOURCE+'/commit_selected_unit.py',SOURCE+'/resume_scoped_commit.py')
 staged=git('diff','--cached','--name-only').decode().splitlines()
 assert all(x in allowed or x.startswith(SOURCE+'/') or x.startswith('art/animation/source/fluid/'+UID+'/') or x in {f+'.import' for f in allowed if f.endswith('.png')} for x in staged),staged
 for path in staged:
  if path.startswith(SOURCE+'/') or path.startswith('art/animation/source/fluid/'+UID+'/') or path in {f for f in allowed if f.endswith('.png')}:assert git('show',':'+path)==(R/path).read_bytes(),path
 for path in ['content/unit_animation_manifest.json','art/overworld/creature_idle.json']:
  head=json.loads(git('show','HEAD:'+path));index=json.loads(git('show',':'+path));working=json.loads((R/path).read_bytes())
  if path.startswith('content'):
   assert [x for x in index['items'] if x['unit_id']!=UID]==[x for x in head['items'] if x['unit_id']!=UID]
   assert next(x for x in index['items'] if x['unit_id']==UID)==next(x for x in working['items'] if x['unit_id']==UID)
  else:
   assert {k:v for k,v in index['units'].items() if k!=UID}=={k:v for k,v in head['units'].items() if k!=UID}
   assert index['units'][UID]==working['units'][UID]
 attrs=git('show','HEAD:.gitattributes').decode()
 for rule in [SOURCE+'/** -text','art/animation/source/fluid/'+UID+'/*.json -text']:
  if rule not in attrs:attrs+='\n'+rule
 assert git('show',':.gitattributes')==(attrs.rstrip()+'\n').encode()
 git('-c','core.whitespace=cr-at-eol','diff','--cached','--check')
 for attempt in range(30):
  try:remove_empty_index_lock();break
  except AssertionError as error:
   if 'Git active' not in str(error):raise
   time.sleep(1)
 else:raise AssertionError('Active Git never cleared; own stage retained, no process interrupted')
 git('-c','user.name=AcorpBG','-c','user.email=10956556+AcorpBG@users.noreply.github.com','commit','-q','-m','Animate original Rootmaul Behemoths battle actions')
 print('COMMIT',git('rev-parse','HEAD').decode().strip(),flush=True)
 result=subprocess.run(['git','-c','gc.auto=0','-c','maintenance.auto=false','-c','http.version=HTTP/1.1','-c','http.postBuffer=1073741824','push','origin','main']);assert result.returncode==0
 assert git('rev-parse','origin/main').strip()==git('rev-parse','HEAD').strip()
 print('PUSH_OK origin/main matches completed own HEAD',flush=True)
