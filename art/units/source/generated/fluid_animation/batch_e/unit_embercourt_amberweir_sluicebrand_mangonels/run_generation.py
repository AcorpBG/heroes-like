"""Run independent action sampling before model release and VAE-only decoding."""
import argparse
import stage_video as stage
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('phase',choices=['sample','decode']);p.add_argument('takes',nargs='+');a=p.parse_args()
 for i,take in enumerate(a.takes):stage.run(take,phase=a.phase,release=i==0)
