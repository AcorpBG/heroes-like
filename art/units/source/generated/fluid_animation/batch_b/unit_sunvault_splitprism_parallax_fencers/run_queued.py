"""Queue every Parallax Fencers H3 take behind other jobs on the shared service.

Owner direction 2026-10-01: do not wait for an empty queue. All sampling jobs are
queued at once; each VAE-only decode is queued as soon as its latent is preserved.
Nothing is cancelled, interrupted, reordered or unloaded. Collection, matte and
chronological review previews follow on the CPU.
"""
import argparse
import datetime
import json
from pathlib import Path
import produce as p
import stage_video as stage

INHERIT = p.ROOT/'art/units/source/generated/fluid_animation/batch_d/unit_neutral_kitehook_runners/hit_h3_v2/runtime_profile.json'
MODELS = Path('H:/ai/minimax-h3/ComfyUI/models')
CLASSES = ['MiniMaxH3ImageToVideo','MiniMaxH3AddGuide','SamplerCustomAdvanced','LTXVSeparateAVLatent','SaveLatent','LoadLatent','VAEDecodeTiled']

def log(*parts):
    print(datetime.datetime.now().strftime('%H:%M:%S'), *parts, flush=True)

def profile():
    target = p.SOURCE_DIR/'runtime_profile.json'
    if target.exists():
        return
    inherited = json.loads(INHERIT.read_bytes())
    manifest = inherited['model_manifest']
    sizes = {f['file']: (MODELS/f['file']).stat().st_size for f in manifest['files']}
    assert all(sizes[f['file']] == f['bytes'] for f in manifest['files'])
    p.write(target, dict(unit_id='unit_sunvault_splitprism_parallax_fencers',
        captured_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),
        model_manifest=manifest,
        hash_source=dict(path=INHERIT.relative_to(p.ROOT).as_posix(), sha256=p.sha(INHERIT),
            rule='Inherited full model hashes and revision; current installed byte sizes independently verified; no fresh full-model hashing.'),
        installed_sizes=sizes, current_service=p.request(p.URL, '/system_stats'), queue_at_capture={k: len(v) for k, v in p.request(p.URL, '/queue').items()},
        current_node_schemas={name: p.request(p.URL, '/object_info/'+name) for name in CLASSES},
        settings=dict(width=960, height=640, length=124, fps=24, steps=20, sampler='res_multistep', scheduler='simple', turbo_lora=False),
        decode=dict(tile_size=512, overlap=64, temporal_size=16, temporal_overlap=4),
        scheduling='Owner direction 2026-10-01: queued behind other jobs on the shared local service; no cancellation, reordering or explicit model unload.'))

def timing(history):
    messages = {kind: data.get('timestamp') for kind, data in history['status']['messages'] if isinstance(data, dict)}
    start, end = messages.get('execution_start'), messages.get('execution_success')
    return dict(execution_start_ms=start, execution_success_ms=end, execution_seconds=(end-start)/1000 if start and end else None)

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('takes', nargs='*')
    args = parser.parse_args()
    takes = args.takes or json.loads((p.SOURCE_DIR/'delivery.json').read_bytes())['takes']
    profile()
    for take in takes:
        out = p.SOURCE_DIR/take
        if (out/'original.json').exists():
            continue
        p.verify(out, json.loads((out/'config.json').read_bytes()))
        sample = stage.submit_sampling(take, release=False, queue_behind=True)
        log('QUEUED_SAMPLING', take, sample['prompt_id'])
    for take in takes:
        out = p.SOURCE_DIR/take
        c = json.loads((out/'config.json').read_bytes())
        if not (out/'original.json').exists():
            stage.run(take, release=False, prepare_review=False, queue_behind=True)
            p.write(out/'gpu_timing.json', dict(sampling=timing(json.loads((out/'sampling_history.json').read_bytes())),
                decode=timing(json.loads((out/'generation_history.json').read_bytes())),
                rule='Queued behind shared jobs; sampling preserves latent, separate tiled VAE-only decode; collection verifies 124 RGB frames.'))
            log('COLLECTED', take)
        if not (out/'matte.json').exists():
            try:
                p.process(out, c)
            except ValueError as error:
                p.write(out/'extraction_failure.json', dict(error=str(error), status='requires_original_frame_review', rule='No fallback matte or acceptance; preserve originals for review.'))
                log('RAW_REVIEW_REQUIRED', take, error); continue
        p.review(out, c)
        log('REVIEW_READY', take)
    log('DONE', ' '.join(takes))
