from pathlib import Path
import argparse,sys
ROOT=Path(__file__).resolve().parents[5]
sys.path[:0]=[str(ROOT/'tools'),str(ROOT/'tests')]
from creature_animation_lock import exclusive
import fluid_creature_animation_regression as f
base=f.SCRIPT.replace('func cell_width()->int:return maxi(155,','func cell_width()->int:return maxi(260,')
parser=argparse.ArgumentParser(description='Render both 128px candidate facings; inspect outputs personally before publishing.')
parser.add_argument('--godot',required=True)
parser.add_argument('--patch',type=Path,required=True)
parser.add_argument('--output',type=Path,required=True)
a=parser.parse_args()
with exclusive('gpu'):
 for mirrored in [False,True]:
  f.SCRIPT=base
  if mirrored:
   old='var rect:Rect2=Pose.grounded_rect(ground,128,region,row)'
   assert f.SCRIPT.count(old)==1
   f.SCRIPT=f.SCRIPT.replace(old,'var rect:Rect2=Pose.grounded_rect(ground,128,region,row,true)')
   old='var rect:Rect2=Pose.grounded_rect(ground,128 if sample==0 else 64,region,row)'
   assert f.SCRIPT.count(old)==1
   f.SCRIPT=f.SCRIPT.replace(old,'var rect:Rect2=Pose.grounded_rect(ground,128 if sample==0 else 64,region,row,true)')
   old='\t\t\t\tdraw_texture_rect_region(sheet,rect,region)'
   assert f.SCRIPT.count(old)==2
   f.SCRIPT=f.SCRIPT.replace(old,'\t\t\t\tdraw_set_transform(Vector2(rect.end.x,0),0,Vector2(-1,1))\n\t\t\t\tdraw_texture_rect_region(sheet,Rect2(Vector2(0,rect.position.y),rect.size),region)\n\t\t\t\tdraw_set_transform(Vector2.ZERO,0,Vector2.ONE)')
  sys.argv=[f.__file__,'--godot',a.godot,'--patch',str(a.patch.resolve()),'--render','--contacts-only','--output',str(a.output.resolve()/('reflected' if mirrored else 'normal'))]
  code=f.main()
  if code:raise SystemExit(code)
