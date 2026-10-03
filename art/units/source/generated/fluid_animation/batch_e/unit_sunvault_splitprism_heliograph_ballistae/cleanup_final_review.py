"""Remove only completed Heliograph review copies, preserving all masters/caches."""
import shutil
import json
import produce as p

def main():
    # Coordinator confirms no active owning process before invoking this.
    source=p.SOURCE_DIR.resolve()
    protected={f.resolve():p.sha(f) for f in source.rglob('*') if f.is_file()}
    roots=[p.ROOT/'.artifacts/heliograph_ballista_h3',
           p.ROOT/'.artifacts/parallel_animation_20261003'/source.name]
    handoff=json.loads((source/'handoff.json').read_bytes())['units'][0]
    assert all('.artifacts/' not in f['source'] for f in handoff['frames'])
    assert all('.artifacts/' not in f['path'] for f in handoff['provenance'].values())
    targets=[]
    for root in roots:
        root=root.resolve();assert root.is_relative_to((p.ROOT/'.artifacts').resolve())
        assert not root.is_symlink()
        for f in root.rglob('*'):
            assert not f.is_symlink() and f.resolve().is_relative_to(root)
            if f.is_file():targets.append((f,f.stat().st_size))
    total=sum(size for _,size in targets)
    for root in roots:shutil.rmtree(root)
    for f,digest in protected.items():assert f.is_file() and p.sha(f)==digest,f
    print(json.dumps(dict(removed_files=len(targets),recovered_bytes=total,
        preserved_source_files=len(protected),rebuildable='Source generation/extraction, focused engine and preview recipes retained. All originals/latents/mattes/guides/caches/saves/backups/RMG and unrelated artifacts preserved.')),flush=True)

if __name__=='__main__':main()
