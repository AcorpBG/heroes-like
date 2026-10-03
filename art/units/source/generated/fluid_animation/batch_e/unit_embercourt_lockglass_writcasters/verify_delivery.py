"""Verify only this unit: original source hashes, packed pixels, retained idle and map."""
import argparse,json,hashlib
from pathlib import Path
import av
import numpy as np
from PIL import Image
import produce as p
from integrate_fluid_creature_animation import old_pose,source_pose,clip_indices,resolve
from pack_overworld_creature_idle import extract
UID=p.SOURCE_DIR.name
checks=0
def check(value,message):
 global checks
 checks+=1
 if not value:raise AssertionError(message)
def read(path):return json.loads(Path(path).read_bytes())
def equal(a,b,message):
 check(a[1]==b[1] and a[0].size==b[0].size and a[0].tobytes()==b[0].tobytes(),message)
def verify(save_report=True):
 rows=read(p.ROOT/'content/unit_animation_manifest.json')['items'];new=next(r for r in rows if r['unit_id']==UID)
 sheet=Image.open(resolve(new['pose_sheet'])).convert('RGBA');check(max(sheet.size)<=4096,'Atlas exceeds bound')
 handoff=read(p.SOURCE_DIR/'handoff.json')['units'][0];published=0
 for name,spec in handoff['clips'].items():
  live=clip_indices(new['pose_clips'][name],new['pose_columns']);check(len(live)==len(spec['indices']),name+' count')
  for idx,packed in zip(spec['indices'],live):
   frame=handoff['frames'][idx];original=Image.open(p.ROOT/frame['source']).convert('RGBA');bounds=original.getchannel('A').point(lambda a:255 if a>=128 else 0).getbbox()
   check(bounds and min(bounds)>0 and bounds[2]<original.width and bounds[3]<original.height,'Clipped original '+frame['source'])
   equal(source_pose(frame,0),old_pose(sheet,new,packed),name+' source pixels');published+=1
 for rec in handoff['provenance'].values():check(p.sha(p.ROOT/rec['path'])==rec['sha256'],rec['path'])
 check(new['pose_clips']['dead']['indices']==[new['pose_clips']['death']['indices'][-1]],'Corpse final death')
 check(set(new['pose_accepted_clips'])=={'idle','move','attack','ranged','hit','defend','cast','death'},'Accepted clips')
 check('cast' not in new.get('pose_aliases',{}),'Dedicated support')
 maps=read(p.ROOT/'art/overworld/creature_idle.json')['units'];rebuilt,meta=extract(new);actual=Image.open(resolve(maps[UID]['path'])).convert('RGBA')
 check(rebuilt.size==actual.size and rebuilt.tobytes()==actual.tobytes(),'Map exact rebuild')
 check({k:v for k,v in maps[UID].items() if k!='sha256'}==meta,'Map metadata')
 check(maps[UID]['sha256']==p.sha(resolve(maps[UID]['path'])),'Map hash')
 oldmap=read(p.SOURCE_DIR/'baseline_map.json');baseline_idle=Image.open(p.SOURCE_DIR/'baseline_map_idle.png').convert('RGBA')
 check(actual.size==baseline_idle.size and actual.tobytes()==baseline_idle.tobytes(),'Original map idle exact pixels')
 check(maps[UID]['frame_msec']==oldmap['frame_msec'],'Original map idle timing')
 old=read(p.SOURCE_DIR/'baseline_manifest.json');baseline_sheet=Image.open(p.SOURCE_DIR/'baseline_atlas.png').convert('RGBA')
 for before,after in zip(clip_indices(old['pose_clips']['idle'],old['pose_columns']),clip_indices(new['pose_clips']['idle'],new['pose_columns'])):
  equal(old_pose(baseline_sheet,old,before),old_pose(sheet,new,after),'Original idle pose')
 check(len(clip_indices(new['pose_clips']['idle'],new['pose_columns']))==8,'Original idle eight')
 hashes_total=0
 accepted_takes=read(p.SOURCE_DIR/'delivery.json')['takes']
 rejected_takes=[r['take'] for r in read(p.SOURCE_DIR/'rejected_takes.json')['takes']]
 for take_name in dict.fromkeys(accepted_takes+rejected_takes):
  take=p.SOURCE_DIR/take_name;record=read(take/'original.json');check(p.sha(take/'original_lossless.mkv')==record['sha256'],'FFV1 hash')
  selected=set(read(take/'selection.json')['source_frames']) if (take/'selection.json').exists() else set();hashes=[]
  with av.open(str(take/'original_lossless.mkv')) as video:
   for index,frame in enumerate(video.decode(video=0)):
    rgb=np.asarray(frame.to_image().convert('RGB'));hashes.append(hashlib.sha256(rgb.tobytes()).hexdigest())
    if index in selected:
     rgba=np.asarray(Image.open(take/'matte'/f'rgba_{index:03}.png').convert('RGBA'));opaque=rgba[:,:,3]==255
     check(bool(opaque.any()) and np.array_equal(rgba[:,:,:3][opaque],rgb[opaque]),'Opaque original RGB coordinates changed '+take_name+'/'+str(index))
  check(hashes==record['decoded_rgb_sha256'],'Every decoded RGB source');hashes_total+=len(hashes)
  for guide in read(take/'reference.json')['guides']:
   check(p.sha(take/guide['input_file'])==guide['input_sha256'],'Guide hash');check(p.sha(p.ROOT/guide['source_frame']['source'])==guide['source_sha256'],'Reference hash')
 result=dict(checks=checks,original_rgb_frames=hashes_total,selected_source_takes=len(accepted_takes),rejected_source_takes=len(rejected_takes),published_h3_frames=published,atlas_size=list(sheet.size),atlas_rgba_bytes=sheet.width*sheet.height*4)
 if save_report:p.write(p.SOURCE_DIR/'source_verification.json',result)
 print(result)
 return result
if __name__=='__main__':
 parser=argparse.ArgumentParser();parser.add_argument('--no-report',action='store_true');args=parser.parse_args();verify(not args.no_report)
