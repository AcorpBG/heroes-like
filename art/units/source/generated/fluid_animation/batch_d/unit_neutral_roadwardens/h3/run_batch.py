"""Generate preserved H3 originals in pairs; inspect candidates before acceptance."""
import argparse
import stage_video as stage
import produce

if __name__=='__main__':
 parser=argparse.ArgumentParser();parser.add_argument('takes',nargs='*',default=['move_h3_v1','attack_h3_v1','defend_h3_v1','hit_h3_v1','cast_h3_v1','death_h3_v1','attack_h3_v2']);args=parser.parse_args()
 for start in range(0,len(args.takes),2):
  pair=[t for t in args.takes[start:start+2] if not (produce.SOURCE_DIR/t/'original.json').exists()]
  if not pair:continue
  stage.release_models()
  for take in pair:stage.run(take,phase='sample',release=False)
  stage.release_models()
  for take in pair:stage.run(take,release=False)
