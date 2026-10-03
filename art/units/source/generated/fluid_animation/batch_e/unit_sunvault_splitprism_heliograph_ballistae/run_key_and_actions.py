"""One pinned key matte and at most two source actions in a shared GPU lease."""
import argparse
import gc
import torch
import matte_rotation_key
import stage_video as stage


if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('takes',nargs='+');args=parser.parse_args()
    if len(args.takes)>2:parser.error('At most two source actions per lease')
    if not (stage.p.SOURCE_DIR/'rolling_rotation_key_v4/matte.json').exists():
        matte_rotation_key.main()
        gc.collect();torch.cuda.empty_cache()
    for take in args.takes:stage.run(take,phase='sample',release=False)
    for i,take in enumerate(args.takes):stage.run(take,phase='decode',release=i==0)
    pending=[take for take in args.takes if not(stage.p.SOURCE_DIR/take/'matte.json').exists()]
    if pending:
        import segment
        net=segment.model()
        for take in pending:segment.run(net,take)
