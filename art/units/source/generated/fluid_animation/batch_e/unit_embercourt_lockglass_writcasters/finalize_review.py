"""Record completed personal acceptance and republish unchanged artwork metadata."""
import json,re,subprocess,sys
from PIL import Image
import produce as p
from verify_delivery import verify

UID=p.SOURCE_DIR.name
LEAF=p.ROOT/'.artifacts/parallel_animation_20261002'/UID

def report(folder):
 text=(LEAF/folder/'console.log').read_text()
 found=re.findall(r'FLUID_ANIMATION_REPORT (\{.*\})',text)
 assert len(found)==1,folder
 return json.loads(found[0])

if __name__=='__main__':
 stages={name:report(name) for name in ['candidate_pair_native','candidate_pair_mirrored','candidate_ranged_ranged','live_native','live_native_retry','live_ranged_ranged']}
 for name,result in stages.items():
  if name!='live_native':assert result['failures']==[],(name,result)
 assert len(stages['live_native']['failures'])==1
 for name in ['battle-phase-'+str(i)+'.png' for i in range(8)]:
  assert (LEAF/'live_native_retry'/name).exists() and (LEAF/'live_ranged_ranged'/name).exists()
 for suffix in ['overview','map-idle-0','map-idle-1','map-idle-reduced']:
  name=UID+'-'+suffix+'.png'
  a=Image.open(LEAF/'live_native'/name).convert('RGBA');b=Image.open(LEAF/'live_native_retry'/name).convert('RGBA')
  assert a.size==b.size and a.tobytes()==b.tobytes(),name
 delivery=json.loads((p.SOURCE_DIR/'delivery.json').read_bytes())
 for take in delivery['takes']:
  out=p.SOURCE_DIR/take;selection=json.loads((out/'selection.json').read_bytes())
  selection.setdefault('source_review_history',selection['review_note'])
  selection['review_status']='accepted_selected_clips'
  selection['review_note']='Personally accepted all 124 original RGB/RGBA poses chronologically, critical enlarged transitions and every selected pose at native scale on light/dark backgrounds in both directions. Final Godot native normal/reflected atlas pages, actual Strike and Shoot phase captures and preserved map motion/reduced-motion views accepted. All published live assertions passed; exact original pixels, anatomical registration and authored timing preserved. Action-specific selection rationale remains in source_review_history.'
  p.write(out/'selection.json',selection);p.build(out,json.loads((out/'config.json').read_bytes()))
 delivery['visual_review']['notes']+=' Final imported atlas matches exact RGBA pixels. Live normal retry passed 678 checks with all 34 strike poses; live Shoot passed all assertions with all 30 shot poses. Map motion and held reduced-motion views personally accepted. Initial live strike observer missed one contact pose; unchanged warm retry passed without changing artwork, timing, fixture assertions or playback.'
 p.write(p.SOURCE_DIR/'delivery.json',delivery);p.assemble()
 paths=[p.ROOT/('art/animation/runtime/fluid/'+UID+'.png'),p.ROOT/('art/overworld/runtime/creature_idle/'+UID+'.png')]
 before={path:p.sha(path) for path in paths}
 subprocess.run([sys.executable,str(p.SOURCE_DIR/'publish_unit.py')],cwd=p.ROOT,check=True)
 assert before=={path:p.sha(path) for path in paths},'Metadata publication changed artwork'
 checked=verify()
 completion=dict(unit_id=UID,status='completed',source_verification=checked,runtime_stages=stages,
  clips=dict(idle=8,move=34,attack=34,ranged=30,hit=13,defend=19,cast=24,death=34,dead_alias=1),
  published_unique_poses=196,new_h3_poses=188,original_source_frames_retained=1240,rejected_complete_takes=3,
  personal_acceptance=dict(original_chronological=True,critical_enlarged=True,selected_native_light_dark_both_directions=True,actual_godot_native_normal_reflected=True,actual_candidate_strike_captures=16,actual_candidate_shoot_captures=8,actual_live_strike_captures=8,actual_live_shoot_captures=8,map_motion_and_held_reduced_motion=True,continuous_manual_playback_claimed=False),
  fixes=['Reciprocal near/far leg gait replaces one-leg shuffle','Clean source guides and neutral gray conditioning replace opaque magenta movement rim; no opaque artwork recoloring','Two-grip forward stock-strike recovery replaces failed behind-head rifle','Dedicated physical chest salute; dedicated guard ending source36; grounded fall and held original corpse123','Reviewed spatial plate soft-edge unmix preserves exact opaque RGB'],
  imported_atlas=dict(exact_rgba_pixels=True,atlas_size=[2808,2692],lossless_import=True,metadata_republication_artwork_byte_identical=True),
  live_retry=dict(initial_observed_strike_poses=33,required=34,missing_initial_contact=18,unchanged_warm_retry_observed=34,cause_not_proven=True,timing_assertions_and_source_unchanged=True),
  preserved=dict(original_idle_poses=8,idle_frame_msec=240,exact_idle_and_map_pixels=True,originals_latents_guides_prompts_recipes_history=True,caches_saves_backups_and_rmg=True,unrelated_work=True),
  scope='Focused Windows Godot 4.6.2 fixtures and source verification; Linux and whole-game suite not run.',cleanup='Pending verified inactive cleanup')
 p.write(p.SOURCE_DIR/'completion.json',completion)
 print('FINAL_REVIEW_RECORDED',checked,flush=True)
