"""Rebuild missing disposable mattes, requiring every retained final PNG hash."""
import argparse,hashlib,io,json
from pathlib import Path
import av
from PIL import Image
import produce as p
from creature_animation_lock import exclusive

parser=argparse.ArgumentParser();parser.add_argument('takes',nargs='+');args=parser.parse_args()
assert 1<=len(args.takes)<=2
pending=[]
for name in args.takes:
 assert Path(name).name==name and '_h3_v' in name
 out=p.SOURCE_DIR/name;rec=json.loads((out/'matte.json').read_bytes())
 assert (out/'edge_despill.json').exists(),'Only completed final plate recipes can be restored'
 missing=[i for i,h in enumerate(rec['rgba_sha256']) if h and not (out/'matte'/f'rgba_{i:03}.png').exists()]
 for i,h in enumerate(rec['rgba_sha256']):
  file=out/'matte'/f'rgba_{i:03}.png'
  if h and file.exists():assert p.sha(file)==h,'Retained source changed'
 if missing:pending.append((out,rec,missing))
if pending:
 with exclusive('gpu'):
  import segment
  from edge_despill import clean
  net=segment.model()
  for out,rec,missing in pending:
   original=json.loads((out/'original.json').read_bytes());assert p.sha(out/'original_lossless.mkv')==original['sha256']
   with av.open(str(out/'original_lossless.mkv')) as video:
    for i,frame in enumerate(video.decode(video=0)):
     if i not in missing:continue
     rgb=frame.to_image().convert('RGB');assert hashlib.sha256(rgb.tobytes()).hexdigest()==original['decoded_rgb_sha256'][i]
     im,detail=segment.extract(net,rgb);im,_=clean(im,detail['background_rgb'])
     buffer=io.BytesIO();im.save(buffer,format='PNG');raw=buffer.getvalue()
     assert hashlib.sha256(raw).hexdigest()==rec['rgba_sha256'][i],'Rebuilt source differs; retained recipes and frames untouched'
     file=out/'matte'/f'rgba_{i:03}.png';assert not file.exists();file.write_bytes(raw)
   print('EXACT_MATTES_RESTORED',out.name,len(missing),flush=True)
  del net
  import torch
  torch.cuda.empty_cache()
else:print('ALL_RECORDED_MATTES_PRESENT; no GPU acquisition',flush=True)
