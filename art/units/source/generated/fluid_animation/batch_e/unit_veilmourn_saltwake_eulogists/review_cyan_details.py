"""Original and corrected support glass/contour at full source scale."""
import av
from PIL import Image,ImageDraw
import produce as p
indices=[6,22,34,46,60,76,100]
out=p.SOURCE_DIR/'cast_h3_v1';target=p.ROOT/'.artifacts/parallel_animation_20261002/unit_veilmourn_saltwake_eulogists/cyan_key_probe'
frames={i:f.to_image().convert('RGB') for i,f in enumerate(av.open(str(out/'original_lossless.mkv')).decode(video=0)) if i in indices}
for part in range(2):
 chosen=indices[part*4:(part+1)*4];sheet=Image.new('RGB',(1050,len(chosen)*550),(25,30,25));d=ImageDraw.Draw(sheet)
 for row,i in enumerate(chosen):
  rect=(330,35,680,570);rgb=frames[i].crop(rect);rgba=Image.open(out/'cyan_key_probe/matte'/f'rgba_{i:03}.png').crop(rect)
  for col in range(3):
   x=col*350;y=row*550
   if col==0:sheet.paste(rgb,(x,y+15))
   else:sheet.paste((220,211,190) if col==2 else (25,30,25),(x,y,x+350,y+550));sheet.paste(rgba,(x,y+15),rgba)
   d.text((x+3,y+2),str(i)+' '+['original RGB','corrected dark','corrected light'][col],fill='white' if col<2 else 'black')
 sheet.save(target/f'details_{part}.png')
