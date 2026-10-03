"""Stage/push only this completed unit, preserving concurrent working rows."""
import json,subprocess,hashlib,re,os,time
import produce as p
from creature_animation_lock import exclusive

UID='unit_neutral_fenmirror_gallowshells'
def recover_empty_lock():
    before=hashlib.sha256((p.ROOT/'.git/index').read_bytes()).hexdigest()
    lock=p.ROOT/'.git/index.lock'
    if lock.exists():
        # Delete only an empty orphan through the exclusively held handle.
        # A nonempty recovery file is never disposable; preserve it.
        import ctypes
        from ctypes import wintypes
        def no_active_git():
            command="@(Get-CimInstance Win32_Process | Where-Object {$_.Name -match '^git(?:-.*)?\\.exe$'}).Count"
            # Desktop status readers can briefly run between the two
            # ownership checks. Wait for observed idle; never stop them or
            # delete a nonempty/actively held lock.
            deadline=time.monotonic()+45
            while True:
                active=int(subprocess.check_output(['powershell','-NoProfile','-Command',command]).strip())
                if active==0:return
                assert time.monotonic()<deadline, 'Git still active; lock preserved'
                time.sleep(.5)
        no_active_git()
        kernel=ctypes.WinDLL('kernel32',use_last_error=True)
        kernel.CreateFileW.argtypes=[wintypes.LPCWSTR,wintypes.DWORD,wintypes.DWORD,ctypes.c_void_p,wintypes.DWORD,wintypes.DWORD,wintypes.HANDLE]
        kernel.CreateFileW.restype=wintypes.HANDLE
        kernel.GetFileSizeEx.argtypes=[wintypes.HANDLE,ctypes.POINTER(ctypes.c_longlong)]
        kernel.GetFileSizeEx.restype=wintypes.BOOL
        kernel.SetFileInformationByHandle.argtypes=[wintypes.HANDLE,ctypes.c_int,ctypes.c_void_p,wintypes.DWORD]
        kernel.SetFileInformationByHandle.restype=wintypes.BOOL
        kernel.CloseHandle.argtypes=[wintypes.HANDLE]
        kernel.CloseHandle.restype=wintypes.BOOL
        handle=kernel.CreateFileW(str(lock),0x80000000|0x10000,0,None,3,0x80,None)
        if handle==ctypes.c_void_p(-1).value:
            error=ctypes.get_last_error()
            # A GUI reader can naturally release its lock between exists()
            # and opening it. No file was opened or deleted in this race.
            if error==2 and not lock.exists():
                assert hashlib.sha256((p.ROOT/'.git/index').read_bytes()).hexdigest()==before,'Index changed while lock disappeared'
                return
        assert handle!=ctypes.c_void_p(-1).value, ('Orphan lock unavailable',ctypes.get_last_error())
        try:
            size=ctypes.c_longlong()
            assert kernel.GetFileSizeEx(handle,ctypes.byref(size))
            assert size.value==0, 'Nonempty lock preserved'
            no_active_git()
            delete=ctypes.c_ubyte(1)
            # FILE_INFO_BY_HANDLE_CLASS::FileDispositionInfo is 4.
            assert kernel.SetFileInformationByHandle(handle,4,ctypes.byref(delete),ctypes.sizeof(delete)),ctypes.get_last_error()
        finally:
            assert kernel.CloseHandle(handle)
    assert hashlib.sha256((p.ROOT/'.git/index').read_bytes()).hexdigest()==before,'Index changed during lock recovery'

def git(*args,input=None):
    for attempt in range(5):
        result=subprocess.run(['git','-c','gc.auto=0','-c','maintenance.auto=false',*args],cwd=p.ROOT,env=dict(os.environ,GIT_OPTIONAL_LOCKS="0"),input=input,stdout=subprocess.PIPE,stderr=subprocess.PIPE,creationflags=subprocess.CREATE_NO_WINDOW if os.name=='nt' else 0)
        if result.returncode==0:return result.stdout
        # Only retry an index-lock error after our Git child fully exits.
        # Exact exclusive-handle, zero-size and two idle proofs remain required.
        if result.returncode==128 and b'index.lock' in result.stderr and attempt<4:
            recover_empty_lock();continue
        raise subprocess.CalledProcessError(result.returncode,result.args,result.stdout,result.stderr)

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
    notes=re.sub(r'COORDINATOR ACTIVE: Fenmirror Gallowshells[;,].*?(?=WORKER ACTIVE:|\| |$)','',notes)
    roster=completion['roster'];checks=completion['validation']['total']
    prefix=(f"SOLO COMPLETE: Fenmirror Gallowshells; {completion['new_selected_poses']} original H3 poses across six dedicated actions; "
            'preserve eight reviewed idle poses and exact map pixels/timing. '
            'Chronological/enlarged/native/reflected/live review, actual pincer-strike captures, '
            f'{checks} focused assertions plus source/anchor/import/map equality pass. '
            f"Roster{roster['complete']}/{roster['total']};{roster['remaining']} remain; broad goal in progress. | ")
    if not notes.startswith(prefix):notes=prefix+notes
    start,end=match.span(1)
    return text[:start]+json.dumps(notes,ensure_ascii=False)+text[end:]

if __name__=='__main__':
    completion=json.loads((p.SOURCE_DIR/'completion.json').read_bytes())
    assert completion['status']=='complete_selected_unit'
    assert not completion['validation']['failures']
    # Snapshot only this unit while a publisher cannot rewrite the catalogs.
    # Release content before Git: never nest shared locks across GPU or Git.
    shared=['content/unit_animation_manifest.json','art/overworld/creature_idle.json']
    progress='ops/progress.json'
    with exclusive('content'):
        own_rows={}
        for path in shared:
            current=json.loads((p.ROOT/path).read_bytes())
            own_rows[path]=(next(r for r in current['items'] if r['unit_id']==UID)
                            if path.startswith('content/') else current['units'][UID])
        current_progress=(p.ROOT/progress).read_bytes().decode()
        (p.ROOT/progress).write_bytes(completed_progress(current_progress,completion).encode())
    with exclusive('git'):
        staged_before=git('diff','--cached','--name-only').decode().splitlines()
        # Resume only an exact partial transaction from this helper. No reset,
        # checkout, stash or foreign-row staging is permitted.
        for path in staged_before:
            if path in shared:
                head=json.loads(git('show','HEAD:'+path))
                if path.startswith('content/'):
                    head['items']=[own_rows[path] if r['unit_id']==UID else r for r in head['items']]
                else:head['units'][UID]=own_rows[path]
                expected=json_bytes(head,path.startswith('content/'))
            elif path=='.gitattributes':
                head=git('show','HEAD:'+path).decode()
                for line in ['art/units/source/generated/fluid_animation/batch_e/'+UID+'/** -text','art/animation/source/fluid/'+UID+'/*.json -text']:
                    if line not in head.splitlines():head=head.rstrip()+'\n'+line+'\n'
                expected=head.encode()
            elif path==progress:
                expected=completed_progress(git('show','HEAD:'+path).decode(),completion).encode()
            else:
                allowed=[p.SOURCE_DIR.relative_to(p.ROOT).as_posix(),'art/animation/source/fluid/'+UID]
                rasters=['art/animation/runtime/fluid/'+UID+'.png','art/overworld/runtime/creature_idle/'+UID+'.png']
                assert any(path.startswith(folder+'/') for folder in allowed) or path in rasters+[r+'.import' for r in rasters], 'Foreign index entry preserved: '+path
                assert '__pycache__' not in path and not path.endswith('.pyc')
                expected=(p.ROOT/path).read_bytes()
            assert git('show',':'+path)==expected, 'Staging differs from own exact transaction: '+path

        recover_empty_lock()
        git('fetch','origin','main')
        assert git('rev-parse','HEAD').strip()==git('rev-parse','origin/main').strip(),'Reconcile remote before publishing'
        for path in shared:
            head=json.loads(git('show','HEAD:'+path))
            if path.startswith('content/'):
                own=own_rows[path]
                before=[r for r in head['items'] if r['unit_id']!=UID]
                head['items']=[own if r['unit_id']==UID else r for r in head['items']]
                assert [r for r in head['items'] if r['unit_id']!=UID]==before
            else:
                before={k:v for k,v in head['units'].items() if k!=UID}
                head['units'][UID]=own_rows[path]
                assert {k:v for k,v in head['units'].items() if k!=UID}==before
            indexed(path,json_bytes(head,path.startswith('content/')))
        attrs=['art/units/source/generated/fluid_animation/batch_e/'+UID+'/** -text','art/animation/source/fluid/'+UID+'/*.json -text']
        head=git('show','HEAD:.gitattributes').decode();working=(p.ROOT/'.gitattributes').read_text()
        for line in attrs:
            if line not in head.splitlines():head=head.rstrip()+'\n'+line+'\n'
            if line not in working.splitlines():working=working.rstrip()+'\n'+line+'\n'
        (p.ROOT/'.gitattributes').write_text(working)
        indexed('.gitattributes',head.encode())
        head_progress=git('show','HEAD:'+progress).decode()
        indexed(progress,completed_progress(head_progress,completion).encode())
        own=[p.SOURCE_DIR.relative_to(p.ROOT).as_posix(),'art/animation/runtime/fluid/'+UID+'.png','art/overworld/runtime/creature_idle/'+UID+'.png','art/animation/source/fluid/'+UID]
        # Retain generated Python caches locally without shipping them.
        # Directory pathspecs also honor normal ignored Godot import caches.
        git('add','--',*own,':(exclude)**/__pycache__/**',':(exclude)**/*.pyc')
        # Godot ignores sidecars globally, but these two lossless import recipes
        # are runtime deliverables. Force only their exact unit-owned paths;
        # retain normal ignores for generated caches and every other unit.
        sidecars=[path+'.import' for path in own if path.endswith('.png')]
        assert all((p.ROOT/path).is_file() for path in sidecars)
        git('add','-f','--',*sidecars)
        staged=git('diff','--cached','--name-only').decode().splitlines()
        assert all(path in shared+['.gitattributes',progress]+sidecars or any(path==a or path.startswith(a+'/') for a in own) for path in staged),staged
        assert not any('__pycache__' in path or path.endswith('.pyc') for path in staged)
        assert all((p.ROOT/path).stat().st_size<100*1024*1024 for path in staged if (p.ROOT/path).is_file()),'GitHub file limit'
        git('-c','user.name=AcorpBG','-c','user.email=10956556+AcorpBG@users.noreply.github.com','commit','--quiet','-m','Complete Fenmirror Gallowshell creature animations')
        commit=git('rev-parse','HEAD').decode().strip();print('COMMIT',commit,flush=True)
        git('-c','http.version=HTTP/1.1','-c','http.postBuffer=1073741824','push','origin','main')
        assert not git('diff','--cached','--name-only').strip()
        print('PUSHED',commit,flush=True)
