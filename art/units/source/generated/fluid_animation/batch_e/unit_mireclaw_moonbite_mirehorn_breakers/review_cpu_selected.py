"""Faithful CPU source phase previews at the game's128/256 scale."""
import json,math,argparse
from PIL import Image,ImageDraw
import produce as p
from integrate_fluid_creature_animation import source_pose
a=argparse.ArgumentParser();a.add_argument('takes',nargs='*');args=a.parse_args()
names=args.takes or json.loads((p.SOURCE_DIR/'delivery.json').read_bytes())['takes']
for take in names:
 if not (p.SOURCE_DIR/take/'handoff.json').exists():continue
 out=p.SOURCE_DIR/take;h=json.loads((out/'handoff.json').read_bytes())['units'][0];sheet=Image.new('RGB',(1920,math.ceil(len(h['frames'])/8)*180),(30,40,30));d=ImageDraw.Draw(sheet)
 for j,f in enumerate(h['frames']):
  x=j%8*240;y=j//8*180
  if j%2:sheet.paste((220,210,190),(x,y,x+240,y+180))
  im,(dx,dy)=source_pose(f,0);im=im.resize((round(im.width*.5),round(im.height*.5)),Image.Resampling.LANCZOS);pos=(round(x+120+dx*.5),round(y+160+dy*.5));assert x<=pos[0] and pos[0]+im.width<=x+240;sheet.paste(im,pos,im);d.line((x,y+160,x+240,y+160),fill=(80,80,70));d.text((x+3,y+3),str(f['video_frame']),fill=(160,110,60))
 target=p.ROOT/'.artifacts/parallel_animation_20261002/unit_mireclaw_moonbite_mirehorn_breakers';sheet.save(target/(take+'_native_cpu.png'))
 mirror=Image.new('RGB',sheet.size,(30,40,30));draw=ImageDraw.Draw(mirror)
 for j,f in enumerate(h['frames']):
  x=j%8*240;y=j//8*180
  if j%2:mirror.paste((220,210,190),(x,y,x+240,y+180))
  im,(dx,dy)=source_pose(f,0);im=im.resize((round(im.width*.5),round(im.height*.5)),Image.Resampling.LANCZOS).transpose(Image.Transpose.FLIP_LEFT_RIGHT)
  pos=(round(x+120-dx*.5-im.width),round(y+160+dy*.5));assert x<=pos[0] and pos[0]+im.width<=x+240;mirror.paste(im,pos,im);draw.line((x,y+160,x+240,y+160),fill=(80,80,70));draw.text((x+3,y+3),str(f['video_frame']),fill=(160,110,60))
 mirror.save(target/(take+'_mirror_cpu.png'))
