"""Record the personally reviewed complete signal and collapse intervals."""
import json
import produce as p

items=[
 ('cast_h3_v1',list(range(17,54,2)),7,
  'All124 original RGB and semantic RGBA frames personally reviewed chronologically, all124 actual128px poses RIGHT and reflected, enlarged20/30/36/48/65 against original RGB and alpha on light/dark. Viewer-left pump operator raises the same connected outer closed BROWN glove at24..39 while inner hand retains pump; right operator tightens original rope with connected gloves. Both original crew and three grounded wheels remain, original stone stays seated, no emitted effects. Select one continuous complete signal17..53, original12fps83ms, recovery by41..53; omit later repeated gesture74..90 while retaining full original footage. No synthetic frames, splicing, stabilization or artwork alteration. Actual Godot acceptance pending.'),
 ('death_h3_v1',list(range(17,112,2)),None,
  'All124 original RGB and semantic RGBA frames personally reviewed chronologically, all124 actual128px poses RIGHT and reflected, enlarged20/38/62/82/110/123 against original RGB and alpha on light/dark. Original arm and wood frame lower/fracture, three original wheels tilt onto ground with physical wood fragments, both original red-tunic operators kneel then lie separately prone beside wreck; seated stone cools to dark by82 and remains cold. Select continuous ready-to-cold-held-wreck17..111 at original12fps83ms and hold final111, matching personally reviewed final123. No disappearance, extra crew, explosion, flame emission, canvas clip, splicing, synthetic poses or artwork alteration. Actual Godot acceptance pending.')]

for take,frames,contact,note in items:
 out=p.SOURCE_DIR/take
 assert (out/'original.json').is_file() and (out/'matte_v3.json').is_file()
 selection=dict(source_frames=frames,matte_directory='matte_v3',frame_msec=83,frame_durations_msec=[83]*len(frames),review_note=note)
 if contact is not None:selection['contact_frame']=contact
 if take.startswith('death'):selection['static_frame']=len(frames)-1
 p.write(out/'selection.json',selection)
 p.write(out/'review.json',dict(status='source_accepted_pending_runtime',source_interval=[frames[0],frames[-1]],selected_frames=len(frames),original_sha256=p.sha(out/'original_lossless.mkv'),review=note))
 p.build(out,json.loads((out/'config.json').read_bytes()))
 print(take,len(frames),flush=True)
p.assemble()
handoff=json.loads((p.SOURCE_DIR/'handoff.json').read_bytes())['units'][0]
print('ALL_ACTION_HANDOFFS', {k:len(v['indices']) for k,v in handoff['clips'].items()},flush=True)
