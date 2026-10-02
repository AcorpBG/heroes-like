"""Select a fully contained, original four-wing cycle; native CPU review."""
import json
from PIL import Image,ImageDraw
import produce as p
from prepare import reference

if __name__=='__main__':
    out=p.SOURCE_DIR/'move_h3_v1';c=json.loads((out/'config.json').read_bytes())
    indices=list(range(54,79))
    note='Personally reviewed all124 lossless original RGB and all124 enlarged semantic RGBA frames. Select the contained54-78 wing cycle: original rising wingbeat54, down/fanning pass60-64, recovery68-73 and raised-wing seam78. Four wings remain attached, two talons tucked/flexing and two tail ribbons flex coherently. Exclude early19-20/later87-88 genuinely clipped extreme downstrokes and borderline41; no cropped anatomy enters this selection. One fixed scale/anchor, no stabilisation, interpolation or synthetic articulation. Native right/reflected Godot playback acceptance remains pending.'
    p.write(out/'selection.json',dict(source_frames=indices,frame_msec=42,review_note=note))
    p.build(out,c)
    h=json.loads((out/'handoff.json').read_bytes())['units'][0]
    review=p.ROOT/'.artifacts/noonshard_prism_kite_h3/flight_native_cpu.png'
    frames=h['frames']+[dict(reference(i),clip='idle',name=f'original_idle_{i}') for i in range(16,24)]
    sheet=Image.new('RGB',(1600,1080),(30,40,30));draw=ImageDraw.Draw(sheet)
    for cell,frame in enumerate(frames):
        x,y=cell%8*200,cell//8*216
        if cell%2:sheet.paste((218,211,193),(x,y,x+200,y+216))
        f=dict(frame,scale=frame['scale']*.5)
        im,(dx,dy)=p.source_pose(f,frame.get('alpha_noise_cutoff',0))
        sheet.paste(im,(x+100+dx,y+200+dy),im)
        draw.text((x+5,y+4),f'{frame["clip"]} {frame.get("video_frame",cell)}',fill=(140,115,75))
    sheet.save(review)
    print('Selected25 original contained wing phases; CPU native scale and idle comparison prepared.',flush=True)
