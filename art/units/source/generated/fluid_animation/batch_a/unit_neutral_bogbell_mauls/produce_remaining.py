"""Sample five unit actions before releasing models for VAE-only decoding.

Resume exact saved submissions; never enqueue a duplicate generation. This
group preserves the same per-action graphs/seeds while avoiding five repeated
encoder/denoiser reloads. Original pixels and visual review remain per action.
"""
import stage_video as stage

if __name__=='__main__':
 takes=['hit_h3_v1','defend_h3_v1','cast_h3_v1','death_h3_v1','move_h3_v1']
 for i,take in enumerate(takes):stage.run(take,phase='sample',release=i==0)
 for i,take in enumerate(takes):stage.run(take,release=i==0)
