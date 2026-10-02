"""Remove only verified own duplicates and completed disposable review files."""
import hashlib,json,subprocess
from pathlib import Path
import numpy as np
from PIL import Image
import produce as p

UID='unit_neutral_quenchbell_ironbacks'
OUT=p.ROOT/'.artifacts/parallel_animation_20261002'/UID
REVIEW=p.ROOT/'.artifacts/quenchbell_ironback_h3'
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
        if UID in line and any(name in line for name in ['run_remaining.py','run_actions.py','run_generation.py','stage_video.py','segment.py','run_candidate_review.py','run_native_review.py','run_mirrored_native.py','run_live_review.py','verify_imported_atlas.gd']):
            raise RuntimeError(f"Own source/render process still active: {proc['ProcessId']}")
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
        duplicate=COMFY/'output/quenchbell_ironback_h3'/take.name
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
                file=COMFY/'input'/f'quenchbell_ironback_{take.name}_guide_{i}.png'
                if file.exists():
                    assert p.sha(file)==guide['input_sha256']
                    targets[safe_file(file,COMFY/'input')]='verified_uploaded_duplicate'
    for directory in [OUT,REVIEW]:
        if directory.exists():
            assert directory.resolve().is_relative_to((p.ROOT/'.artifacts').resolve())
            for file in directory.rglob('*'):
                if file.is_file() and '__pycache__' not in file.parts:
                    targets[safe_file(file,directory)]='disposable_review'
    # Only this coordinator's completed CPU helpers, never shared worker tools.
    common=p.ROOT/'.artifacts/parallel_animation_20261002'
    for name in ['ironback_review_cpu.py','ironback_select_cpu.py','ironback_partial_candidate.py','ironback_native_cpu.py']:
        file=common/name
        if file.exists():
            assert not any(name in (proc.get('CommandLine') or '') for proc in processes),name
            targets[safe_file(file,common)]='disposable_review_helper'
    removed={};sizes={}
    for file,kind in targets.items():
        size=file.stat().st_size;file.unlink();removed[kind]=removed.get(kind,0)+1;sizes[kind]=sizes.get(kind,0)+size
    result=dict(files_removed_by_kind=removed,bytes_removed_by_kind=sizes,recovered_bytes=sum(sizes.values()),retained_original_rgb_frames=rgb_count,original_videos_latents_guides_prompts_and_provenance_preserved=True,caches_preserved=True,rebuildable=True)
    record['cleanup']=result;p.write(p.SOURCE_DIR/'completion.json',record)
    print(json.dumps(result,indent=2))

if __name__=='__main__':cleanup()
