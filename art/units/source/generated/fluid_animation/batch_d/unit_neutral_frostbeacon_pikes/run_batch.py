"""Generate preserved H3 originals in pairs; inspect candidates before acceptance."""
import argparse,json
import stage_video as stage
import produce

if __name__=='__main__':
 parser=argparse.ArgumentParser();parser.add_argument('takes',nargs='*',default=json.loads((produce.SOURCE_DIR/'delivery.json').read_bytes())['takes']);args=parser.parse_args()
 for start in range(0,len(args.takes),2):
  pair=[t for t in args.takes[start:start+2] if not (produce.SOURCE_DIR/t/'original.json').exists()]
  if not pair:continue
  stage.release_models()
  for take in pair:stage.run(take,phase='sample',release=False)
  stage.release_models()
  for take in pair:stage.run(take,release=False)
