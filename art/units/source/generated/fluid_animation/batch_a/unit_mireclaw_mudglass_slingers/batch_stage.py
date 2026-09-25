"""Grouped sampling then VAE decoding; source settings and latents unchanged."""
import argparse
import stage_video as stage
p=argparse.ArgumentParser();p.add_argument('--resume',nargs='*',default=[]);p.add_argument('takes',nargs='+');a=p.parse_args()
for take in a.resume:stage.run(take)
for i,take in enumerate(a.takes):stage.run(take,phase='sample',release=i==0)
released=stage.release_models()
print('GROUPED_MODELS_RELEASED',released,flush=True)
for take in a.takes:stage.run(take,phase='decode',release=False)
