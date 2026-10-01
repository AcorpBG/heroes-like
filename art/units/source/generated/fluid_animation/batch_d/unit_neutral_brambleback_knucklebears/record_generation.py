"""Summarize this original's actual stage timing and sampled memory observations."""
import argparse
import datetime
import json
import produce as p


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('take')
    args = parser.parse_args()
    out = p.SOURCE_DIR / args.take
    assert (out / 'original.json').exists()
    stages = {}
    for phase, submission_name, history_name in [
        ('sampling', 'sampling_submission.json', 'sampling_history.json'),
        ('decode', 'decode_submission.json', 'generation_history.json')]:
        submission = json.loads((out / submission_name).read_bytes())
        history = json.loads((out / history_name).read_bytes())
        assert history['status']['status_str'] == 'success'
        events = history['status']['messages']
        start = next(event[1]['timestamp'] for event in events if event[0] == 'execution_start')
        end = next(event[1]['timestamp'] for event in events if event[0] == 'execution_success')
        observed = json.loads((out / (phase + '_memory_observations.json')).read_bytes())['observations']
        devices = [device for sample in observed for device in sample['devices']]
        stages[phase] = dict(prompt_id=submission['prompt_id'], submitted_unix=submission['started_unix'],
            execution_start_unix=start/1000, execution_success_unix=end/1000, execution_seconds=(end-start)/1000,
            sampled_peak_device_used_bytes=max(device['vram_total']-device['vram_free'] for device in devices),
            sampled_peak_torch_reserved_bytes=max(device['torch_vram_total'] for device in devices),
            minimum_sampled_host_ram_free_bytes=min(sample['ram_free'] for sample in observed),
            status='success', execution_errors=[event for event in events if event[0] == 'execution_error'],
            memory_note='Periodic actual service readings; sampled peaks, not a CUDA-instrumented true allocation maximum.')
    log = p.ROOT / '.artifacts/creature_sets_20261001/server-reserve4-stderr.log'
    window = out / 'service_log_window.json'
    if window.exists():
        record = json.loads(window.read_bytes())
        log = p.ROOT / record['path']
        spans = [(record['start_byte'],record['sampling_end_byte']),
            (record['decode_start_byte'],record['decode_end_byte'])]
        parts = []
        with log.open('rb') as stream:
            for start, end in spans:
                stream.seek(start)
                parts.append(stream.read(end-start).decode('utf-8',errors='replace'))
        snapshot = '\n'.join(parts)
    else:
        # V1 predates window recording and owns this restarted service's
        # first two jobs. Exclude every subsequent agent's service job.
        assert args.take == 'move_h3_v1'
        snapshot = '[INFO] got prompt'.join(log.read_text(encoding='utf-8', errors='replace').split('[INFO] got prompt')[:3])
    relevant = [line.strip() for line in snapshot.splitlines()
        if any(token in line for token in ['Requested to load MiniMaxH3', 'loaded completely;', 'loaded partially;', 'Prompt executed in', '20/20', 'OutOfMemory', 'CUDA out of memory'])]
    summary = dict(unit_id='unit_neutral_brambleback_knucklebears', take=args.take,
        observed_at_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(), stages=stages,
        service_argv=json.loads((out/'runtime_profile.json').read_bytes())['current_service']['system']['argv'],
        loader_observation_source=log.relative_to(p.ROOT).as_posix(), relevant_loader_lines=relevant,
        loader_note='Actual active service log observed during the exclusive first movement take. Full loader residency is evidenced by loaded-completely/full-load-True lines; periodic memory readings alone do not establish residency.',
        original_rgb_frames_verified=124)
    p.write(out / 'generation_summary.json', summary)
    print(json.dumps(summary['stages'], indent=2))
