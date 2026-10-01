"""Prepare original-only Harbor walk review and full existing-action candidate."""
import json
from PIL import Image, ImageDraw
import produce as p
from publish_fluid_creature_animation import combine

OUT = p.SOURCE_DIR / 'move_h3_v3'
TASK = p.ROOT / '.artifacts/creature_sets_20261001'

def main():
    indices = list(range(13,92,2))
    note = ('All124 original chronological mattes inspected, both traceable leg chains exchange leading heel contact/load. '
            'Foreground broad thigh leads around20; it trails at the reviewed opposite contact65 while background leg leads. '
            'Selected13..91 every2 original frames contains both complete steps with grounded passing/double support, '
            'not a repeated same-leg block. Both hands retain one rigid shaft and forearm buckler; cap, coat, boots and belt props stable. '
            'Native original-only phases, alpha on light/dark and loop13/91 still require final review. No continuous playback claim.')
    selection = dict(source_frames=indices,frame_msec=50,review_note=note)
    p.write(OUT/'selection.json', selection)
    p.build(OUT,json.loads((OUT/'config.json').read_bytes()))
    entry = json.loads((OUT/'handoff.json').read_bytes())['units'][0]
    p.write(p.SOURCE_DIR/'handoff_move_v3.json',dict(schema_version=1,units=[entry]))
    baseline_path = p.SOURCE_DIR/'before_move_v3_handoff.json'
    previous_path = p.ROOT/'art/animation/source/fluid/unit_neutral_harbor_polearms/reviewed_handoff.json'
    if not baseline_path.exists():
        baseline_path.write_bytes(previous_path.read_bytes())
    before=json.loads(baseline_path.read_bytes())['units'][0]
    full=combine(before,entry)
    full['provenance'].update({f'previous_{name}':record for name,record in before['provenance'].items()})
    full['provenance']['retained_reviewed_handoff'] = dict(path=baseline_path.relative_to(p.ROOT).as_posix(),sha256=p.sha(baseline_path))
    full['preserved_accepted_clips']=['idle']
    full['visual_review']=dict(status='pending',notes=note+' Other five published actions retain exact original source selection/timing.')
    p.write(p.SOURCE_DIR/'handoff_complete_v3.json',dict(schema_version=1,units=[full]))
    # Fixed common crop and scale for review; thumbnails do not create motion.
    all_indices=list(dict.fromkeys(indices+[12,13,14,20,21,39,40,41,63,64,65,66,67,89,90,91,92]))
    bounds=[Image.open(OUT/'matte'/f'rgba_{i:03}.png').getbbox() for i in all_indices]
    crop=(min(b[0] for b in bounds)-4,min(b[1] for b in bounds)-4,max(b[2] for b in bounds)+4,max(b[3] for b in bounds)+4)
    for start in range(0,len(all_indices),20):
        subset=all_indices[start:start+20]
        sheet=Image.new('RGB',(1600,5*360),(35,45,35));draw=ImageDraw.Draw(sheet)
        for j,i in enumerate(subset):
            x,y=j%4*400,j//4*360
            if j%2:sheet.paste((229,224,209),(x,y,x+400,y+360))
            im=Image.open(OUT/'matte'/f'rgba_{i:03}.png').crop(crop)
            im.thumbnail((392,330),Image.Resampling.LANCZOS)
            sheet.paste(im,(x+(400-im.width)//2,y+22),im)
            draw.text((x+6,y+4),str(i),fill=(170,120,70))
        sheet.save(TASK/f'harbor_walk_detail_{start}.png')
    print('Pending full candidate:160 preserved action frames +',len(indices),'new walk frames, idle8 retained')

if __name__=='__main__':
    main()
