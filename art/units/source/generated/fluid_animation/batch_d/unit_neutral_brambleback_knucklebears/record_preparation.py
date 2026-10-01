"""Read service schemas and installed sizes; never queue or unload during prep."""
import datetime
import json
import shutil
from pathlib import Path
import produce as p

UID = 'unit_neutral_brambleback_knucklebears'


if __name__ == '__main__':
    parent = p.SOURCE_DIR.parent / 'unit_neutral_harbor_polearms/runtime_profile.json'
    inherited = json.loads(parent.read_bytes())
    stats = p.request(p.URL, '/system_stats')
    models = Path('H:/ai/minimax-h3/ComfyUI/models')
    sizes = []
    for model in inherited['model_manifest']['files']:
        installed = models / model['file']
        size = installed.stat().st_size
        assert size == model['bytes'], str(installed)
        sizes.append(dict(path=str(installed), bytes=size))
    profile = dict(unit_id=UID, checked_for_unit=UID, model_manifest=inherited['model_manifest'],
        inherited_model_hashes_from=parent.relative_to(p.ROOT).as_posix(),
        hash_source='Inherited installed model hashes/revision from Harbor profile. Current installed sizes rechecked for Knucklebear; no fresh full-model hash claimed.',
        current_service=stats, observed_at_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),
        installed_file_sizes=sizes,
        settings=dict(width=960, height=640, frames=124, fps=24, steps=20,
            sampler='res_multistep', scheduler='simple', turbo_lora=False),
        decode='Preserve original sampler latent; unload encoder/denoiser after sampling; separate tiled VAE decode 512/64/16/4.',
        generation_authorization='Prepared only. Movement first and immediate release; exclusive GPU grant required before queue, free, sampling or decoding calls.',
        verification_note='Own actual read-only system_stats and node schemas observed. No queue request/mutation, model unload or service process during preparation.')
    p.write(p.SOURCE_DIR / 'runtime_profile.json', profile)
    for take in json.loads((p.SOURCE_DIR / 'delivery.json').read_bytes())['takes']:
        p.write(p.SOURCE_DIR / take / 'runtime_profile.json', profile)
    schemas = {}
    for name in ['MiniMaxH3ImageToVideo', 'MiniMaxH3AddGuide', 'SaveLatent', 'LoadLatent', 'LTXVSeparateAVLatent', 'VAEDecodeTiled']:
        schemas[name] = p.request(p.URL, '/object_info/' + name)[name]
    p.write(p.SOURCE_DIR / 'installed_node_schemas.json', schemas)
    target = p.ROOT / '.artifacts/knucklebear_h3_20261001'
    for name, source in [('baseline_manifest.json', 'content/unit_animation_manifest.json'), ('baseline_map.json', 'art/overworld/creature_idle.json')]:
        destination = target / name
        if not destination.exists():
            shutil.copyfile(p.ROOT / source, destination)
    idle = json.loads((p.ROOT / 'art/overworld/creature_idle.json').read_bytes())['units'][UID]
    if not (target / 'baseline_map_idle.png').exists():
        shutil.copyfile(p.ROOT / idle['path'].removeprefix('res://'), target / 'baseline_map_idle.png')
    print('Read-only service/model/schema preparation complete; original target/map baseline saved.')
