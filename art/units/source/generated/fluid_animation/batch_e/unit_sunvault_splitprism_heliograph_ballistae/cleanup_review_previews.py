"""Delete only this worker's rebuildable, completed-review preview files."""
import json
import re
import produce as p

TAKES=['move_h3_v1','move_h3_v2','ranged_h3_v1','ranged_h3_v2','attack_h3_v1','hit_h3_v1','defend_h3_v1','cast_h3_v1','hit_h3_v2','death_h3_v1','defend_h3_v2','cast_h3_v2','move_h3_v3','death_h3_v2','move_h3_v4','cast_h3_v3','move_h3_v5']
PATTERN=re.compile(r'(?:chronological_[01]|original_rgb_0[0-7]|wheel_rgb_0[0-7]|enlarged_rgba_0[0-7]|native128_reflected[01]_[0-3]|critical_rgb_(?:59|60|90|91))\.png|review_inventory\.json')


def main():
    root=(p.ROOT/'.artifacts/heliograph_ballista_h3').resolve()
    targets=[];protected={}
    # Command-line/process check is performed by the coordinator before this
    # operation. Active source-generation takes are excluded from TAKES.
    initial=json.loads((p.SOURCE_DIR/'initial_pair_review.json').read_bytes())
    for take in TAKES:
        source=p.SOURCE_DIR/take
        if take in ['move_h3_v1','ranged_h3_v1']:
            assert initial[take]['status'].startswith('rejected')
        else:
            assert json.loads((source/'visual_review.json').read_bytes())['status'] in {'qualified_source_pending_runtime','rejected_at_original_RGB_review','rejected_at_original_transition_review'}
        rec=json.loads((source/'original.json').read_bytes())
        original=source/'original_lossless.mkv'
        assert p.sha(original)==rec['sha256']
        protected[original]=rec['sha256']
        matte=json.loads((source/'matte.json').read_bytes())
        for i,digest in enumerate(matte['rgba_sha256']):
            file=source/'matte'/f'rgba_{i:03}.png'
            assert p.sha(file)==digest
            protected[file]=digest
        directory=root/take
        assert directory.resolve().parent==root and not directory.is_symlink()
        if not directory.exists():continue
        for file in directory.iterdir():
            assert not file.is_symlink()
            if file.is_file() and PATTERN.fullmatch(file.name):
                assert file.resolve().parent==directory.resolve()
                targets.append((file,file.stat().st_size,p.sha(file)))
    total=sum(size for _,size,_ in targets)
    for file,size,digest in targets:
        assert file.stat().st_size==size and p.sha(file)==digest
        file.unlink()
    for take in TAKES:
        directory=root/take
        if directory.exists() and not list(directory.iterdir()):directory.rmdir()
    for file,digest in protected.items():assert file.is_file() and p.sha(file)==digest
    print(json.dumps(dict(removed_files=len(targets),recovered_bytes=total,protected_source_files=len(protected),rebuildable_by='produce.py review and inspect_sources.py',preserved='All original videos,latents,124 mattes/take,guides,prompts,provenance,caches and unrelated data; active source-generation takes excluded.')),flush=True)


if __name__=='__main__':main()
