"""Review original moving wheel detail without manufacturing wheel articulation."""
import hashlib
import json
import av
import cv2
import numpy as np
from PIL import Image, ImageDraw
import produce as p

folder=p.SOURCE_DIR/'move_h3_v5'
record=json.loads((folder/'original.json').read_bytes())
assert p.sha(folder/'original_lossless.mkv')==record['sha256']
with av.open(str(folder/'original_lossless.mkv')) as video:
    frames=[f.to_image().convert('RGB') for f in video.decode(video=0)]
assert len(frames)==124
template=np.asarray(frames[0])[488:524,936:970].copy()
centers=[]
for i,im in enumerate(frames):
    assert hashlib.sha256(im.tobytes()).hexdigest()==record['decoded_rgb_sha256'][i]
    a=np.asarray(im)
    expected=953 if not centers else centers[-1][0]
    left=max(0,expected-30);right=min(im.width,expected+32)
    search=a[470:540,left:right]
    match=cv2.matchTemplate(search,template,cv2.TM_CCOEFF_NORMED)
    _,quality,_,(x,y)=cv2.minMaxLoc(match)
    centers.append((left+x+17,470+y+18))
target=p.ROOT/'.artifacts/heliograph_ballista_h3/move_h3_v5'
target.mkdir(parents=True,exist_ok=True)
for page in range(8):
    sheet=Image.new('RGB',(1280,1040),(28,38,28));draw=ImageDraw.Draw(sheet)
    for j,i in enumerate(range(page*16,min(124,(page+1)*16))):
        x,y=j%4*320,j//4*260
        cx,cy=centers[i]
        # The observer follows the immutable hub solely to enlarge its spokes.
        # These coordinates are not qualified for source integration.
        crop=frames[i].crop((cx-69,cy-74,cx+69,cy+76)).resize((220,240),Image.Resampling.NEAREST)
        sheet.paste(crop,(x+50,y+20));draw.text((x+7,y+3),f'original {i} hub~{cx},{cy}',fill=(225,208,160))
    sheet.save(target/f'wheel_rgb_{page:02}.png')
print('ORIGINAL_WHEEL_DETAIL_READY; observer only, no extraction anchor acceptance',flush=True)
