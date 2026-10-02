"""CPU uniform-plate extraction comparison, original RGB and fixed geometry."""
import json,hashlib
import av
from PIL import Image
import produce as p
out=p.SOURCE_DIR/'move_h3_v1';c=json.loads((out/'config.json').read_bytes());c['protected_foreground_chroma']=30
rec=json.loads((out/'original.json').read_bytes());dest=out/'key_matting_probe';dest.mkdir(exist_ok=True)
results=[]
with av.open(str(out/'original_lossless.mkv')) as vid:
 for i,frame in enumerate(vid.decode(video=0)):
  rgb=frame.to_image().convert('RGB');assert hashlib.sha256(rgb.tobytes()).hexdigest()==rec['decoded_rgb_sha256'][i]
  try:im,detail=p.key(rgb,c)
  except ValueError as exc:results.append(dict(frame=i,sha256=None,bounds=None,excluded_reason=str(exc)));continue
  f=dest/f'rgba_{i:03}.png';im.save(f);results.append(dict(frame=i,sha256=p.sha(f),bounds=im.getbbox(),detail=detail))
assert len(results)==124
p.write(out/'key_matting_probe.json',dict(frames=results,protected_foreground_chroma=30,tool_sha256=p.sha(p.SOURCE_DIR/'produce.py'),reason='Semantic mask dropped original blue saltglass on green plate. Compare uniform-plate chroma extraction preserving existing RGB source and all source coordinates; no painted alpha or contours.'))
# Reuse source review layout on the comparison directory.
p.write(dest/'matte.json',dict(rgba_sha256=[r['sha256'] for r in results]));(dest/'matte').mkdir(exist_ok=True)
for f in dest.glob('rgba_*.png'):
 f.replace(dest/'matte'/f.name)
p.review(dest,c)
print('KEY_COMPARISON',len([r for r in results if r['sha256']]),'excluded',[r['frame'] for r in results if not r['sha256']])

