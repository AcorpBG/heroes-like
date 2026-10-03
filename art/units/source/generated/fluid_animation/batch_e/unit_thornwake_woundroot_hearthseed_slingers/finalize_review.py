"""Finalize only completed, personally reviewed Hearthseed source and live work."""
import json,re,subprocess,sys
from PIL import Image
import produce as p
from verify_delivery import verify
UID=p.SOURCE_DIR.name
LEAF=p.ROOT/'.artifacts/parallel_animation_20261002'/UID

def read(path):return json.loads(path.read_bytes())
def report(folder):
 found=re.findall(r'FLUID_ANIMATION_REPORT (\{.*\})',(LEAF/folder/'console.log').read_text())
 assert len(found)==1,folder
 return json.loads(found[0])

if __name__=='__main__':
 acceptance=read(p.SOURCE_DIR/'personal_acceptance.json')
 required=['original_chronological_rgb_rgba','critical_enlarged','selected_native_light_dark_both_directions','actual_godot_native_normal_reflected','actual_strike','actual_shoot','map_motion_and_held_reduced_motion']
 assert all(acceptance.get(k) is True for k in required),'Personal review is incomplete'
 stages={name:report(name) for name in acceptance['runtime_stage_folders']}
 assert stages and all(not result['failures'] for result in stages.values()),stages
 for name in ['battle-phase-'+str(i)+'.png' for i in range(8)]:
  assert (LEAF/acceptance['live_strike_folder']/name).exists() and (LEAF/acceptance['live_shoot_folder']/name).exists()
 delivery=read(p.SOURCE_DIR/'delivery.json')
 for take in delivery['takes']:
  out=p.SOURCE_DIR/take;selection=read(out/'selection.json')
  assert acceptance['source_takes'][take]['original_rgb_frames_reviewed']==124 and acceptance['source_takes'][take]['original_rgba_frames_reviewed']==124
  assert acceptance['source_takes'][take]['selected_frames_reviewed']==len(selection['source_frames'])
  selection.setdefault('source_review_history',selection['review_note']);selection['review_status']='accepted_selected_clips'
  selection['review_note']='Personally accepted every original RGB/RGBA frame chronologically, critical enlarged transitions and all selected frames at native scale on light/dark backgrounds in both directions. Actual Godot normal/reflected native pages, Strike and Shoot captures and retained idle/map motion and held views accepted. Action selection rationale remains in source_review_history.'
  p.write(out/'selection.json',selection);p.build(out,read(out/'config.json'))
 delivery['visual_review']['notes']+=' '+acceptance['final_notes'];p.write(p.SOURCE_DIR/'delivery.json',delivery);p.assemble()
 paths=[p.ROOT/('art/animation/runtime/fluid/'+UID+'.png'),p.ROOT/('art/overworld/runtime/creature_idle/'+UID+'.png')];before={path:p.sha(path) for path in paths}
 subprocess.run([sys.executable,str(p.SOURCE_DIR/'publish_unit.py')],cwd=p.ROOT,check=True)
 assert before=={path:p.sha(path) for path in paths},'Acceptance metadata changed artwork'
 checked=verify();handoff=read(p.SOURCE_DIR/'handoff.json')['units'][0]
 clips={name:len(spec['indices']) for name,spec in handoff['clips'].items()};clips.update(idle=8,dead_alias=1)
 completion=dict(unit_id=UID,status='completed',source_verification=checked,runtime_stages=stages,clips=clips,
  new_h3_poses=len(handoff['frames']),published_unique_poses=len(handoff['frames'])+8,original_source_frames_retained=checked['original_rgb_frames'],rejected_complete_takes=checked['rejected_source_takes'],
  personal_acceptance=acceptance,fixes=acceptance['fixes'],imported_atlas=dict(exact_rgba_pixels=True,atlas_size=checked['atlas_size'],lossless_import=True,metadata_republication_artwork_byte_identical=True),
  preserved=dict(original_idle_poses=8,idle_frame_msec=240,exact_idle_and_map_pixels=True,originals_latents_guides_prompts_recipes_history=True,caches_saves_backups_and_rmg=True,unrelated_work=True),
  scope='Focused Windows Godot4.6.2 source, import and runtime fixtures. Linux and whole-game suite not run.',cleanup='Pending verified inactive cleanup')
 p.write(p.SOURCE_DIR/'completion.json',completion);print('FINAL_REVIEW_RECORDED',checked,flush=True)
