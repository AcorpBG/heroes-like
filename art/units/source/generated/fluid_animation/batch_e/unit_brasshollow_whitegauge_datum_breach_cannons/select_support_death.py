"""Select reviewed original valve operation and complete attached collapse."""
import json
from PIL import Image, ImageDraw
import produce as p

selections={
 'cast_h3_v1':([0,12,22,26,28,30,32,34,36,38,40,44,48,50,54,58,62,66,70,74,78,80,82,84,86,88,90,92,94,96,98,100,108,116,122],
 'Personally reviewed all124 untouched RGB and alpha originals chronologically plus enlarged originals0/20/40/50/65/82/105/123 on light/dark backgrounds. One operator raises the original right arm to the original upper pressure-control valve, turns the wrist while checking the two gauges, and returns that hand to the control bar; the left hand stays at the lower control. Six attached leg chains load slightly under the restrained breech tilt. Original barrel, full round muzzle, chimney, gauges, two operator boots and clothing remain intact. Heat stays contained with no exterior effect.35 unique original poses retain the gesture and return; native/reflected/live review pending.'),
 'death_h3_v1':([0,12,22,26,28,29,30,31,32,34,36,38,40,44,48,54,60,64,66,67,68,69,70,71,72,73,74,75,76,77,78,79,80,81,82,83,84,85,86,88,90,94,100,110,123],
 'Personally reviewed all124 untouched RGB and alpha originals chronologically plus enlarged originals0/20/40/50/65/82/105/123 on light/dark backgrounds. Six attached leg chains buckle progressively under the original cannon. The single operator releases the bar, bends both knees, falls with two arms and two boots, and settles prone beside the grounded intact machinery. Original muzzle, barrel rings, two gauges, hoses, valves and chimney remain attached; far limbs occlude naturally. Contained furnace/muzzle heat fades to a completely cold black final aperture and dark goggles.45 unique originals preserve consecutive collapse/fall poses and final123 without revival or extra anatomy; native/reflected/live review pending.')
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
