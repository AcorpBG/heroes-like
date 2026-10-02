"""Stage/push only this completed unit, preserving concurrent working rows."""
import json,subprocess,hashlib,re
import produce as p
from creature_animation_lock import exclusive

UID='unit_neutral_quenchbell_ironbacks'
def git(*args,input=None):
    result=subprocess.run(['git','-c','gc.auto=0','-c','maintenance.auto=false',*args],cwd=p.ROOT,input=input,stdout=subprocess.PIPE,stderr=subprocess.PIPE,check=True)
    return result.stdout
def indexed(path,data):
    sha=git('hash-object','-w','--stdin',input=data).decode().strip()
    git('update-index','--add','--cacheinfo','100644',sha,path)
    assert git('show',':'+path)==data,path
def json_bytes(data,compact=False):
    return (json.dumps(data,indent=None if compact else 2,separators=(',',':') if compact else None)+'\n').encode()

def completed_progress(text,completion):
    # Change only this selected slice's notes string. Preserve all unrelated
    # working tracker edits and do not reserialize the operations document.
    pattern=r'"id"\s*:\s*"art-fluid-creature-animation-20260923"[\s\S]*?"notes"\s*:\s*("(?:\\.|[^"\\])*")'
    match=re.search(pattern,text);assert match
    assert re.search(r'"status"\s*:\s*"in_progress"',match[0])
    notes=json.loads(match[1])
    notes=re.sub(r'^COORDINATOR ACTIVE: Quenchbell Ironbacks,[\s\S]*? \| ','',notes,count=1)
    roster=completion['roster'];checks=completion['validation']['total']
    prefix=('SOLO COMPLETE: Quenchbell Ironbacks; 203 original H3 poses across six dedicated actions; '
            'preserve eight reviewed idle poses and exact map pixels/timing. '
            'Chronological/enlarged/native/reflected/live review, actual ram captures, '
            f'{checks} focused assertions plus source/anchor/import/map equality pass. '
            f"Roster{roster['complete']}/{roster['total']};{roster['remaining']} remain; broad goal in progress. | ")
    if not notes.startswith(prefix):notes=prefix+notes
    start,end=match.span(1)
    return text[:start]+json.dumps(notes,ensure_ascii=False)+text[end:]

if __name__=='__main__':
    completion=json.loads((p.SOURCE_DIR/'completion.json').read_bytes())
    assert completion['status']=='complete_selected_unit'
    assert not completion['validation']['failures']
    with exclusive('git'):
        assert not git('diff','--cached','--name-only').strip(),'Concurrent index is occupied; do not reset it'
        lock=p.ROOT/'.git/index.lock'
        if lock.exists():
            # Remove only the known empty desktop leftover after proving no
            # Git process owns it and acquiring exclusive access to this file.
            command="$ErrorActionPreference='Stop'; $target='D:\\Games\\godot\\heroes-like\\.git\\index.lock'; if (@(Get-CimInstance Win32_Process | Where-Object {$_.Name -match '^git(?:-.*)?\\.exe$'}).Count -gt 0) {throw 'Git active'}; if ((Get-Item -LiteralPath $target).Length -ne 0) {throw 'Nonempty lock'}; $stream=[IO.File]::Open($target,[IO.FileMode]::Open,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None);$stream.Dispose();Remove-Item -LiteralPath $target"
            subprocess.run(['powershell','-NoProfile','-Command',command],check=True)
        git('fetch','origin','main')
        assert git('rev-parse','HEAD').strip()==git('rev-parse','origin/main').strip(),'Reconcile remote before publishing'
        shared=['content/unit_animation_manifest.json','art/overworld/creature_idle.json']
        for path in shared:
            head=json.loads(git('show','HEAD:'+path));current=json.loads((p.ROOT/path).read_bytes())
            if path.startswith('content/'):
                own=next(r for r in current['items'] if r['unit_id']==UID)
                before=[r for r in head['items'] if r['unit_id']!=UID]
                head['items']=[own if r['unit_id']==UID else r for r in head['items']]
                assert [r for r in head['items'] if r['unit_id']!=UID]==before
            else:
                before={k:v for k,v in head['units'].items() if k!=UID}
                head['units'][UID]=current['units'][UID]
                assert {k:v for k,v in head['units'].items() if k!=UID}==before
            indexed(path,json_bytes(head,path.startswith('content/')))
        attrs=['art/units/source/generated/fluid_animation/batch_e/'+UID+'/** -text','art/animation/source/fluid/'+UID+'/*.json -text']
        head=git('show','HEAD:.gitattributes').decode();working=(p.ROOT/'.gitattributes').read_text()
        for line in attrs:
            if line not in head.splitlines():head=head.rstrip()+'\n'+line+'\n'
            if line not in working.splitlines():working=working.rstrip()+'\n'+line+'\n'
        (p.ROOT/'.gitattributes').write_text(working)
        indexed('.gitattributes',head.encode())
        progress='ops/progress.json'
        head_progress=git('show','HEAD:'+progress).decode()
        current_progress=(p.ROOT/progress).read_bytes().decode()
        (p.ROOT/progress).write_bytes(completed_progress(current_progress,completion).encode())
        indexed(progress,completed_progress(head_progress,completion).encode())
        own=[p.SOURCE_DIR.relative_to(p.ROOT).as_posix(),'art/animation/runtime/fluid/'+UID+'.png','art/overworld/runtime/creature_idle/'+UID+'.png','art/animation/source/fluid/'+UID]
        git('add','--',*own)
        staged=git('diff','--cached','--name-only').decode().splitlines()
        assert all(path in shared+['.gitattributes',progress] or any(path==a or path.startswith(a+'/') for a in own) for path in staged),staged
        assert all((p.ROOT/path).stat().st_size<100*1024*1024 for path in staged if (p.ROOT/path).is_file()),'GitHub file limit'
        git('-c','user.name=AcorpBG','-c','user.email=10956556+AcorpBG@users.noreply.github.com','commit','--quiet','-m','Complete Quenchbell Ironback creature animations')
        commit=git('rev-parse','HEAD').decode().strip();print('COMMIT',commit,flush=True)
        git('-c','http.version=HTTP/1.1','-c','http.postBuffer=1073741824','push','origin','main')
        assert not git('diff','--cached','--name-only').strip()
        print('PUSHED',commit,flush=True)
