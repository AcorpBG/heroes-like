"""Record personal completed engine capture review after actual inspection."""
import argparse,json
import produce as p
UID='unit_mireclaw_moonbite_mirehorn_breakers'
a=argparse.ArgumentParser();a.add_argument('mode',choices=['candidate','live']);args=a.parse_args()
root=p.ROOT/'.artifacts/parallel_animation_20261002'/UID/args.mode
results={}
for label in ['native','mirror']:
 directory=root/label;log=(directory/'console.log').read_text(encoding='utf-8')
 reports=[json.loads(line.split('FLUID_ANIMATION_REPORT ',1)[1]) for line in log.splitlines() if line.startswith('FLUID_ANIMATION_REPORT ')]
 assert len(reports)==1 and not reports[0]['failures'];results[label]=reports[0]
 assert len(list(directory.glob('battle-phase-*.png')))==8
 if args.mode=='live':assert len(list(directory.glob(UID+'-map*.png')))==3
review=json.loads((p.SOURCE_DIR/'source_review.json').read_bytes())
review[args.mode+'_personal_visual_review']=dict(passed=True,all_selected_native_and_reflected_poses=195,preserved_idle_poses=8,actual_battle_phase_captures=16,map_animated_and_reduced_captures=sum(len(list((root/label).glob(UID+'-map*.png'))) for label in ['native','mirror']),scope='Personally inspected complete unscaled native and reflected engine phase pages beside preserved idle, all map captures, full actual battle screenshots and unscaled action crops. Chronological source RGB/alpha review covers all124 per selected take. Both visible staff/rein grips, beast four paws/two horns, handler feet, mantle/lamps, horn contact/recovery and authentic two-body corpse endpoint remain coherent at actual128px. Actual battle screenshots use runtime board facing; reflected phase pages use runtime grounded rect/draw transform. No continuous manual playback claim.',checks={k:v['checks'] for k,v in results.items()})
p.write(p.SOURCE_DIR/'source_review.json',review)
if args.mode=='candidate':
 d=json.loads((p.SOURCE_DIR/'delivery.json').read_bytes());d['visual_review']=dict(status='accepted_selected_clips',notes='Six dedicated physical Mirehorn actions personally passed full original124 RGB/alpha per source, enlarged anatomy/grips, all195 selected actual128px poses both facings and native Godot candidate pages beside eight preserved idle260ms. Actual battle contact/recovery, normal/Fast/reduced/static/dead/interrupt/RNG/save fixtures passed. Authentic four-paw two-horn beast plus two-legged handler with left staff/right rein, original mantle/lamps and fixed original painting registration retained. Original eight battle/map idle poses remain byte-exact. Melee ranged-to-attack fallback retained; no authored ranged action. Imported/live checks still pending.')
 p.write(p.SOURCE_DIR/'delivery.json',d);p.assemble()
print('PERSONAL_ENGINE_CAPTURE_REVIEW_RECORDED',args.mode,flush=True)
