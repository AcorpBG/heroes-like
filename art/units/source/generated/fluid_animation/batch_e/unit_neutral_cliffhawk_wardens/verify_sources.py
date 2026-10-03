"""Exact preserved originals, body pixels and observed companion source proof."""
from pathlib import Path
import hashlib,json,sys,av
import numpy as np
from PIL import Image
from scipy.ndimage import label,find_objects
R=next(p for p in Path(__file__).resolve().parents if (p/'project.godot').exists());S=Path(__file__).parent;UID='unit_neutral_cliffhawk_wardens';checks=0
def check(condition,message):
 global checks
 checks+=1
 assert condition,message
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p):return json.loads(p.read_bytes())
B=R/'art/units/source/generated/fluid_animation/batch_c'/UID/'death_h3_v1'
for take in [B,S/'companion_h3_v1',S/'companion_clearance_h3_v2']:
 info=read(take/'original.json');check(sha(take/'original_lossless.mkv')==info['sha256'],'Lossless source changed')
 with av.open(str(take/'original_lossless.mkv')) as v:raw=[hashlib.sha256(f.to_image().convert('RGB').tobytes()).hexdigest() for f in v.decode(video=0)]
 check(len(raw)==124,'Missing original source frames')
 for actual,expected in zip(raw,info['decoded_rgb_sha256']):check(actual==expected,'Original RGB frame changed')
check(sha(B/'original_lossless.mkv')==read(S/'body_extraction_recipe.json')['original_video_sha256'],'Original actor video changed')
for record in read(S/'body_extraction_recipe.json')['records']:
 original=R/record['original'];derived=R/record['derived'];check(sha(original)==record['original_sha256'],'Original actor matte changed');check(sha(derived)==record['derived_sha256'],'Derived body changed')
 a=np.array(Image.open(original).convert('RGBA'));b=np.array(Image.open(derived).convert('RGBA'));check(np.array_equal(a[:,:,:3],b[:,:,:3]),'Body RGB changed')
 changed=a[:,:,3]!=b[:,:,3];check(np.array_equal(a[~changed],b[~changed]),'Body pixel changed')
 labs,n=label(a[:,:,3]>=8,np.ones((3,3)));sizes=np.bincount(labs.ravel());sizes[0]=0;body=int(sizes.argmax());check(not np.any(changed[labs==body]),'Woman/pike component changed')
 actual=[]
 for k,sl in enumerate(find_objects(labs),1):
  if sl is None or not np.any(changed[labs==k]):continue
  y,x=sl;actual.append(dict(box=[x.start,y.start,x.stop,y.stop],pixels=int(sizes[k])));check(np.all(b[labs==k,3]==0),'Bird component incompletely removed')
 check(actual==record['detached_original_bird_components'],'Unreviewed component removed')
recipe=read(S/'composite_recipe.json');check(recipe['original_body_phases']==[f['video_frame'] for f in read(S/'handoff.json')['units'][0]['frames'][:16]]+[r['video_frame'] for r in read(S/'body_extraction_recipe.json')['records']],'Collapse phase list changed')
for f in recipe['records']:
 body=R/f['body'];bird=R/f['companion'];target=R/f['composite'];check(sha(body)==f['body_sha256'],'Body recipe drift');check(sha(bird)==f['companion_sha256'],'Companion source drift');check(sha(target)==f['composite_sha256'],'Composite drift')
 a=np.array(Image.open(body).convert('RGBA'));b=np.array(Image.open(bird).convert('RGBA'));c=np.array(Image.open(target).convert('RGBA'));foreground=a[:,:,3]>0
 check(np.array_equal(c[foreground],a[foreground]),'Foreground woman/pike RGBA changed');check(np.array_equal(c[~foreground],b[~foreground]),'Unoccluded observed bird RGBA changed')
check(set(recipe['original_body_phases'])==set(f['video_frame'] for f in read(S/'handoff.json')['units'][0]['frames']),'Original collapse phase omitted')
sys.path.insert(0,str(R/'tools'))
from integrate_fluid_creature_animation import source_pose,old_pose,resolve
row=next(r for r in read(R/'content/unit_animation_manifest.json')['items'] if r['unit_id']==UID);atlas=Image.open(resolve(row['pose_sheet'])).convert('RGBA');handoff=read(R/'art/animation/source/fluid'/UID/'reviewed_handoff.json')['units'][0]
for name,spec in handoff['clips'].items():
 for si,pi in zip(spec['indices'],row['pose_clips'][name]['indices']):
  source,origin=source_pose(handoff['frames'][si],0);packed,anchor=old_pose(atlas,row,pi);check(origin==anchor and source.size==packed.size and source.tobytes()==packed.tobytes(),'Published observed source/anchor differs')
check(row['pose_clips']['dead']['indices']==[row['pose_clips']['death']['indices'][-1]],'Corpse differs from final death')
result=dict(unit_id=UID,checks=checks,failures=[],original_lossless_rgb_frames=372,original_body_phases=43,derived_composite_phases=len(recipe['records']),published_selected_source_poses=sum(len(s['indices']) for s in handoff['clips'].values()),rule='Exact byte hashes, original RGB frames, body foreground RGBA, unoccluded observed companion RGBA, publication source/ground anchors. No art acceptance inferred from counts.')
(S/'source_verification.json').write_text(json.dumps(result,indent=2)+'\n');print('CLIFFHAWK_SOURCE_PROOF',result,flush=True)
