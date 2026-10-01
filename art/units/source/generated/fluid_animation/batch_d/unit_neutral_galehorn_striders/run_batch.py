"""Generate preserved H3 originals one action at a time; inspect candidates before acceptance."""
import argparse,json
import stage_video as stage
import produce

if __name__=='__main__':
 delivery=json.loads((produce.SOURCE_DIR/'delivery.json').read_bytes())
 sequence_takes=[f['take'] for spec in delivery.get('clip_sequences',{}).values() for f in spec['frames']]
 default_takes=list(dict.fromkeys(delivery['takes']+delivery.get('attack_segments',[])+sequence_takes))
 parser=argparse.ArgumentParser();parser.add_argument('takes',nargs='*',default=default_takes);args=parser.parse_args()
 for start in range(0,len(args.takes),1):
  pair=[t for t in args.takes[start:start+1] if not (produce.SOURCE_DIR/t/'original.json').exists()]
  if not pair:continue
  stage.release_models()
  for take in pair:stage.run(take,phase='sample',release=False)
  stage.release_models()
  for take in pair:stage.run(take,release=False)
