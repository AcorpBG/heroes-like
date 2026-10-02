"""Remove only verified own duplicates and completed disposable review files."""
import hashlib,json,subprocess,os,urllib.request
from pathlib import Path
import numpy as np
from PIL import Image
import produce as p

UID='unit_neutral_noonshard_prism_kites'
OUT=p.ROOT/'.artifacts/parallel_animation_20261002'/UID
REVIEW=p.ROOT/'.artifacts/noonshard_prism_kite_h3'
COMFY=Path('H:/ai/minimax-h3/ComfyUI')

def safe_file(file,root):
    file=file.resolve();root=root.resolve()
    assert file.is_relative_to(root) and file!=root and file.is_file(),file
    assert not file.is_symlink(),file
    return file

def cleanup():
    record=json.loads((p.SOURCE_DIR/'completion.json').read_bytes())
    assert record['status']=='complete_selected_unit' and not record['validation']['failures']
    # Ask Windows about actual own child processes before deleting artifacts.
    command="$ErrorActionPreference='Stop'; Get-CimInstance Win32_Process | Select-Object ProcessId,CommandLine | ConvertTo-Json -Compress"
    processes=json.loads(subprocess.check_output(['powershell','-NoProfile','-Command',command]))
    for proc in processes:
        line=proc.get('CommandLine') or ''
        if UID in line and any(name in line for name in ['run_remaining.py','run_actions.py','run_generation.py','stage_video.py','segment.py','inspect_sources.py','run_candidate_review.py','run_native_review.py','run_mirrored_native.py','run_ranged_native.py','run_live_review.py','verify_imported_atlas.gd']):
            raise RuntimeError(f"Own source/render process still active: {proc['ProcessId']}")
    # Foreign production can continue: prove only that no active or pending
    # Comfy graph references this unit's exact source/upload/output prefix.
    with urllib.request.urlopen(p.URL+'/queue',timeout=30) as response:
        queue=json.load(response)
    for job in queue['queue_running']+queue['queue_pending']:
        assert 'noonshard_prism_kite' not in json.dumps(job).lower(), 'Own source graph still active'
    selected={Path(f['source']).resolve() if Path(f['source']).is_absolute() else (p.ROOT/f['source']).resolve() for f in json.loads((p.SOURCE_DIR/'handoff.json').read_bytes())['units'][0]['frames']}
    targets={};rgb_count=0
    for take in sorted(p.SOURCE_DIR.glob('*_h3_v*')):
        if not (take/'original.json').exists():continue
        original=json.loads((take/'original.json').read_bytes());rgb_count+=original['frames']
        for variant in ['matte','edge_matte']:
            matte=json.loads((take/(variant+'.json')).read_bytes()) if (take/(variant+'.json')).exists() else None
            if not matte:continue
            for file in (take/variant).glob('rgba_*.png'):
                i=int(file.stem.split('_')[-1])
                if file.resolve() not in selected:
                    assert p.sha(file)==matte['rgba_sha256'][i]
                    targets[safe_file(file,take/variant)]='unselected_rebuildable_matte'
        history=json.loads((take/'generation_history.json').read_bytes())
        saved_frames={(COMFY/'output'/item.get('subfolder','')/item['filename']).resolve():i for i,item in enumerate(history['outputs']['15']['images'])}
        duplicate=COMFY/'output/noonshard_prism_kite_h3'/take.name
        if duplicate.exists():
            for file in duplicate.rglob('*'):
                if not file.is_file():continue
                if file.suffix=='.png':
                    assert file.resolve() in saved_frames,file
                    i=saved_frames[file.resolve()]
                    rgb=Image.open(file).convert('RGB')
                    assert hashlib.sha256(rgb.tobytes()).hexdigest()==original['decoded_rgb_sha256'][i],file
                elif file.suffix=='.mp4':assert p.sha(file)==p.sha(take/'original.mp4')
                elif file.suffix in ['.latent','.safetensors']:assert p.sha(file)==p.sha(take/'original.latent')
                else:continue
                targets[safe_file(file,duplicate)]='verified_comfy_duplicate'
        if (take/'reference.json').exists():
            for i,guide in enumerate(json.loads((take/'reference.json').read_bytes())['guides']):
                file=COMFY/'input'/f'noonshard_prism_kite_{take.name}_guide_{i}.png'
                if file.exists():
                    assert p.sha(file)==guide['input_sha256']
                    targets[safe_file(file,COMFY/'input')]='verified_uploaded_duplicate'
    for directory in [OUT,REVIEW]:
        if directory.exists():
            assert directory.resolve().is_relative_to((p.ROOT/'.artifacts').resolve())
            for file in directory.rglob('*'):
                if file.is_file() and '__pycache__' not in file.parts:
                    targets[safe_file(file,directory)]='disposable_review'
    # These four pre-registration views duplicate authored source paintings;
    # final registered input guides and their exact provenance remain intact.
    for index in [16,0,2,3]:
        file=p.SOURCE_DIR/f'registration_original_{index}.png'
        if file.exists():targets[safe_file(file,p.SOURCE_DIR)]='disposable_registration_view'
    # Only this coordinator's completed CPU helpers, never shared worker tools.
    common=p.ROOT/'.artifacts/parallel_animation_20261002'
    for name in ['noonshard_review_cpu.py','noonshard_select_cpu.py','noonshard_partial_candidate.py','noonshard_native_cpu.py']:
        file=common/name
        if file.exists():
            assert not any(name in (proc.get('CommandLine') or '') for proc in processes),name
            targets[safe_file(file,common)]='disposable_review_helper'
    removed={};sizes={}
    for file,kind in targets.items():
        if os.name=='nt':
            import ctypes
            from ctypes import wintypes
            kernel=ctypes.WinDLL('kernel32',use_last_error=True)
            kernel.CreateFileW.argtypes=[wintypes.LPCWSTR,wintypes.DWORD,wintypes.DWORD,ctypes.c_void_p,wintypes.DWORD,wintypes.DWORD,wintypes.HANDLE]
            kernel.CreateFileW.restype=wintypes.HANDLE
            kernel.CloseHandle.argtypes=[wintypes.HANDLE]
            kernel.CloseHandle.restype=wintypes.BOOL
            handle=kernel.CreateFileW(str(file),0x80000000,0,None,3,0x80,None)
            if handle==ctypes.c_void_p(-1).value:
                raise RuntimeError(f'File is in use or inaccessible: {file}; Windows error{ctypes.get_last_error()}')
            assert kernel.CloseHandle(handle)
        size=file.stat().st_size;file.unlink();removed[kind]=removed.get(kind,0)+1;sizes[kind]=sizes.get(kind,0)+size
    result=dict(files_removed_by_kind=removed,bytes_removed_by_kind=sizes,recovered_bytes=sum(sizes.values()),retained_original_rgb_frames=rgb_count,original_videos_latents_guides_prompts_and_provenance_preserved=True,caches_preserved=True,rebuildable=True)
    record['cleanup']=result;p.write(p.SOURCE_DIR/'completion.json',record)
    print(json.dumps(result,indent=2))

if __name__=='__main__':cleanup()
