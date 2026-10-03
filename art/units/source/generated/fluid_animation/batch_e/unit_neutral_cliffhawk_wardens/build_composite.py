"""Exact body foreground and complete original H3 companion behind it."""
from pathlib import Path
import copy,json,hashlib,sys
import numpy as np
from PIL import Image,ImageDraw
R=next(p for p in Path(__file__).resolve().parents if (p/'project.godot').exists());S=Path(__file__).parent;UID='unit_neutral_cliffhawk_wardens';OUT=R/'.artifacts/parallel_animation_20261002/middle53_completion_audit/cliffhawk-correction'
sys.path.insert(0,str(R/'tools'))
from publish_fluid_creature_animation import select_clips,combine
from integrate_fluid_creature_animation import pack_unit
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def write(p,v):p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(v,indent=2)+'\n')
old=json.loads((S/'original_handoff.json').read_bytes())['units'][0];entry=select_clips(old,['death']);original_frames=copy.deepcopy(entry['frames']);plan=json.loads((S/'composite_plan.json').read_bytes());bybody={f['video_frame']:f for f in original_frames}
frames=[copy.deepcopy(bybody[i]) for i in plan['original_early_frames']];records=[];previews=[]
# Native review exposed brief source-painted green/pink flashes at four
# intermediate wing phases. Neighboring observed frames retain the complete
# wingbeat; the landing contact/fold/recovery remains intact. Keep every body.
pairs=[dict(p) for p in plan['pairs'] if p['companion_frame'] not in [24,25,26,73,74]]
pairs.extend([dict(body_frame=53,companion_frame=23),dict(body_frame=54,companion_frame=26),dict(body_frame=88,companion_frame=75)])
pairs.sort(key=lambda p:p['companion_frame'])
for n,pair in enumerate(pairs):
 i,j=pair['body_frame'],pair['companion_frame'];assert j not in [1,24,25,48,73,74,98,123]
 bodypath=S/f'original_body/rgba_{i:03}.png';birdpath=S/f'companion_h3_v1/matte_plate_v3/rgba_{j:03}.png';a=np.array(Image.open(bodypath).convert('RGBA'));b=np.array(Image.open(birdpath).convert('RGBA'));body=a[:,:,3]>0;bird=b[:,:,3]>0
 assert not np.any((a[:,:,3]>0)&(a[:,:,3]<8));assert not np.any((b[:,:,3]>0)&(b[:,:,3]<8))
 # Foreground actor occludes only the physically behind shoulder/cape wing.
 # Copy source RGBA, including painted soft edges, instead of recoloring actor.
 result=b.copy();result[body]=a[body];assert np.array_equal(result[body],a[body]);assert np.array_equal(result[~body],b[~body])
 target=S/'composite_death'/f'rgba_{n:03}_body{i:03}_bird{j:03}.png';target.parent.mkdir(exist_ok=True);Image.fromarray(result).save(target)
 f=copy.deepcopy(bybody[i]);f.update(name=f'death_companion_{n:03}',source=target.relative_to(R).as_posix(),original_body_frame=i,companion_video_frame=j,companion_video_time_seconds=j/24,composite_recipe='build_composite.py: exact original body foreground, unchanged observed H3 companion behind body')
 frames.append(f);records.append(dict(death_phase=len(frames)-1,original_body_frame=i,companion_frame=j,body=bodypath.relative_to(R).as_posix(),body_sha256=sha(bodypath),companion=birdpath.relative_to(R).as_posix(),companion_sha256=sha(birdpath),composite=f['source'],composite_sha256=sha(target),body_rgba_exact=True,unoccluded_companion_rgba_exact=True,body_occluded_companion_pixels=int(np.sum(body&bird))))
 previews.append((len(frames)-1,i,j,Image.fromarray(result)))
assert set(f['video_frame'] for f in frames)==set(f['video_frame'] for f in original_frames),'Original collapse phases omitted'
entry['frames']=frames;entry['clips']['death']['indices']=list(range(len(frames)));entry['clips']['death']['frame_msec']=35;entry['clips']['death']['static_frame']=len(frames)-1;entry['clips']['death'].pop('frame_durations_msec',None)
entry['source_scale_by_image']={f['source']:f['scale'] for f in frames};entry['source_scale_reason']='Fixed original .5 death scale and anchor; no per-frame warp, interpolation or normalization.'
entry['visual_review']=dict(status='pending',notes='Complete companion flight/landing/fold, original body as foreground occluder. Requires changed composite/native review.')
recipe=dict(unit_id=UID,rule='Every original selected body phase retained with exact visible RGBA. One full original H3 companion behind body; no clipped bird pixels in source, no companion removal, no synthetic articulation.',original_early_frames=plan['original_early_frames'],original_body_phases=[f['video_frame'] for f in original_frames],observed_companion_take='companion_h3_v1',matting='Existing pinned semantic + fixed measured plate extraction, protected chroma67, unchanged all-frame rule.',retiming=dict(previous_death_poses=43,previous_msec=1505,death_poses=len(frames),frame_msec=35,duration_msec=len(frames)*35,reason='Retain complete observed flight/contact/fold/recovery while preserving all original collapse poses.'),records=records,preserved_unused_source='companion_clearance_h3_v2 sampler/decode complete; partial matte stopped on corner estimator. All124 original RGB personally reviewed; not used in publication.')
write(S/'composite_recipe.json',recipe);entry['provenance']['companion_correction']=dict(recipe=(S/'composite_recipe.json').relative_to(R).as_posix(),sha256=sha(S/'composite_recipe.json'));write(S/'handoff.json',dict(schema_version=1,units=[entry]))
combined=combine(old,entry);combined['accepted_clips']=json.loads((S/'original_row.json').read_bytes())['pose_accepted_clips'];write(S/'candidate_handoff.json',dict(schema_version=1,units=[combined]));patch=pack_unit(combined,json.loads((S/'original_row.json').read_bytes()),OUT/'candidate');patch['replaced_clips']=['death','dead'];write(OUT/'candidate/manifest_patch.json',dict(schema_version=1,units=[patch]))
for start in range(0,len(previews),8):
 chunk=previews[start:start+8];page=Image.new('RGB',(1440,290*((len(chunk)+2)//3)),(27,37,24));d=ImageDraw.Draw(page)
 for k,(phase,i,j,im) in enumerate(chunk):
  x=k%3*480;y=k//3*290;im=im.resize((480,272),Image.Resampling.LANCZOS);page.paste(im,(x,y),im);d.text((x+4,y+273),f'death{phase} / body{i} bird{j}',fill='white')
 page.save(OUT/f'composite-chronology-{start//8}.png')
for i,j in [(38,4),(60,36),(123,122)]:
 r=next(r for r in records if r['original_body_frame']==i and r['companion_frame']==j);Image.open(R/r['composite']).save(OUT/f'composite-detail-{i}-{j}.png')
print('COMPOSITE',len(frames),'death poses',len(records),'changed',[(r['original_body_frame'],r['companion_frame'],r['body_occluded_companion_pixels']) for r in records if r['body_occluded_companion_pixels']],flush=True)
