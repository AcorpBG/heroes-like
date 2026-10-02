"""Original idle pixels at battle128/map64 reference height, no authored motion."""
import json
from PIL import Image,ImageDraw
import produce as p

UID='unit_neutral_noonshard_prism_kites'
OUT=p.ROOT/'.artifacts/parallel_animation_20261002'/UID
REVIEW=p.ROOT/'.artifacts/noonshard_prism_kite_h3'
if __name__=='__main__':
    OUT.mkdir(parents=True,exist_ok=True)
    for name,path in [('manifest',p.ROOT/'content/unit_animation_manifest.json'),('map',p.ROOT/'art/overworld/creature_idle.json')]:
        target=OUT/f'initial_baseline_{name}.json'
        if not target.exists():target.write_bytes(path.read_bytes())
    row=next(row for row in json.loads((OUT/'initial_baseline_manifest.json').read_bytes())['items'] if row['unit_id']==UID)
    B=p.ROOT/'art/animation/source/poses'/UID
    frames=json.loads((B/'packing.json').read_bytes())['frames']
    sheet=Image.new('RGB',(1024,560),(30,40,30));draw=ImageDraw.Draw(sheet)
    animations=[]
    for cell,index in enumerate(row['pose_clips']['idle']['indices']):
        f=dict(frames[index]);f['source']=(B/f['source']).relative_to(p.ROOT).as_posix()
        im,(x,y)=p.source_pose(f,8)
        native=Image.new('RGBA',(512,256));native.alpha_composite(im,(256+x,248+y))
        native=native.resize((256,128),Image.Resampling.LANCZOS)
        x0,y0=cell%4*256,cell//4*280
        draw.text((x0+8,y0+5),f'{cell}: {index}, {cell*200}ms',fill='white')
        sheet.paste(native,(x0,y0+22),native)
        draw.line((x0,y0+146,x0+256,y0+146),fill=(95,100,60))
        small=native.resize((128,64),Image.Resampling.LANCZOS)
        sheet.paste(small,(x0+64,y0+170),small)
        draw.line((x0+64,y0+232,x0+192,y0+232),fill=(95,100,60))
        movie=Image.new('RGB',(256,150),(30,40,30));movie.paste(native,(0,10),native);animations.append(movie)
    sheet.save(REVIEW/'original-idle-native.png')
    animations[0].save(REVIEW/'original-idle-native.gif',save_all=True,append_images=animations[1:],duration=200,loop=0)
    p.write(p.SOURCE_DIR/'idle_retention.json',dict(unit_id=UID,original_indices=row['pose_clips']['idle']['indices'],original_frame_msec=200,original_pose_source_sha256={f['source']:p.sha(B/f['source']) for f in frames[16:24]},status='pending_actual_godot_native_review',rule='Preserve exact original battle/map artwork, anchors and timing only after native review; no duplicate frame padding.'))
    print('EIGHT_ORIGINAL_IDLE_PHASES_AT128_AND64',flush=True)
