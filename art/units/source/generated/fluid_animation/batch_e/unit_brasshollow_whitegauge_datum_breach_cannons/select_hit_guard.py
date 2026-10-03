"""Select personally reviewed original flinch and brace motion without padding."""
import json
from PIL import Image, ImageDraw
import produce as p

selections={
 'hit_h3_v1':([0,16,26,28,30,32,34,36,38,40,42,45,48,50,52,54,56,58,60,62,64,70,80,100,122],
 'Personally reviewed all124 untouched RGB and alpha poses chronologically and enlarged originals0/20/36/45/60/75/100/123 on light/dark backgrounds. Six original attached leg chains absorb backward cannon tilt; one operator bends knees and raises one original hand beside helmet, retaining the other hand on the original bar. The released hand then returns to the bar and loaded joints restore ready. Constant original muzzle/barrel, two gauges, chimney, clothing and two operator boots. No exterior effects or added anatomy. Quiet ready holds trimmed;25 unique originals retain actual recoil/recovery. Native/reflected/live review pending.'),
 'defend_h3_v1':([0,16,28,34,36,38,40,41,42,43,44,45,46,48,50,52,54,56,58,60,62,66,70,75,82,123],
 'Personally reviewed all124 untouched RGB and alpha poses chronologically and enlarged originals0/20/36/45/60/75/100/123 on light/dark backgrounds. Six original attached leg chains flex and spread under the boiler; single operator crouches behind rear plating with two original hands on the control bar and both knees bent. Deep brace settles into the supplied lower grounded held guard; no return to idle. Original round muzzle, barrel dimensions, two gauges, chimney and clothing remain intact. Quiet ready/terminal holds trimmed;26 unique originals preserve consecutive41..46 flex transitions and final123 held pose. Native/reflected/live review pending.')
}
for take,(indices,note) in selections.items():
 out=p.SOURCE_DIR/take;assert not (out/'selection.json').exists()
 p.write(out/'selection.json',dict(source_frames=indices,matte_directory='matte_v3',frame_msec=42,review_note=note))
 p.build(out,json.loads((out/'config.json').read_bytes()))
 frames=json.loads((out/'handoff.json').read_bytes())['units'][0]['frames']
 sheet=Image.new('RGB',(1400,((len(frames)+3)//4)*280),(44,52,46));d=ImageDraw.Draw(sheet)
 for j,f in enumerate(frames):
  x,y=j%4*350,j//4*280
  if j%2:sheet.paste((220,214,200),(x,y,x+350,y+280))
  im,(dx,dy)=p.source_pose(f);sheet.paste(im,(x+175+dx,y+250+dy),im)
  d.text((x+8,y+8),f'{j}: original {f["video_frame"]}',fill=(180,120,75))
 target=p.ROOT/'.artifacts/parallel_animation_20261002'/p.SOURCE_DIR.name/f'{take}_selected_native.png';sheet.save(target)
 print(take,len(frames),'unique originals',target)
