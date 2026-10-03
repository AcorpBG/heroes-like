"""Hash immutable sampler originals and failed sources for permanent retention."""
import argparse,json
import produce as p

def run(status):
 records={}
 for out in sorted(p.SOURCE_DIR.iterdir()):
  if not (out/'original.json').exists():continue
  files=[f for f in out.iterdir() if f.is_file() and f.name not in ['handoff.json','selection.json','extraction_pending.json']]
  records[out.name]={f.name:dict(path=f.relative_to(p.ROOT).as_posix(),bytes=f.stat().st_size,sha256=p.sha(f)) for f in files}
 guide_art={}
 for directory in sorted({f.parent for f in p.SOURCE_DIR.rglob('*.generation.json')}):
  for f in sorted(directory.iterdir()):
   if f.is_file():guide_art[f.relative_to(p.SOURCE_DIR).as_posix()]=dict(path=f.relative_to(p.ROOT).as_posix(),bytes=f.stat().st_size,sha256=p.sha(f))
 p.write(p.SOURCE_DIR/'original_source_inventory.json',dict(unit_id=p.SOURCE_DIR.name,takes=records,guide_art=guide_art,original_rgb_frames=sum(json.loads((p.SOURCE_DIR/t/'original.json').read_bytes())['frames'] for t in records),status=status,rule='Retain all immutable original takes including rejected art and original generated guide images, exact requests, prompts and provenance. Rebuildable extraction files are governed by their exact matte hashes.'))
 print('ORIGINAL_SOURCE_INVENTORY',len(records),'takes',status)

if __name__=='__main__':
 a=argparse.ArgumentParser();a.add_argument('--status',choices=['in_progress','complete'],required=True);args=a.parse_args();run(args.status)
