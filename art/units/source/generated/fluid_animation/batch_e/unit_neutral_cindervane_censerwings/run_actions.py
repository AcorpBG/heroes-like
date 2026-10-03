"""At most two originals per shared GPU lease, then CPU review before more."""
import argparse
import stage_video as stage

if __name__=='__main__':
    a=argparse.ArgumentParser();a.add_argument('takes',nargs='+');args=a.parse_args()
    if len(args.takes)>2:a.error('Release shared GPU after at most two source actions')
    if any(not (stage.p.SOURCE_DIR/t/'sampling_submission.json').exists() for t in args.takes):stage.release_models()
    for t in args.takes:stage.run(t,phase='sample',release=False)
    for i,t in enumerate(args.takes):stage.run(t,phase='decode',release=i==0)
    pending=[t for t in args.takes if not (stage.p.SOURCE_DIR/t/'matte.json').exists()]
    if pending:
        import segment
        net=segment.model()
        if not (stage.p.SOURCE_DIR/'feather_matte_calibration.json').exists():
            from calibrate_feathers import calibrate
            calibrate(net)
        for t in pending:segment.run(net,t)
    import edge_despill
    for t in args.takes:
        if not (stage.p.SOURCE_DIR/t/'edge_matte.json').exists():edge_despill.run(t)
