"""Capture current H3 service evidence without changing committed profiles."""
import argparse
import json
import time
from pathlib import Path
import produce as p

parser = argparse.ArgumentParser()
parser.add_argument('takes', nargs='+')
args = parser.parse_args()
stats = p.request(p.URL, '/system_stats')
queue = p.request(p.URL, '/queue')
assert not queue['queue_running'] and not queue['queue_pending']
argv = stats['system']['argv']
assert argv[argv.index('--reserve-vram')+1] == '10'
assert '--disable-api-nodes' in argv and '--disable-dynamic-vram' in argv
parent = p.SOURCE_DIR / 'runtime_profile.json'
original = json.loads(parent.read_bytes())
models = Path('H:/ai/minimax-h3/ComfyUI/models')
files = []
for item in original['model_manifest']['files']:
    path = models / item['file']
    assert path.stat().st_size == item['bytes']
    files.append(dict(item, installed_path=str(path), current_size_verified=True))
schemas = {name:p.request(p.URL, '/object_info/'+name) for name in
    ['MiniMaxH3ImageToVideo','MiniMaxH3AddGuide','LTXVSeparateAVLatent',
     'SaveLatent','LoadLatent','VAEDecodeTiled']}
for take in args.takes:
    out = p.SOURCE_DIR / take
    assert not (out / 'submission.json').exists(), 'Submitted original is immutable'
    config = json.loads((out/'config.json').read_bytes())
    p.verify(out, config)
    p.write(out/'runtime_profile.json', dict(
        unit_id=config['unit_id'], take=take, recorded_unix=time.time(),
        source_profile=dict(path=parent.relative_to(p.ROOT).as_posix(), sha256=p.sha(parent)),
        current_service=stats, initial_queue=queue, current_node_schemas=schemas,
        model_manifest=dict(original['model_manifest'], files=files),
        hash_source='Inherited committed installed model hashes; current file sizes verified, not a fresh full-model hash.',
        generation=dict(canvas=config['canvas'], frames=124, fps=24, seed=config['seed'],
                        steps=20, sampler='res_multistep', scheduler='simple', turbo_lora=False),
        decode=config['tiled_decode'],
        rule='Authorized exclusive slot; preserve sampler latent and all decoded originals; release models before grouped VAE decode.'))
    print(take, 'verified fresh runtime profile', flush=True)
