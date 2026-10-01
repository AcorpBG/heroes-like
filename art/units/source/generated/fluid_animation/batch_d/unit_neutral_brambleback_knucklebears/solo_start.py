"""Observe current service and prepare one solo Knucklebear unit, preserving originals."""
import json, shutil, time
from pathlib import Path
import produce as p

def main():
    queue=p.request(p.URL,'/queue')
    assert not queue['queue_running'] and not queue['queue_pending']
    stats=p.request(p.URL,'/system_stats')
    assert '--disable-api-nodes' in stats['system']['argv']
    old=json.loads((p.SOURCE_DIR/'runtime_profile.json').read_bytes())
    installed=Path('H:/ai/minimax-h3/ComfyUI/models')
    for model in old['model_manifest']['files']:
        assert (installed/model['file']).stat().st_size==model['bytes']
    for name in ['move_h3_v2','attack_h3_v1','hit_h3_v1','defend_h3_v1','cast_h3_v1','death_h3_v1']:
        folder=p.SOURCE_DIR/name
        assert not (folder/'sampling_submission.json').exists()
        assert not (folder/'submission.json').exists()
        profile=dict(old,current_service=stats,initial_queue=queue,recorded_unix=time.time(),
            generation_authorization='Owner solo production direction: complete this unit before another. Current queue empty; use separate sampler-latent and VAE-only decode jobs.',
            verification_note='Current model sizes verified; inherited recorded hashes, not a fresh full-model hash. No other client queue cancellation or service restart.')
        if (folder/'runtime_profile.json').exists():
            backup=folder/'runtime_profile.pre-solo.json'
            assert not backup.exists();shutil.copyfile(folder/'runtime_profile.json',backup)
        p.verify(folder,json.loads((folder/'config.json').read_bytes()))
        p.write(folder/'runtime_profile.json',profile)
    out=p.ROOT/'.artifacts/knucklebear_solo_20261001';out.mkdir(exist_ok=False)
    for name,source in [('baseline_manifest.json','content/unit_animation_manifest.json'),('baseline_map.json','art/overworld/creature_idle.json')]:
        shutil.copyfile(p.ROOT/source,out/name)
    idle=json.loads((p.ROOT/'art/overworld/creature_idle.json').read_bytes())['units']['unit_neutral_brambleback_knucklebears']
    shutil.copyfile(p.ROOT/idle['path'].removeprefix('res://'),out/'baseline_map_idle.png')
    ops=p.ROOT/'ops/progress.json';raw=ops.read_text(encoding='utf-8');data=json.loads(raw)
    row=next(r for r in data['plannedSlices'] if r['id']=='art-fluid-creature-animation-20260923')
    assert row['status']=='in_progress'
    note=('2026-10-01 solo next unit: Brambleback Knucklebears. Preserve reviewed legacy idle8/map; '
          'prior move_v1 rejected for abrupt paw swaps and fixed hind paw. Generate corrected move_v2 first, '
          'review reciprocal four-limb support, then complete dedicated attack/hit/defend/support/death. '
          'No delegation, no new creature until full unit delivery. ')+row['notes']
    needle=json.dumps(row['notes'],ensure_ascii=False)
    assert raw.count(needle)==1
    ops.write_text(raw.replace(needle,json.dumps(note,ensure_ascii=False),1),encoding='utf-8')
    print('Current service/profiles and original baseline verified. Solo movement correction ready.')

if __name__=='__main__':main()
