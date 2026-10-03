"""Verify preserved RGB footage, explicit alpha exclusions and exact packed sources."""
from pathlib import Path
import hashlib,json,sys
import av,numpy as np
from PIL import Image
from scipy.ndimage import label
R=next(p for p in Path(__file__).resolve().parents if (p/'project.godot').exists());S=Path(__file__).parent;UID='unit_neutral_cinderwake_aurochs'
sys.path.insert(0,str(R/'tools'))
from integrate_fluid_creature_animation import source_pose,old_pose,resolve
from derive import FOREIGN
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 take=R/'art/units/source/generated/fluid_animation/batch_d'/UID/'death_h3_v1';record=json.loads((take/'original.json').read_bytes());assert sha(take/'original_lossless.mkv')==record['sha256']
 with av.open(str(take/'original_lossless.mkv')) as video:hashes=[hashlib.sha256(f.to_image().convert('RGB').tobytes()).hexdigest() for f in video.decode(video=0)]
 assert hashes==record['decoded_rgb_sha256'];checks=len(hashes)
 recipe=json.loads((S/'extraction_recipe.json').read_bytes());assert len(recipe['records'])==17
 for f in recipe['records']:
  original=R/f['original'];derived=R/f['derived'];assert sha(original)==f['original_sha256'] and sha(derived)==f['derived_sha256'];a=np.array(Image.open(original).convert('RGBA'));b=np.array(Image.open(derived).convert('RGBA'));labs,n=label(a[:,:,3]>=8,structure=np.ones((3,3)));mask=a[:,:,3]!=b[:,:,3];sizes=np.bincount(labs.ravel());sizes[0]=0;body=int(sizes.argmax())
  assert np.array_equal(a[:,:,:3],b[:,:,:3]) and np.array_equal(a[~mask],b[~mask]);assert not np.any(mask[labs==body]);assert int(mask.sum())==f['alpha_pixels_removed'];assert np.all(b[mask,3]==0);assert len(f['components'])==len(FOREIGN[f['video_frame']]);checks+=8
 published='--live' in sys.argv
 if published:
  row=next(x for x in json.loads((R/'content/unit_animation_manifest.json').read_bytes())['items'] if x['unit_id']==UID);entry=json.loads((R/'art/animation/source/fluid'/UID/'reviewed_handoff.json').read_bytes())['units'][0];atlas=Image.open(resolve(row['pose_sheet'])).convert('RGBA');provenance=json.loads((R/'art/animation/source/fluid'/UID/'provenance.json').read_bytes())
  for name,spec in entry['clips'].items():
   for i,j in zip(spec['indices'],row['pose_clips'][name]['indices']):
    f=entry['frames'][i];assert provenance['sources']['res://'+resolve(f['source']).relative_to(R).as_posix()]==sha(resolve(f['source']));a=source_pose(f,0);b=old_pose(atlas,row,j);assert a[1]==b[1] and a[0].size==b[0].size and a[0].tobytes()==b[0].tobytes();checks+=2
 result=dict(original_rgb_frames=len(hashes),derived_frames=17,excluded_components=sum(len(f['components']) for f in recipe['records']),excluded_alpha_pixels=sum(f['alpha_pixels_removed'] for f in recipe['records']),published=published,checks=checks,failures=[])
 print('CINDERWAKE_SOURCE_PROOF',json.dumps(result),flush=True)
 (S/'source_verification.json').write_text(json.dumps(result,indent=2)+'\n')
if __name__=='__main__':main()
