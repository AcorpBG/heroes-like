"""At most two H3 originals per GPU lease; CPU review follows release."""
import argparse
import stage_video as stage

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('takes',nargs='+');args=parser.parse_args()
    if len(args.takes)>2: parser.error('At most two source actions per shared GPU lease')
    if any(not (stage.p.SOURCE_DIR/t/'sampling_submission.json').exists() for t in args.takes): stage.release_models()
    for t in args.takes: stage.run(t,phase='sample',release=False)
    for i,t in enumerate(args.takes): stage.run(t,phase='decode',release=i==0)
    pending=[t for t in args.takes if not (stage.p.SOURCE_DIR/t/'matte.json').exists()]
    if pending:
        import segment
        net=segment.model()
        for t in pending: segment.run(net,t)
