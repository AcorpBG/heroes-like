"""Isolated main-branch commit, preserving other workers' live catalog rows."""
import hashlib,json,subprocess,sys,time
import produce as p
from creature_animation_lock import exclusive
UID='unit_mireclaw_moonbite_votive_drummers'
def git(*args,input=None):
 deadline=time.monotonic()+30
 while True:
  r=subprocess.run(['git','-c','gc.auto=0','-c','maintenance.auto=false',*args],input=input,stdout=subprocess.PIPE,stderr=subprocess.PIPE,cwd=p.ROOT)
  # Read-only GUI/status refresh can briefly own Git's index lock outside the
  # production mutex. Wait for natural release; never remove another lock.
  if not (r.returncode and b'index.lock' in r.stderr and b'File exists' in r.stderr and time.monotonic()<deadline):break
  time.sleep(.25)
 if r.returncode:
  sys.stderr.buffer.write(r.stderr);sys.stderr.flush();r.check_returncode()
 return r.stdout
def blob(path,data):
 oid=git('hash-object','-w','--stdin',input=data).decode().strip();git('update-index','--add','--cacheinfo','100644',oid,path)
 assert git('show',':'+path)==data
def run():
 with exclusive('git'):
  assert git('branch','--show-current').decode().strip()=='main'
  assert not git('diff','--cached','--name-only').strip(),'Foreign staged work exists; leave index untouched'
  source=p.SOURCE_DIR.relative_to(p.ROOT).as_posix();runtime=f'art/animation/runtime/fluid/{UID}.png';provenance=f'art/animation/source/fluid/{UID}';mapstrip=f'art/overworld/runtime/creature_idle/{UID}.png'
  paths=[source,runtime,provenance,mapstrip]
  # Generated import metadata is ignored by the repository; include it only
  # if this unit already has a tracked import configuration.
  if git('ls-files','--',runtime+'.import').strip():paths.append(runtime+'.import')
  # Append only this worker's rules to working attrs, but index HEAD plus ours.
  head=git('show','HEAD:.gitattributes');rules=[f'{source}/** -text',f'{provenance}/*.json -text']
  working=(p.ROOT/'.gitattributes').read_bytes()
  for rule in rules:
   encoded=rule.encode()
   if encoded not in working.splitlines():working=working.rstrip(b'\r\n')+b'\n'+encoded+b'\n'
   if encoded not in head.splitlines():head=head.rstrip(b'\r\n')+b'\n'+encoded+b'\n'
  (p.ROOT/'.gitattributes').write_bytes(working);blob('.gitattributes',head)
  # Preserve task-created Python caches without adding them as production art.
  git('add','--',*paths,':(exclude)'+source+'/__pycache__/**')
  for path,key in [('content/unit_animation_manifest.json','items'),('art/overworld/creature_idle.json','units')]:
   old=json.loads(git('show','HEAD:'+path));working=json.loads((p.ROOT/path).read_bytes());new=json.loads(json.dumps(old))
   if key=='items':
    selected=next(r for r in working[key] if r['unit_id']==UID);index=next(i for i,r in enumerate(new[key]) if r['unit_id']==UID);new[key][index]=selected
    assert [r for r in old[key] if r['unit_id']!=UID]==[r for r in new[key] if r['unit_id']!=UID]
   else:
    new[key][UID]=working[key][UID];assert {k:v for k,v in old[key].items() if k!=UID}=={k:v for k,v in new[key].items() if k!=UID}
   data=(json.dumps(new,separators=(',',':'))+'\n').encode() if key=='items' else (json.dumps(new,indent=2)+'\n').encode();blob(path,data)
  staged=git('diff','--cached','--name-only').decode().splitlines()
  allowed=paths+['.gitattributes','content/unit_animation_manifest.json','art/overworld/creature_idle.json']
  assert all(any(f==a or f.startswith(a+'/') for a in allowed) for f in staged),staged
  assert not any('/__pycache__/' in f or f.endswith('.pyc') for f in staged)
  for f in staged:
   if f in ['.gitattributes','content/unit_animation_manifest.json','art/overworld/creature_idle.json']:continue
   assert hashlib.sha256(git('show',':'+f)).digest()==hashlib.sha256((p.ROOT/f).read_bytes()).digest(),f
  git('-c','user.name=AcorpBG','-c','user.email=10956556+AcorpBG@users.noreply.github.com','commit','--quiet','-m','Complete Moonbite Votive Drummers original H3 battle animations')
  commit=git('rev-parse','HEAD').decode().strip();print('COMMITTED',commit,flush=True)
  git('-c','http.version=HTTP/1.1','-c','http.postBuffer=1073741824','push','origin','main');print('PUSHED',commit,flush=True)
if __name__=='__main__':run()
