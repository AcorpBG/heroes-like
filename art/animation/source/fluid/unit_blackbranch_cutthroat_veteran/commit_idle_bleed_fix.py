"""Commit the completed Blackbranch extraction correction with own-UID rows."""
from pathlib import Path
import hashlib,json,os,subprocess,sys,time
import repair_idle_grid_bleed as p
from creature_animation_lock import exclusive
UID=p.UID
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


if __name__=='__main__':
    validation=json.loads((p.SOURCE/'idle_bleed_fix_validation.json').read_bytes())
    assert validation['status']=='personally_reviewed_current_live_both_facings'
    assert not validation['failures'] and validation['changed_atlas_pixels']==57
    shared=['content/unit_animation_manifest.json','art/overworld/creature_idle.json']
    rasters=['art/animation/runtime/fluid/'+UID+'.png','art/overworld/runtime/creature_idle/'+UID+'.png']
    for path in rasters:
        assert hashlib.sha256((p.ROOT/path).read_bytes()).hexdigest()==validation['hashes'][path]
    source=p.SOURCE.relative_to(p.ROOT).as_posix()
    source_files=['provenance.json','reviewed_handoff.json','provenance_before_idle_bleed_fix.json','reviewed_handoff_before_idle_bleed_fix.json','idle_bleed_fixed_handoff.json','idle_bleed_fix_validation.json','repair_idle_grid_bleed.py','import_and_review.py','review_candidate.py','commit_idle_bleed_fix.py']
    own=[*[source+'/'+name for name in source_files],*rasters,'tools/review_upgraded_creature_completion.py']
    attrs_lines=[source+'/'+name+' -text' for name in source_files if name.endswith('.json')]
    sidecars=[path+'.import' for path in rasters]
    with exclusive('content'):
        own_rows={}
        for path in shared:
            data=json.loads((p.ROOT/path).read_bytes())
            own_rows[path]=next(r for r in data['items'] if r['unit_id']==UID) if path.startswith('content/') else data['units'][UID]
    with exclusive('git'):
        # Foreign staging remains untouched; refuse to mutate that transaction.
        assert not git('diff','--cached','--name-only').strip(),'Foreign staging is present; preserved'
        recover_empty_lock()
        git('fetch','origin','main')
        assert git('rev-parse','HEAD').strip()==git('rev-parse','origin/main').strip(),'Reconcile remote without overwriting working edits'
        head_attrs=git('show','HEAD:.gitattributes').decode()
        working_attrs=(p.ROOT/'.gitattributes').read_text()
        for attrs_line in attrs_lines:
            if attrs_line not in head_attrs.splitlines():head_attrs=head_attrs.rstrip()+'\n'+attrs_line+'\n'
            if attrs_line not in working_attrs.splitlines():working_attrs=working_attrs.rstrip()+'\n'+attrs_line+'\n'
        (p.ROOT/'.gitattributes').write_text(working_attrs)
        indexed('.gitattributes',head_attrs.encode())
        for path in shared:
            head=json.loads(git('show','HEAD:'+path))
            if path.startswith('content/'):
                before=[r for r in head['items'] if r['unit_id']!=UID]
                head['items']=[own_rows[path] if r['unit_id']==UID else r for r in head['items']]
                assert [r for r in head['items'] if r['unit_id']!=UID]==before
            else:
                before={k:v for k,v in head['units'].items() if k!=UID}
                head['units'][UID]=own_rows[path]
                assert {k:v for k,v in head['units'].items() if k!=UID}==before
            indexed(path,json_bytes(head,path.startswith('content/')))
        git('add','--',*own,':(exclude)**/__pycache__/**',':(exclude)**/*.pyc')
        git('add','-f','--',*sidecars)
        staged=git('diff','--cached','--name-only').decode().splitlines()
        assert all(path in shared+sidecars+own+['.gitattributes'] for path in staged),staged
        assert not any('__pycache__' in path or path.endswith('.pyc') for path in staged)
        git('-c','user.name=AcorpBG','-c','user.email=10956556+AcorpBG@users.noreply.github.com','commit','--quiet','-m','Fix Blackbranch idle extraction and add focused upgrade review')
        commit=git('rev-parse','HEAD').decode().strip();print('COMMIT',commit,flush=True)
        git('-c','http.version=HTTP/1.1','push','origin','main')
        assert not git('diff','--cached','--name-only').strip()
        assert git('rev-parse','HEAD').strip()==git('ls-remote','origin','refs/heads/main').split()[0]
        print('PUSHED',commit,flush=True)
