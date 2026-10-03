"""Build uniquely selected original corrected poses and fixed native review plates."""
import json
from pathlib import Path
from PIL import Image, ImageDraw
import produce as p

selections = {
 'attack_h3_v2': ([0,12,20,28,34,38,40,41,42,43,44,45,46,47,48,50,54,62,70,76,82,86,88,90,91,92,93,94,95,96,97,98,100,104,112,122],13,13,
 'All124 original RGB and alpha poses personally reviewed chronologically and eight enlarged original/light/dark views. One six-legged cannon and one two-armed/two-legged operator retain attached anatomy, complete round muzzle, two gauges and chimney. A supported forward pressure shove follows anticipation, near-knee flex and rear extension; operator widens stance and leans with both hands on the original bar. No exterior emission or barrel growth. Consecutive original43..48 and90..98 preserve rapid joint transitions; quiet peak/ready holds trimmed without duplicated or invented frames. Native/reflected/live acceptance pending.'),
 'ranged_h3_v3': ([0,8,16,20,24,28,32,36,38,40,42,44,46,48,50,54,58,62,64,66,68,70,71,72,73,74,78,82,100,122],11,13,
 'All124 original RGB and alpha poses personally reviewed chronologically and eight enlarged original/light/dark views. Original inner barrel compresses inside its fixed sleeve, operator bends elbows and knees with both hands on the original control, then piston springs back; muzzle opening/rings/diameter and original maximum barrel length remain constant. Six attached legs, one operator, two gauges, chimney and contained orange heat remain intact. No exterior beam/flash or erased muzzle. Consecutive71..74 preserve the quick spring reset; quiet holds trimmed using unique original frames. Native/reflected/live acceptance pending.')
}

for take,(indices,contact,static,note) in selections.items():
 out=p.SOURCE_DIR/take
 assert not (out/'selection.json').exists(), 'Do not replace an existing reviewed selection'
 p.write(out/'selection.json',dict(source_frames=indices,matte_directory='matte_v3',frame_msec=42,contact_frame=contact,static_frame=static,review_note=note))
 p.build(out,json.loads((out/'config.json').read_bytes()))
 frames=json.loads((out/'handoff.json').read_bytes())['units'][0]['frames']
 sheet=Image.new('RGB',(1400,((len(frames)+3)//4)*280),(44,52,46));d=ImageDraw.Draw(sheet)
 for j,f in enumerate(frames):
  x,y=j%4*350,j//4*280
  if j%2: sheet.paste((220,214,200),(x,y,x+350,y+280))
  im,(dx,dy)=p.source_pose(f)
  sheet.paste(im,(x+175+dx,y+250+dy),im)
  d.text((x+8,y+8),f'{j}: original {f["video_frame"]}',fill=(180,120,75))
 target=p.ROOT/'.artifacts/parallel_animation_20261002'/p.SOURCE_DIR.name/f'{take}_selected_native.png'
 sheet.save(target)
 print(take,len(frames),'unique originals',target)
