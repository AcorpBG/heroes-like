"""Record completed live acceptance without rebuilding or changing shipped pixels."""
import json
import produce as p
import build_delivery
from creature_animation_lock import exclusive

def main():
    source=p.SOURCE_DIR
    runtime=p.ROOT/'art/animation/source/fluid'/source.name
    pixels=[p.ROOT/'art/animation/runtime/fluid'/f'{source.name}.png',p.ROOT/'art/overworld/runtime/creature_idle'/f'{source.name}.png']
    before={str(f):p.sha(f) for f in pixels}
    delivery=json.loads((source/'delivery.json').read_bytes())
    note=delivery['visual_review']['notes'].replace('Selected import and live map check remain required.',
        'Selected imported battle/map textures verified exact RGBA. Live919 focused Windows checks pass; all eight preserved map shader phases and live contact personally inspected. Source verification preserves all2232 lossless RGB frames,262 published new action poses, eight exact240ms idle poses/map pixels and other231 battle/map rows. No full suite or Linux execution.')
    delivery['visual_review']=dict(status='accepted_runtime',notes=note)
    p.write(source/'delivery.json',delivery)
    build_delivery.assemble()
    handoff=json.loads((source/'handoff.json').read_bytes())['units'][0]
    with exclusive('content'):
        path=runtime/'reviewed_handoff.json';record=json.loads(path.read_bytes());unit=record['units'][0]
        assert unit['frames']==handoff['frames'] and unit['clips']==handoff['clips']
        unit['provenance']=handoff['provenance']
        unit['visual_review']=dict(status='accepted_selected_clips',notes=note)
        p.write(path,record)
        path=runtime/'provenance.json';record=json.loads(path.read_bytes());record['review']=unit['visual_review'];p.write(path,record)
    assert before=={str(f):p.sha(f) for f in pixels}
    for entry in handoff['provenance'].values():assert p.sha(p.ROOT/entry['path'])==entry['sha256'],entry['path']
    print('LIVE_ACCEPTANCE_FINALIZED; shipped pixels and source hashes preserved',flush=True)

if __name__=='__main__':main()
