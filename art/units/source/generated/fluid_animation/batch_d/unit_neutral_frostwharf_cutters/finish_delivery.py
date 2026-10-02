"""Record this shipped unit after focused candidate, mirror, import and live checks."""
import json,re
from pathlib import Path
import produce as p
from PIL import Image

def report(path):
 text=path.read_text(encoding='utf-8');m=re.search(r'FLUID_ANIMATION_REPORT (\{.*\})',text)
 assert m and not [line for line in text.splitlines() if 'ERROR' in line and 'Failed to read the root certificate store.' not in line]
 d=json.loads(m.group(1));assert not d['failures'];return d['checks']

def main():
 own=p.ROOT/'.artifacts/frostwharf_solo';uid='unit_neutral_frostwharf_cutters'
 checks={name:report(own/name/'console.log') for name in ['candidate','mirrored','live']}
 assert 'FROSTWHARF_CUTTER_IMPORTED_ATLAS_OK' in (own/'atlas_import.log').read_text(encoding='utf-8')
 handoff=json.loads((p.SOURCE_DIR/'handoff.json').read_bytes())['units'][0];assert handoff['visual_review']['status']=='accepted'
 rows=json.loads((p.ROOT/'content/unit_animation_manifest.json').read_bytes())['items'];units={u['id']:u for u in json.loads((p.ROOT/'content/units.json').read_bytes())['items']}
 required={'idle':8,'move':8,'attack':8,'hit':4,'defend':4,'cast':8,'death':8};completed=[]
 for row in rows:
  req=dict(required)
  if units[row['unit_id']].get('ranged',False):req['ranged']=8
  if all(k in row.get('pose_accepted_clips',[]) and row.get('pose_clips',{}).get(k,{}).get('frames',len(row.get('pose_clips',{}).get(k,{}).get('indices',[])))>=n and k not in row.get('pose_aliases',{}) for k,n in req.items()):completed.append(row['unit_id'])
 assert uid in completed and len(rows)==232
 roster=dict(complete=len(completed),remaining=len(rows)-len(completed),total=len(rows))
 frames={name:len(spec['indices']) for name,spec in handoff['clips'].items()};total=sum(frames.values())
 atlas=Image.open(p.ROOT/'art/animation/runtime/fluid'/f'{uid}.png');assert max(atlas.size)<=4096
 note=(f'2026-10-02 SOLO COMPLETE: Frostwharf Cutters six H3 actions{total} original poses plus retained8-frame idle; reciprocal two-leg walk, two-hook slash/recovery, clean recoil, crossed-blades guard, physical blade salute and grounded corpse reviewed. '
       f'{checks["candidate"]}/{checks["mirrored"]}/{checks["live"]} candidate/mirrored/live focused checks pass; exact imported atlas, all232 map pixels/timing and other231 battle rows preserved. '
       f'Roster{roster["complete"]}/232 complete,{roster["remaining"]} remaining. Broad goal stays in_progress; solo, no full suite.')
 delivery=json.loads((p.SOURCE_DIR/'delivery.json').read_bytes())
 accepted=set(delivery['takes'])|{f['take'] for seq in delivery.get('clip_sequences',{}).values() for f in seq['frames']}
 accepted_rgb=sum(json.loads((p.SOURCE_DIR/t/'original.json').read_bytes())['frames'] for t in accepted)
 all_rgb=sum(json.loads((t/'original.json').read_bytes())['frames'] for t in p.SOURCE_DIR.iterdir() if t.is_dir() and (t/'original.json').exists())
 completion=dict(unit_id=uid,workflow='Solo local MiniMax H3 original video and extracted transparent frames; one unit fully completed.',new_takes=sorted(x.name for x in p.SOURCE_DIR.iterdir() if x.is_dir() and (x/'config.json').exists()),new_clip_frames=frames,preserved_accepted_clips=['idle'],visual_review=handoff['visual_review'],validation=dict(candidate_checks=checks['candidate'],mirrored_checks=checks['mirrored'],live_checks=checks['live'],failures=0,imported_atlas='Exact RGBA after Godot alpha-border processing',atlas_dimensions=list(atlas.size),rgba_bytes=atlas.width*atlas.height*4,new_original_action_frames=total,preserved_idle_frames=8,verified_accepted_take_rgb_frames=accepted_rgb,retained_original_rgb_frames_including_rejected=all_rgb,overworld_visuals_preserved=232,other_battle_rows_preserved=231,platform='Windows Godot4.6.2 offscreen',full_suite_run=False,manual_playtest=False,continuous_browser_playback_review=False,linux_run=False),roster_after=roster,progress_note=note)
 p.write(p.SOURCE_DIR/'completion.json',completion)
 # Replace only selected notes string. Preserve statuses and unrelated work.
 path=p.ROOT/'ops/progress.json';text=path.read_bytes().decode('utf-8');marker='"id": "art-fluid-creature-animation-20260923"'
 start=text.index('"notes": ',text.index(marker))+len('"notes": ');old,length=json.JSONDecoder().raw_decode(text[start:])
 path.write_bytes((text[:start]+json.dumps(note+' | '+old,ensure_ascii=False)+text[start+length:]).encode('utf-8'))
 print(note)

if __name__=='__main__':main()
