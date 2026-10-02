"""Complete at most two H3 actions under one externally held GPU lease."""
import argparse
import json
import stage_video as stage

if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('takes',nargs='+')
    args=parser.parse_args()
    paired=stage.p.SOURCE_DIR/'paired_actions.json'
    if paired.exists():
        companions=json.loads(paired.read_bytes())
        for requested in list(args.takes):
            for take in companions.get(requested,[]):
                if take not in args.takes and not (stage.p.SOURCE_DIR/take/'edge_matte.json').exists():
                    args.takes.append(take)
    if len(args.takes)>2:
        parser.error('Release the shared GPU after at most two actions')
    if any(not (stage.p.SOURCE_DIR/take/'sampling_submission.json').exists() for take in args.takes):
        stage.release_models()
    for i,take in enumerate(args.takes):
        stage.run(take,phase='sample',release=False)
    for i,take in enumerate(args.takes):
        stage.run(take,phase='decode',release=i==0)
    pending=[take for take in args.takes if not (stage.p.SOURCE_DIR/take/'matte.json').exists()]
    if pending:
        import segment
        net=segment.model()
        if not (stage.p.SOURCE_DIR/'glass_matte_calibration.json').exists():
            from calibrate_glass import calibrate
            calibrate(net)
        for take in pending:
            segment.run(net,take)
    import edge_despill
    for take in args.takes:
        if not (stage.p.SOURCE_DIR/take/'edge_matte.json').exists():
            edge_despill.run(take)
