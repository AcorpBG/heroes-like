"""Prove candidate atlas pixels/registration against retained selected sources."""
import json,hashlib,argparse
from pathlib import Path
from PIL import Image
import produce as p
from integrate_fluid_creature_animation import old_pose,source_pose,clip_indices,resolve

a=argparse.ArgumentParser();a.add_argument('patch',type=Path);args=a.parse_args()
row=json.loads(args.patch.read_bytes())['units'][0]['animation']
h=json.loads((p.SOURCE_DIR/'handoff.json').read_bytes())['units'][0]
baseline=json.loads((p.SOURCE_DIR/'original_baseline.json').read_bytes())['row']
sheet=Image.open(resolve(row['pose_sheet'])).convert('RGBA')
assert max(sheet.size)<=4096 and sheet.width*sheet.height*4<=64*1024*1024
count=0
for name,clip in h['clips'].items():
 for index,packed in zip(clip['indices'],clip_indices(row['pose_clips'][name],row['pose_columns'])):
  original=source_pose(h['frames'][index],0);actual=old_pose(sheet,row,packed)
  assert original[1]==actual[1] and original[0].size==actual[0].size and original[0].tobytes()==actual[0].tobytes()
  count+=1
old=Image.open(resolve(baseline['pose_sheet'])).convert('RGBA')
for before,after in zip(clip_indices(baseline['pose_clips']['idle'],baseline['pose_columns']),clip_indices(row['pose_clips']['idle'],row['pose_columns'])):
 first,second=old_pose(old,baseline,before),old_pose(sheet,row,after)
 assert first[1]==second[1] and first[0].size==second[0].size and first[0].tobytes()==second[0].tobytes()
assert row['pose_clips']['idle']['frame_msec']==baseline['pose_clips']['idle']['frame_msec']==260
assert row['pose_clips']['dead']['indices']==[row['pose_clips']['death']['indices'][-1]]
for record in h['provenance'].values():assert p.sha(p.ROOT/record['path'])==record['sha256'],record['path']
print('CANDIDATE_EXACT_SOURCE_PIXELS_ANCHORS',count,'IDLE_EXACT',8,'RGBA_BYTES',sheet.width*sheet.height*4,flush=True)
