"""Separate only the already detached old bird; retain every body/equipment pixel."""
from pathlib import Path
import json,hashlib
import av,numpy as np
from scipy.ndimage import label,find_objects
from PIL import Image
R=next(p for p in Path(__file__).resolve().parents if (p/'project.godot').exists());S=Path(__file__).parent;B=R/'art/units/source/generated/fluid_animation/batch_c/unit_neutral_cliffhawk_wardens/death_h3_v1';O=S/'original_body';O.mkdir(exist_ok=True)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
rec=json.loads((B/'original.json').read_bytes());assert sha(B/'original_lossless.mkv')==rec['sha256']
with av.open(str(B/'original_lossless.mkv')) as video:hashes=[hashlib.sha256(f.to_image().convert('RGB').tobytes()).hexdigest() for f in video.decode(video=0)]
assert hashes==rec['decoded_rgb_sha256'];records=[]
for i in [i for i in json.loads((B/'selection.json').read_bytes())['source_frames'] if i>=36]:
 source=B/f'matte/rgba_{i:03}.png';a=np.array(Image.open(source).convert('RGBA'));b=a.copy();mask=np.zeros(a.shape[:2],bool);components=[]
 if i<=55:
  labs,n=label(a[:,:,3]>=8,np.ones((3,3)));sizes=np.bincount(labs.ravel());sizes[0]=0;body=int(sizes.argmax());boxes=find_objects(labs)
  for j in range(1,n+1):
   if j==body or sizes[j]<500:continue
   z=boxes[j-1];box=[z[1].start,z[0].start,z[1].stop,z[0].stop]
   if box[0]>=450 and box[3]<310:mask|=labs==j;components.append(dict(box=box,pixels=int(sizes[j])))
  assert len(components)==1,(i,components);assert not np.any(mask[labs==body])
 b[mask,3]=0;assert np.array_equal(a[:,:,:3],b[:,:,:3]) and np.array_equal(a[~mask],b[~mask])
 target=O/f'rgba_{i:03}.png'
 if target.exists():assert np.array_equal(np.array(Image.open(target).convert('RGBA')),b),'Existing own body extraction differs; refuse overwrite'
 else:Image.fromarray(b).save(target)
 records.append(dict(video_frame=i,original=source.relative_to(R).as_posix(),original_sha256=sha(source),derived=target.relative_to(R).as_posix(),derived_sha256=sha(target),detached_original_bird_components=components,all_body_and_other_rgba_exact=True,all_rgb_exact=True))
(S/'body_extraction_recipe.json').write_text(json.dumps(dict(original_rgb_frames_preserved=124,original_video_sha256=rec['sha256'],records=records,rule='Remove only one proven detached old companion component at36-55 for replacement by personally accepted original H3 companion pixels. Keep body/pike and all other RGBA unchanged. Not an accepted standalone clip.'),indent=2)+'\n')
print('CLIFFHAWK_BODY_SOURCE_EXACT',len(hashes),len(records),'old_detached_bird_components',sum(len(r['detached_original_bird_components']) for r in records),flush=True)
