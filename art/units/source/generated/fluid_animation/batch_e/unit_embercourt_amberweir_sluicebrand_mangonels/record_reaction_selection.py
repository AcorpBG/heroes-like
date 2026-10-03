"""Record personally reviewed original recoil and held brace selections."""
import json
import produce as p

items = [
 ('hit_h3_v1', list(range(23, 70, 2)), 11,
  'All124 original RGB and semantic RGBA frames personally reviewed chronologically, all124 actual128px poses RIGHT and reflected, enlarged25/45/60/82 against original RGB and alpha on light/dark. Both original crew bend knees while keeping connected pump/rope grips; loaded arm lowers at recoil45 and returns to loaded ready by65/69. Same two crew, three grounded wheels, original gauges and seated stone throughout; no flashes or emitted particles. Select continuous complete reaction23..69 at original12fps,83ms; no synthetic poses, splicing, stabilization, or artwork alteration. Actual Godot acceptance pending.'),
 ('defend_h3_v1', list(range(0, 47, 2)), None,
  'All124 original RGB and semantic RGBA frames personally reviewed chronologically, all124 actual128px poses RIGHT and reflected, enlarged25/45/78/110 against original RGB and alpha on light/dark. Both original crew crouch behind the loaded chassis and retain their controls while the throwing arm lowers into a guarded angle; three original grounded wheels, original counterweight and gauges remain intact. Select continuous ready-to-held-brace0..46 at original12fps,83ms, then hold final pose; omit redundant long hold tail but preserve all original footage. No synthetic poses, splicing, stabilization, or artwork alteration. Actual Godot acceptance pending.')]

for take, frames, contact, note in items:
 out=p.SOURCE_DIR/take
 assert (out/'original.json').is_file() and (out/'matte_v3.json').is_file()
 selection=dict(source_frames=frames,matte_directory='matte_v3',frame_msec=83,frame_durations_msec=[83]*len(frames),review_note=note)
 if contact is not None: selection['contact_frame']=contact
 if take.startswith('defend'):selection['static_frame']=len(frames)-1
 p.write(out/'selection.json',selection)
 p.write(out/'review.json',dict(status='source_accepted_pending_runtime',source_interval=[frames[0],frames[-1]],selected_frames=len(frames),original_sha256=p.sha(out/'original_lossless.mkv'),review=note))
 p.build(out,json.loads((out/'config.json').read_bytes()))
 print(take,len(frames),flush=True)
