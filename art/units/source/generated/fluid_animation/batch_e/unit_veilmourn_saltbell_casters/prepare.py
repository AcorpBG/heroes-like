"""Original Saltbell action guides; unchanged accepted idle is retained."""
import json,sys
import produce as p
UID='unit_veilmourn_saltbell_casters'
SELECTED=sys.argv[1:] if __name__=='__main__' else []
B=p.ROOT/'art/animation/source/poses'/UID
IDENTITY=('Original SALTBELL CASTER from supplied painting. One slender human in ragged ivory hooded coat over dark blue clothes, leather boots with bandaged shins and bronze knee plates, face visible beneath ivory hood, facing SCREEN RIGHT. Exactly TWO arms and TWO legs. His anatomical RIGHT hand, on SCREEN LEFT in the ready guide, grips one tan rope coil connected continuously to ONE small bronze handbell with blue tassel. His anatomical LEFT hand is the free open hand on SCREEN RIGHT. Preserve this exact grip and ONE continuously attached bell, no staff, duplicate bell, sword or new weapon. Original rope, bell, sleeves, hood, proportions and painted fantasy game surface remain recognizable. ')
PLATE=(' Entire backdrop flat magenta RGB255,0,255 throughout, no scenery, floor, cast shadow, text, cuts, camera movement or zoom. Fixed boot contact plane y576. Preserve one constant anatomical scale and keep bell/rope/coat/boots within ample margins. No particles or beams obscuring anatomy. ')

def reference(index):
 f=dict(json.loads((B/'packing.json').read_bytes())['frames'][index]);f['source']=(B/f['source']).relative_to(p.ROOT).as_posix();f['alpha_noise_cutoff']=8
 return f

def recipe(clip,indices,guides,last,action,seed):
 if SELECTED and clip not in SELECTED:return
 out=p.SOURCE_DIR/(clip+'_h3_v1');out.mkdir(exist_ok=True)
 c=dict(unit_id=UID,clip=clip,canvas=[960,640],anchor=[480,576],scale=.5,key_rgb=[255,0,255],seed=seed,references=[reference(i) for i in indices],guides=guides,last=last,prompt=(IDENTITY+action+PLATE).strip(),tiled_decode=dict(tile_size=512,overlap=64,temporal_size=16,temporal_overlap=4))
 if (out/'sampling_submission.json').exists() or (out/'submission.json').exists():
  assert json.loads((out/'config.json').read_bytes())==c,'Submitted recipe is immutable; use a new take'
  for guide in json.loads((out/'reference.json').read_bytes())['guides']:
   assert p.sha(out/guide['input_file'])==guide['input_sha256']
  print('Preserved submitted',clip,flush=True);return
 p.write(out/'config.json',c);p.prepare(out,c);p.verify(out,c);print('Prepared',clip,flush=True)

if __name__=='__main__':
 recipe('move',[16,2,3],[[30,1],[60,2]],0,'One full reciprocal WALK IN PLACE cycle: near boot extends forward and plants while far boot trails; near knee loads, then far boot passes and extends forward as near boot trails, then both recover to exact ready stance. Not a repeated one-leg hop. Original rope-hand lifts slightly to protect the hanging bell while free hand balances. Coat follows articulated hips/knees; planted boots stay registered. End matches initial guide. ',2026108301)
 recipe('attack',[16,6,7],[[36,1],[62,2]],0,'One physical close-range open-palm shove. Draw free anatomical LEFT arm back, shift weight through knees, thrust that same free open palm SCREEN RIGHT once in a clear contact, then withdraw and recover to ready. Anatomical RIGHT hand continues holding coil and attached bell low at the same side. No bell throw or new weapon. ',2026108302)
 recipe('hit',[16],[],0,'One clear short impact recoil: chest and hood lean backward away from SCREEN RIGHT, free forearm raises briefly, both knees flex and boots brace, bell-hand retains rope/attached bell. Recover to exact ready. No collapse, turning, equipment loss or repeated impacts. ',2026108303)
 recipe('defend',[16,8],[],1,'One continuous defensive brace: raise rope coil and attached bell with original anatomical RIGHT hand, bend knees, bring free LEFT forearm across chest to protect face and hood. End held in original guard guide, motionless final second. Bell remains on continuous rope, no extra arms or return to idle. ',2026108304)
 recipe('cast',[16,10,12],[[42,1],[72,2]],0,'One controlled bell support invocation. Anatomical RIGHT equipped hand slowly raises the original rope coil so the ONE continuously tethered bronze bell rises in a controlled overhead arc; anatomical LEFT free palm extends to direct the rite. Pause deliberately with both original hands clearly visible, bow hood slightly, then draw the bell downward toward the chest along its original continuous rope and recover to exact ready. Do not throw the bell horizontally, detach equipment, repeat a strike or merely repeat waist-level idle. Plain original painted hands and bell; no flashes, sparks, projectiles, spell stars, rings or new staff. ',2026108305)
 recipe('ranged',[16,10,11,12],[[30,1],[60,2],[88,3]],0,'One bell-on-rope casting strike: original anatomical RIGHT hand raises its rope coil, the ONE continuously attached bronze bell follows a single overhand arc SCREEN RIGHT, the bell stays tethered by one continuous rope, free LEFT hand reaches to direct the cast, then draw rope back and recover to ready. Preserve constant bell size and material. No detached projectile, duplicate bell, whip growth, extra hands or magical beam. Runtime owns distant projectile flight; show only held/tethered equipment. ',2026108306)
 recipe('death',[16,13,14,15],[[36,1],[78,2]],3,'One continuous grounded collapse. Knees buckle and torso kneels, original rope-hand lowers coil/attached bell to floor, free hand reaches to brace, body tips sideways then forearm and hip land. End in supplied grounded corpse with hood, two arms, two folded legs, ONE rope coil and attached bell resting on ground. No shrink, upright equipment, resurrection or disintegration. Final second completely still. ',2026108307)
 if not (p.SOURCE_DIR/'delivery.json').exists():
  p.write(p.SOURCE_DIR/'delivery.json',dict(takes=[c+'_h3_v1' for c in ['move','attack','hit','defend','cast','ranged','death']],preserved_accepted_clips=['idle'],visual_review=dict(status='pending',notes='Original24 poses personally inspected. Existing idle16-23 has clear free palm/forearm articulation, stable equipped rope hand and planted boots; preserve eight original poses and240ms timing. New actions await complete original/matte/native/reflected/live review.')))
 if not (p.SOURCE_DIR/'runtime_registration.json').exists():
  p.write(p.SOURCE_DIR/'runtime_registration.json',dict(unit_id=UID,reference_height=256,output_scale=.5,canvas=[960,640],ground_anchor=[480,576],ready_guide=reference(16),reason='Original artwork scales retained; one fixed video extraction scale and anatomical foot contact plane. No per-frame scale or registration.'))
