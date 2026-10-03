"""Repack exact native death cells without rescaling or altering foreground pixels."""
from pathlib import Path
import json,math,sys
from PIL import Image,ImageDraw
UID='unit_neutral_cinderwake_aurochs'
for arg in sys.argv[1:]:
 out=Path(arg);patch=json.loads((out/'candidate_patch.json').read_bytes())['units'][0];row=patch['animation']
 names=list(patch['replaced_clips'])
 if 'idle' not in names:names.insert(0,'idle')
 im=Image.open(out/(UID+'-overview.png')).convert('RGB');rh=row.get('pose_reference_height',row['pose_frame_size']['height']);extent=120.0
 for x,y,w,h in row.get('pose_frame_rects',[]):
  ax=row['pose_region_anchors'][f'{x},{y}'][0];extent=max(extent,max(abs(ax),abs(w-ax))*128/rh)
 cw=max(260,math.ceil(extent*2)+20);cols=im.width//cw;assert cols*cw==im.width
 used=0;cells=[]
 for name in names:
  spec=row['pose_clips'][name]
  if name=='death':
   for i in range(spec['frames']):cells.append(im.crop(((i%cols)*cw,35+(used+i//cols)*190,(i%cols+1)*cw,35+(used+i//cols+1)*190)))
  used+=math.ceil(spec['frames']/cols)
 assert used*190+35==im.height,(names,used,im.height)
 for start in range(0,len(cells),25):
  selected=cells[start:start+25];page=Image.new('RGB',(cw*5,math.ceil(len(selected)/5)*190+35),im.getpixel((im.width-1,im.height-1)));draw=ImageDraw.Draw(page);draw.text((5,5),out.name+' / exact native128 / chronological death '+str(start)+'+',fill=(240,240,220))
  for i,cell in enumerate(selected):
   x=(i%5)*cw;y=35+(i//5)*190;page.paste(cell,(x,y));assert page.crop((x,y,x+cw,y+190)).tobytes()==cell.tobytes()
  page.save(out/f'death-native-{start//25}.png')
 print('EXACT_DEATH_NATIVE',out,len(cells),flush=True)
