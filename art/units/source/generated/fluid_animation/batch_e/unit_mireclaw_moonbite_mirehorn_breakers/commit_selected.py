"""Commit/push only this unit, preserving a shared dirty tree and index."""
import hashlib,json,subprocess,time,os
os.environ["GIT_OPTIONAL_LOCKS"]="0"
from pathlib import Path
import produce as p
from creature_animation_lock import exclusive
UID='unit_mireclaw_moonbite_mirehorn_breakers'
ATTR=f'art/units/source/generated/fluid_animation/batch_e/{UID}/** -text\nart/animation/source/fluid/{UID}/*.json -text\n'
def git(*args,input=None):
 for attempt in range(5):
  result=subprocess.run(['git','-c','gc.auto=0','-c','maintenance.auto=false','-c','user.name=AcorpBG','-c','user.email=10956556+AcorpBG@users.noreply.github.com',*args],cwd=p.ROOT,input=input,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
  if result.returncode==0:return result.stdout
  if result.returncode==128 and b'index.lock' in result.stderr and attempt<4:
   from recover_empty_git_lock import recover_empty_lock
   recover_empty_lock();continue
  print(result.stderr.decode(errors='replace'),flush=True);result.check_returncode()

def blob(path,raw):
 digest=git('hash-object','-w','--stdin',input=raw).decode().strip();git('update-index','--add','--cacheinfo',f'100644,{digest},{path}');assert git('show',':'+path)==raw
 return digest

if __name__=='__main__':
 assert json.loads((p.SOURCE_DIR/'completion.json').read_bytes())['status']=='complete_selected_unit'
 with exclusive('git'):
  assert git('branch','--show-current').decode().strip()=='main'
  assert not git('diff','--cached','--name-only').strip(),'Shared index is occupied; wait, never reset it'
  attrs=p.ROOT/'.gitattributes';current=attrs.read_text();attrs.write_text(current+('\n' if current and not current.endswith('\n') else '')+ATTR) if ATTR not in current else None
  headattr=git('show','HEAD:.gitattributes');indexedattr=headattr+(b'\n' if headattr and not headattr.endswith(b'\n') else b'')+ATTR.encode() if ATTR.encode() not in headattr else headattr
  blob('.gitattributes',indexedattr)
  selected=[p.SOURCE_DIR.relative_to(p.ROOT).as_posix(),f'art/animation/source/fluid/{UID}',f'art/animation/runtime/fluid/{UID}.png',f'art/overworld/runtime/creature_idle/{UID}.png']
  git('add','--',*selected)
  for path,key in [('content/unit_animation_manifest.json','items'),('art/overworld/creature_idle.json','units')]:
   head=json.loads(git('show','HEAD:'+path));live=json.loads((p.ROOT/path).read_bytes())
   if key=='items':
    own=next(r for r in live[key] if r['unit_id']==UID);before=[r for r in head[key] if r['unit_id']!=UID]
    head[key]=[own if r['unit_id']==UID else r for r in head[key]];assert [r for r in head[key] if r['unit_id']!=UID]==before
   else:
    before={k:v for k,v in head[key].items() if k!=UID};head[key][UID]=live[key][UID];assert {k:v for k,v in head[key].items() if k!=UID}==before
   raw=(json.dumps(head,separators=(',',':'))+'\n').encode() if key=='items' else (json.dumps(head,indent=2)+'\n').encode();blob(path,raw)
  staged=git('diff','--cached','--name-only').decode().splitlines()
  assert not any('__pycache__' in f or f.endswith('.pyc') for f in staged),'Generated caches must remain local'
  allowed=['.gitattributes','content/unit_animation_manifest.json','art/overworld/creature_idle.json',*selected]
  assert all(any(f==x or f.startswith(x+'/') for x in allowed) for f in staged),staged
  for f in staged:
   if f not in ['.gitattributes','content/unit_animation_manifest.json','art/overworld/creature_idle.json']:
    assert git('show',':'+f)==(p.ROOT/f).read_bytes(),f
  git('commit','--quiet','-m','Complete Mirehorn Breakers original H3 action animations')
  sha=git('rev-parse','HEAD').decode().strip();print('COMMIT',sha,flush=True)
  git('-c','http.version=HTTP/1.1','-c','http.postBuffer=1073741824','push','origin','main');print('PUSHED',sha,flush=True)
  assert not git('diff','--cached','--name-only').strip()
  print(git('status','--short').decode(),flush=True)
