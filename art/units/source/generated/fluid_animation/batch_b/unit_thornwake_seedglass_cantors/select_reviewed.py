"""Retain observed moving phases and shorten static holds; never synthesize poses."""
import json
import numpy as np
from PIL import Image
from scipy.ndimage import label
import produce as p
def select(take,indices,msec,note,contact=None,projectiles=False):
 out=p.SOURCE_DIR/take;c=json.loads((out/'config.json').read_bytes())
 assert len(indices)==len(set(indices)) and min(indices)>=0 and max(indices)<124
 s=dict(source_frames=indices,frame_msec=msec,review_note=note)
 if contact is not None:s['contact_frame']=indices.index(contact)
 if projectiles:
  cuts={}
  for i in [x for x in indices if 38<=x<=45]:
   alpha=np.asarray(Image.open(out/'matte'/f'rgba_{i:03}.png'))[:,:,3]>=8
   labs,count=label(alpha,structure=np.ones((3,3),dtype=np.uint8));sizes=np.bincount(labs.ravel());sizes[0]=0;body=sizes.argmax()
   ys,xs=np.where(labs==body);right=int(xs.max())
   # Inspect and retain every body/held-equipment component left of a fully
   # empty vertical gap. The original projectile remains in the source video.
   split=next(x for x in range(right+4,alpha.shape[1]-4) if not alpha[:,x-2:x+3].any() and alpha[:,x:].sum()>0)
   assert alpha[:,:split].sum()>alpha[:,split:].sum()
   cuts[str(i)]=dict(axis='x',split_x=split,reason='Personally reviewed detached seed-arrow only; original full bow, string, hands and leaves retained. Runtime owns outgoing projectile flight.')
  s['runtime_projectile_separation']=cuts
 p.write(out/'selection.json',s);p.build(out,c);print(take,len(indices),'contact',s.get('contact_frame'),flush=True)
if __name__=='__main__':
 select('move_h3_v1',list(range(20,65)),42,'Complete observed reciprocal cycle20-64: both root feet pass/lift and plant in opposed phases; matched extended-contact seam. Original ivory face, leaf crown and full left-hand bow stable; fixed scale/anchor; original frames at42ms, no interpolation.')
 select('attack_h3_v1',[0,4,8]+list(range(9,32))+[32,48,64]+list(range(65,84)),33,'Right empty fist rises beside shoulder, drives forward27-28 and withdraws65-83 while left hand holds full bow. Original brief motion blur26-27 follows arm trajectory; two arms remain distinct. Long contact hold shortened with original poses32/48/64; no duplicate or invented motion.',28)
 select('ranged_h3_v1',[0,4,8]+list(range(9,31))+[34,36]+list(range(38,51))+[58,66,70]+list(range(72,102,2))+[108,123],33,'Original left bow raises, right hand nocks/draws one amber seed-arrow, releases38 and follows through to shoulder before lowering to ready. Exclude37 where released arrow still touches bow and cannot be separated honestly. Fully detached flight38-45 cropped across proved empty gap, preserving body/held gear and original footage. Runtime owns flight; retained original timing phases deliberately shortened to33ms.',38,True)
 select('hit_h3_v1',[24,28]+list(range(30,55)),33,'Backward chest/head recoil35-42 with bent knees, retained left bow and right forearm recovery43-54. Shortened idle lead/tail; original two-arm silhouette and body scale remain stable.')
 select('defend_h3_v1',[0,4]+list(range(6,33))+[38,123],42,'Continuous hip/knee lowering and right-forearm chest guard, left bow upright and complete. Terminal original123 held after settling; no return-to-ready or extra shield.')
 select('cast_h3_v1',[0,8,12,14]+list(range(16,36))+[44,52]+list(range(54,81))+[84,123],33,'Physical spoken rally: right free hand rises to throat/chest, relaxed palm opens outward56-62 and lowers to ready; left bow remains held. Both feet planted, no spell effect. Original long chest hold shortened; no new magic or frame synthesis.',34)
 death=p.SOURCE_DIR/'death_h3_v2'
 if (death/'matte.json').exists():
  select('death_h3_v2',[0,6,10]+list(range(12,49,2))+list(range(49,65))+list(range(66,85,2))+[96,123],33,'Corrected original start/end-only footage: continuous hip/knee lowering12-26, loss of support and torso roll32-58, left bow turning with held arm54-64 onto ground in front, leaves/legs settling66-84. Head-right/feet-left original corpse123 held. All rapid roll frames49-64 retained, no intermediate pose cuts or synthesized motion; original scale/ground registration fixed.')
