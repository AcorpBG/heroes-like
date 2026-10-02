"""Extract the personally reviewed complete guard before invalid firing.

Caller must hold shared GPU for model load, extraction and terminal completion.
The pinned full-source RGB, all unused intervals and original pixels remain.
"""
import json,hashlib,time
from pathlib import Path
import av
from PIL import Image,ImageDraw
import segment as base
import produce as p

if __name__=='__main__':
 out=p.SOURCE_DIR/'defend_h3_v1';record=json.loads((out/'original.json').read_bytes())
 assert p.sha(out/'original_lossless.mkv')==record['sha256']
 assert not (out/'matte.json').exists() and not (out/'matte_plate_v3').exists()
 review=json.loads((out/'source_interval_review.json').read_bytes())
 assert review['retained_continuous_source_interval']==[0,41] and review['reviewed_original_rgb_frames']==124
 target=out/'matte_plate_v3';target.mkdir();net=base.model();hashes=[None]*124;details=[];start=time.time();seen=0
 with av.open(str(out/'original_lossless.mkv')) as video:
  for i,frame in enumerate(video.decode(video=0)):
   rgb=frame.to_image().convert('RGB');assert hashlib.sha256(rgb.tobytes()).hexdigest()==record['decoded_rgb_sha256'][i];seen+=1
   if i>41:continue
   im,detail=base.extract(net,rgb);f=target/f'rgba_{i:03}.png';im.save(f);hashes[i]=p.sha(f);details.append(dict(source_frame=i,**detail))
   if i%12==0:print('GUARD_INTERVAL',i,round(time.time()-start,1),flush=True)
 assert seen==124 and all(hashes[:42]) and all(x is None for x in hashes[42:])
 recipe=dict(matte_directory='matte_plate_v3',frames=42,decoded_source_frames=124,fps=24,rgba_sha256=hashes,background_frames=details,retained_continuous_source_interval=[0,41],excluded_invalid_source_interval=[42,123],recipe='Pinned original BiRefNet/strict uniform-plate extraction unchanged. Extract only personally reviewed continuous ready-to-kneeling guard0-41. Later firing42-106 and unused remaining source107-123 have no generated matte and are never selected. All124 original RGB hashes verified. No overlapping-effect erasure, color-threshold relaxation, interpolation, reversed phases or painted anatomy.',model_manifest=json.loads((base.BASE/'model_manifest.json').read_bytes()),inference_precision='float16',torch_version=base.torch.__version__,gpu=base.torch.cuda.get_device_name(),elapsed_seconds=round(time.time()-start,3),tool_sha256=p.sha(Path(__file__)),segmentation_tool=Path(__file__).relative_to(p.ROOT).as_posix(),base_tool_sha256=p.sha(p.SOURCE_DIR/'segment.py'))
 p.write(out/'matte.json',recipe);p.write(out/'segmentation_recipe.json',recipe)
 dest=p.ROOT/'.artifacts/parallel_animation_20261002/unit_brasshollow_tallyspring_throwers/defend_h3_v1';dest.mkdir(exist_ok=True)
 for bg,label in [((32,34,39),'dark'),((217,211,195),'light')]:
  sheet=Image.new('RGB',(8*240,6*178),bg);draw=ImageDraw.Draw(sheet)
  for i in range(42):
   x=i%8*240;y=i//8*178;im=Image.open(target/f'rgba_{i:03}.png').convert('RGBA').resize((240,160));sheet.paste(im,(x,y+18),im);draw.text((x+4,y+3),str(i),fill='white' if label=='dark' else 'black')
  sheet.save(dest/f'guard_rgba_{label}.png')
 print('GUARD_INTERVAL_EXTRACTED',42,'original source frames preserved',seen,flush=True)
