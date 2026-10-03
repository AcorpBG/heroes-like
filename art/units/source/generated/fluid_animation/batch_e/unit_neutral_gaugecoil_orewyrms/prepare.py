"""Prepare original four-legged Gaugecoil reference conditioning on CPU."""
import json,urllib.request
from pathlib import Path
from PIL import Image,ImageDraw
import numpy as np
import produce as p
OUT=p.SOURCE_DIR;ROOT=p.ROOT;UID=OUT.name;B=ROOT/'.artifacts/parallel_animation_20261002'/UID
refs=json.loads((OUT/'original_references.json').read_bytes())
if (OUT/'death_reference.json').exists():refs['dead_repaired']=json.loads((OUT/'death_reference.json').read_bytes())
identity=('ONE original Gaugecoil Orewyrm, fixed slightly elevated three-quarter orthographic camera facing SCREEN RIGHT. Exactly FOUR short articulated rock legs, two near and two far with natural body occlusion, cleft wedge feet and brass ankle plates; no human arms/hands, extra legs or wings. Retain original charcoal segmented mineral cylindrical body, weathered brass bands, orange rock seams. Exactly THREE original amber-glass pressure bulbs and THREE original white round gauge faces/red needles on brass brackets, connected copper/red tubes, same sizes and order. Original circular drill-flower jaw faces RIGHT with overlapping brass mineral tooth petals and dark red throat. One raised tapered tail LEFT ending ONE original red valve wheel. Keep every permanent mechanism attached, original head/body/leg proportions and painted details. ')
plate=(' Complete feet, jaw, pressure bulbs and tail wheel remain inside canvas with generous margins. Flat magenta RGB255,0,255 backdrop only; no floor, shadow, scenery, horizon, text, cuts, camera movement or zoom. No sparks, smoke, magic, flashes, beams or projectiles. Physical joint articulation rather than whole-body rocking, rigid translation or prop duplication. ')
specs={
 'move':(['idle_hands_0','walk_contact_a','walk_pass','walk_contact_b'],[(26,1),(52,2),(82,3)],0,'One smooth in-place four-legged crawling gait and return. Alternate the two diagonal leg pairs through bent joints: lift, swing forward, plant wedge foot, push back while opposite pair supports body. Keep at least two feet grounded. Tail segments flex slightly and pressure brackets follow body naturally; head closed and level. No travel across frame. Restore original ready stance.'),
 'attack':(['idle_hands_0','windup','bite'],[(28,1),(58,2)],0,'One physical Drill-Petal Lunge MELEE attack and complete recovery. Four wedge feet brace; front body draws back, drill jaw tooth petals open into original circular rosette, forebody thrusts SCREEN RIGHT to contact while rear legs support. Retract head, close same tooth petals and return all legs to original ready stance. No projectile, tongue, rotating new saw or effect.'),
 'hit':(['idle_hands_0','recoil'],[(46,1)],0,'One receiving-impact recoil and full recovery. Front head/neck draw back, four legs bend knees to absorb load and pressure bulbs sway on attached brackets. Recover closed jaw and original grounded ready. No attack, permanent collapse, chips or effects.'),
 'defend':(['idle_hands_0','guard'],[(48,1)],1,'One deliberate Pressure-Coil Brace. Lower cylindrical forebody, compress mineral segments, spread FOUR original legs and plant wedge feet firmly. Jaw stays closed, neck retracts inside armored rings, gauges/bulbs remain attached. Finish in deepest grounded defensive brace and HOLD. No return to standing, attack or death.'),
 'death':(['idle_hands_0','collapse','roll','dead_repaired' if 'dead_repaired' in refs else 'dead'],[(35,1),(78,2)],3,'One continuous terminal collapse. Four rock legs lose support and fold at their joints; segmented body sinks then rolls/slumps onto floor. Tail valve wheel lowers visibly to LEFT of body, original drill head rests closed on ground, every gauge/bulb/bracket remains identifiable and attached. Finish fully grounded and STILL, no surviving standing stance or recovery. All THREE amber bulbs and their THREE gauges remain visibly attached and cool dark brown, mineral seams dim at rest. No disappearing limbs, explosion, dismemberment or new hardware.')}
if (OUT/'support_reference.json').exists():
 refs['support_signal']=json.loads((OUT/'support_reference.json').read_bytes())
 specs['cast']=(['idle_hands_0','support_signal'],[(54,1)],0,'One purposeful physical SUPPORT signal. Keep THREE feet planted and closed drill jaw level. Lift the SAME viewer-near FRONT wedge foot, bend its original connected leg at knee/ankle, raise it beside chest as a deliberate rally cue. Tail straightens slightly while its original red valve wheel turns at its own stem. Lower the SAME foot through connected joints to original floor position and restore original ready stance. Pressure bulbs remain attached; no idle-only bobbing, human hand, attack or spell.')
for i,(name,(names,guides,last,beat)) in enumerate(specs.items()):
 out=OUT/f'{name}_h3_v1';out.mkdir(exist_ok=True)
 cfg=dict(unit_id=UID,clip=name,source_facing='right',canvas=[960,544],anchor=[480,500],scale=.5,key_rgb=[255,0,255],seed=2026110400+i,references=[refs[n] for n in names],guides=guides,last=last,prompt=(identity+beat+plate).strip(),tiled_decode=dict(tile_size=512,overlap=64,temporal_size=16,temporal_overlap=4))
 if not (out/'sampling_submission.json').exists():p.write(out/'config.json',cfg);p.prepare(out,cfg)
profile=json.loads((OUT/'runtime_profile.json').read_bytes());profile['runtime']=json.load(urllib.request.urlopen(p.URL+'/system_stats'));profile['verification_date']='2026-10-03';profile['schemas']={}
for n in ['MiniMaxH3ImageToVideo','MiniMaxH3AddGuide','VAEDecodeTiled','UNETLoader','CLIPLoader','VAELoader','SaveLatent','LoadLatent','LTXVSeparateAVLatent']:
 profile['schemas'][n]=json.load(urllib.request.urlopen(p.URL+'/object_info/'+n))[n]['input']
for r in profile['models']['files']:assert (Path('H:/ai/minimax-h3/ComfyUI/models')/r['file']).stat().st_size==r['bytes']
p.write(OUT/'runtime_profile.json',profile)
if not (OUT/'delivery.json').exists():p.write(OUT/'delivery.json',dict(takes=[f'{n}_h3_v1' for n in ['move','attack','hit','defend','cast','death']],failed_takes=[],preserved_accepted_clips=['idle'],visual_review=dict(status='pending',notes='All8 original idle poses personally qualify in chronological enlarged and exact128px RIGHT/reflected review. Six dedicated H3 actions remain pending full source/native/live acceptance; melee creature needs no ranged action.')))
measure=[];yellow=[]
for take in OUT.glob('*_h3_v*'):
 for f in take.glob('guide_*_rgba.png'):
  a=np.asarray(Image.open(f).convert('RGBA')).astype(np.int16);R,G,V=a[:,:,:3][a[:,:,3]>=240].T
  bands=dict(magenta=np.minimum(R,V)-G,green=G-np.maximum(R,V),blue=V-np.maximum(R,G),cyan=np.minimum(G,V)-R)
  measure.append(dict(path=f.relative_to(ROOT).as_posix(),sha256=p.sha(f),opaque_pixels=len(R),maximum={k:int(v.max()) for k,v in bands.items()}));yellow.extend((np.minimum(R,G)-V)[R-G<12].tolist())
p.write(OUT/'foreground_measurement.json',dict(guides=measure,protected_bands={k:max(r['maximum'][k] for r in measure)+2 for k in bands},protected_neutral_yellow_band=max(yellow)+2,rule='All original guide opaque palette maxima plus2; preserve amber glass, orange mineral seams, brass and red valve independently.'))
p.write(OUT/'unit_brief.json',dict(identity=identity,source_facing='right',source_scale=.5,video_anchor=[480,500],accepted_idle='All8 chronological enlarged and exact128px RIGHT/reflected poses retain four articulated rock legs, three pressure bulbs/gauges, closed drill jaw and tail valve. Preserve exact battle/map pixels and260ms.',action_guides={n:v[0] for n,v in specs.items()},required_actions=['move','attack','hit','defend','cast','death'],support_key_status='prepared' if 'cast' in specs else 'Distinct raised-front-foot physical support key required before cast submission.'))
p.write(OUT/'task_temporary_files.json',dict(files=[]))
B.mkdir(parents=True,exist_ok=True)
guides=[f for take in OUT.glob('*_h3_v1') for f in take.glob('guide_*_rgba.png')]
sheet=Image.new('RGB',(1920,((len(guides)+3)//4)*310),(45,48,42));d=ImageDraw.Draw(sheet)
for j,f in enumerate(guides):
 x,y=j%4*480,j//4*310;im=Image.open(f);im.thumbnail((480,272));sheet.paste(im,(x,y+25),im);d.text((x+8,y+7),f.parent.name+'/'+f.name,fill='white')
sheet.save(B/'prepared_guides.png')
print('GAUGECOIL_CPU_GUIDES_PREPARED',len(specs),len(guides),flush=True)
