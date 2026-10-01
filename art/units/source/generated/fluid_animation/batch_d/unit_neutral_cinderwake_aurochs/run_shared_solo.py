"""Finish one Aurochs take at a time without disturbing other service clients."""
import argparse
import json
import produce as p
import stage_video as stage

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('takes', nargs='+')
    args = parser.parse_args()
    for take in args.takes:
        out = p.SOURCE_DIR/take
        if (out/'original.json').exists():
            continue
        p.write(out/'shared_queue_scheduling.json', dict(
            unit_id='unit_neutral_cinderwake_aurochs',
            rule='Solo operator completes this creature; a separate Claude client also owns server work. Append sampling/decode behind existing jobs without explicit free, restart, cancellation or reordering.',
            initial_queue={k:[j[1] for j in v] for k,v in p.request(p.URL,'/queue').items()}))
        stage.run(take, release=False, queue_behind=True)
        print('SOLO_TAKE_COLLECTED',take,flush=True)
