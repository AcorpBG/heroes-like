"""Exclude only reviewed disconnected foreign fragments, preserving original ink."""
from pathlib import Path
import copy,hashlib,json,sys
import numpy as np
from scipy.ndimage import label,find_objects
from PIL import Image,ImageDraw
R=next(p for p in Path(__file__).resolve().parents if (p/'project.godot').exists())
S=Path(__file__).parent;UID='unit_neutral_cinderwake_aurochs'
sys.path.insert(0,str(R/'tools'))
from publish_fluid_creature_animation import select_clips,combine
from integrate_fluid_creature_animation import pack_unit
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def write(p,v):p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(v,indent=2)+'\n')
# Exact alpha>=8, eight-connected foreign component sizes and boxes reviewed
# against original RGB and matte. No blanket largest-component filter is used.
FOREIGN={
58:[(126,[590,518,608,528])],60:[(121,[598,520,612,534])],62:[(178,[604,518,620,538])],64:[(169,[614,512,624,536])],65:[(139,[618,502,630,529])],
66:[(147,[625,480,636,502]),(92,[624,510,634,522])],67:[(141,[628,476,638,496]),(95,[626,506,636,518])],68:[(129,[628,476,640,496]),(83,[628,504,638,516])],
69:[(120,[630,479,640,496]),(110,[628,506,640,520])],70:[(121,[630,480,640,501]),(119,[630,508,640,524])],71:[(122,[632,484,640,506]),(118,[632,508,640,528])],
72:[(226,[634,490,642,532])],73:[(147,[634,504,644,529])],74:[(114,[634,510,644,528])],75:[(106,[634,512,644,528])],76:[(96,[634,512,644,528])],77:[(74,[634,512,644,526])]}
def main():
 old=json.loads((S/'original_handoff.json').read_bytes())['units'][0]
 entry=select_clips(old,['death']);evidence=R/'.artifacts/parallel_animation_20261002/middle53_completion_audit/cinderwake-correction';evidence.mkdir(parents=True,exist_ok=True)
 records=[];previews=[]
 for phase,f in enumerate(entry['frames']):
  i=f['video_frame']
  if i not in FOREIGN:continue
  original=R/f['source'];a=np.array(Image.open(original).convert('RGBA'));labs,n=label(a[:,:,3]>=8,structure=np.ones((3,3)));sizes=np.bincount(labs.ravel());sizes[0]=0;body=int(sizes.argmax());mask=np.zeros(a.shape[:2],bool);actual=[]
  for k,sl in enumerate(find_objects(labs),1):
   if k==body or sl is None:continue
   y,x=sl;box=[x.start,y.start,x.stop,y.stop];actual.append((int(sizes[k]),box));assert (int(sizes[k]),box) in FOREIGN[i],(i,'unreviewed component',actual)
   mask|=labs==k
  assert actual==FOREIGN[i],(i,actual,FOREIGN[i]);assert not np.any(mask[labs==body])
  corrected=a.copy();corrected[mask,3]=0
  assert np.array_equal(a[:,:,:3],corrected[:,:,:3]);assert np.array_equal(a[~mask],corrected[~mask]);assert np.array_equal(a[labs==body],corrected[labs==body])
  target=S/'derived_alpha'/f'rgba_{i:03}.png';target.parent.mkdir(exist_ok=True);Image.fromarray(corrected,'RGBA').save(target)
  f['original_source']=f['source'];f['source']=target.relative_to(R).as_posix();f['derived_alpha_recipe']='derive.py explicit disconnected foreign component whitelist; RGB and all connected body RGBA untouched'
  records.append(dict(death_phase=phase,video_frame=i,original=f['original_source'],original_sha256=sha(original),derived=f['source'],derived_sha256=sha(target),components=actual,alpha_pixels_removed=int(mask.sum()),unchanged_rgb=True,unchanged_connected_body_rgba=True))
  previews.append((phase,i,Image.fromarray(a,'RGBA'),Image.fromarray(corrected,'RGBA')))
 assert len(records)==17
 entry['source_scale_by_image']={f['source']:f['scale'] for f in entry['frames']};entry['source_scale_reason']='Unchanged anatomical registration; derived alpha removes only explicitly reviewed disconnected foreign fragments.'
 write(S/'extraction_recipe.json',dict(unit_id=UID,diagnosis='Foreign fragments already exist in original RGB death58-77; fixed matte retains them. Complete horn/body unchanged. Corpse123 has no fragment.',component_connectivity=8,component_alpha_threshold=8,rule='Explicit per-frame component box/size whitelist only; retain original RGB and every other RGBA pixel.',original_lossless_path='art/units/source/generated/fluid_animation/batch_d/'+UID+'/death_h3_v1/original_lossless.mkv',records=records))
 entry['provenance']['narrow_derived_extraction']=dict(path=(S/'extraction_recipe.json').relative_to(R).as_posix(),sha256=sha(S/'extraction_recipe.json'))
 entry['visual_review']=dict(status='pending',notes='Narrow foreign-alpha extraction requires personal source/native/reflected review.')
 write(S/'handoff.json',dict(schema_version=1,units=[entry]))
 combined=combine(old,entry);combined['accepted_clips']=json.loads((S/'original_row.json').read_bytes())['pose_accepted_clips']
 write(S/'candidate_handoff.json',dict(schema_version=1,units=[combined]))
 for start in range(0,len(previews),6):
  chunk=previews[start:start+6];page=Image.new('RGB',(1500,50+300*len(chunk)),(30,40,26));d=ImageDraw.Draw(page)
  for j,(phase,i,before,after) in enumerate(chunk):
   d.text((4,50+j*300),f'death {phase}; video {i}; original / derived / reflected derived',(240,240,220))
   for col,im in enumerate([before,after,after.transpose(Image.Transpose.FLIP_LEFT_RIGHT)]):
    box=(530,435,670,575) if col<2 else (960-670,435,960-530,575);cut=im.crop(box).resize((280,280),Image.Resampling.NEAREST);page.paste(cut,(col*500+20,70+j*300),cut)
  # Slice into at most three complete rows so view_image preserves pixels.
  for row in range(0,len(chunk),3):page.crop((0,50+row*300,1500,min(page.height,50+(row+3)*300))).save(evidence/f'alpha-detail-{start//6}-{row//3}.png')
 row=json.loads((S/'original_row.json').read_bytes());patch=pack_unit(entry,row,evidence/'candidate');write(evidence/'candidate/manifest_patch.json',dict(schema_version=1,units=[patch]));print('DERIVED',len(records),'frames',sum(r['alpha_pixels_removed'] for r in records),'foreign alpha pixels',flush=True)
if __name__=='__main__':main()
