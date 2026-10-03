"""Preserve the actual Heliograph source lineage and prepare personal review."""
import copy
import hashlib
import json
from pathlib import Path
from PIL import Image, ImageDraw
import produce as p
from creature_animation_lock import exclusive
from integrate_fluid_creature_animation import resolve, old_pose

UID=p.SOURCE_DIR.name
S=p.SOURCE_DIR
OUT=p.ROOT/'.artifacts/parallel_animation_20261003'/UID
REV=p.ROOT/'.artifacts/heliograph_ballista_h3/originals'

def immutable(path, value):
    if path.exists():
        assert json.loads(path.read_bytes())==value, f'Existing baseline differs: {path}'
    else:
        p.write(path,value)

def main():
    OUT.mkdir(parents=True,exist_ok=True)
    REV.mkdir(parents=True,exist_ok=True)
    with exclusive('content'):
        manifest=json.loads((p.ROOT/'content/unit_animation_manifest.json').read_bytes())
        row=next(r for r in manifest['items'] if r['unit_id']==UID)
        mapping=json.loads((p.ROOT/'art/overworld/creature_idle.json').read_bytes())
        immutable(S/'original_unit_baseline.json',row)
        immutable(S/'original_map_baseline.json',mapping['units'][UID])
        for label, data in [('manifest',manifest),('map',mapping)]:
            file=OUT/f'initial_baseline_{label}.json'
            if not file.exists():p.write(file,data)
        for filename, source in [('baseline_atlas.png',resolve(row['pose_sheet'])),('baseline_map_idle.png',resolve(mapping['units'][UID]['path']))]:
            target=OUT/filename
            if target.exists():assert p.sha(target)==p.sha(source)
            else:target.write_bytes(source.read_bytes())
        base=p.ROOT/'art/animation/source/poses'/UID
        packing=json.loads((base/'packing.json').read_bytes())
        refs=[]
        for frame in packing['frames']:
            f=copy.deepcopy(frame)
            source=(base/f['source']).resolve()
            assert source.is_relative_to(p.ROOT) and source.is_file()
            f['source']=source.relative_to(p.ROOT).as_posix()
            f['source_sha256']=p.sha(source)
            refs.append(f)
        immutable(S/'original_pose_references.json',refs)
        immutable(S/'identity_lineage.json',dict(unit_id=UID,curated_source=row['curated_source'],curated_sha256=p.sha(resolve(row['curated_source'])),original_packing=packing,original_atlas_sha256=p.sha(resolve(row['pose_sheet'])),original_map_sha256=p.sha(resolve(mapping['units'][UID]['path'])),source_facing=row['pose_source_facing']))
        progress=p.ROOT/'ops/progress.json'
        text=progress.read_text(encoding='utf-8')
        import re
        match=re.search(r'("id"\s*:\s*"art-fluid-creature-animation-20260923".*?"notes"\s*:\s*)("(?:\\.|[^"\\])*")',text,re.S)
        assert match, 'Selected animation slice not found'
        notes=json.loads(match.group(2))
        claim='COORDINATOR ACTIVE 2026-10-03: Heliograph Ballistae reservation released by its prior worker; coordinator owns original source preparation, all seven H3 action sequences, personal visual acceptance, focused integration and cleanup. Existing eight-phase idle will be preserved only after personal review. Five existing workers retain their units; no new agents or setting changes.'
        if claim not in notes:
            replacement=json.dumps(claim+' '+notes,ensure_ascii=False)
            progress.write_text(text[:match.start(2)]+replacement+text[match.end(2):],encoding='utf-8',newline='')
    if not (S/'brief.json').exists():
        p.write(S/'brief.json',dict(unit_id=UID,status='in_progress_original_reference_review',source_facing='left',identity='One original ivory/gold/cobalt Heliograph Ballista siege engine; exactly two large blue/gold spoked wheels, three articulated cobalt/gold stabilizers with star feet, one central blue glass lens, blue front launcher LEFT and amber rear arm RIGHT. Exactly one rear-right ivory/gold human operator, two arms and two legs, blue plume/cape, hands on rear control crank. Fixed elevated tactical camera. No invented wheels, legs, operator, ornaments or magic.',preserve='Original live atlas, map idle and all lineage captured immutably; eight existing 240ms idle poses are pending personal acceptance.',required_new_actions=['move','attack','ranged','hit','defend','cast','death'],review='pending; no generated sequence accepted',safe_background=[190,206,222]))
    # Native 128px reference height: no change to the original live art.
    sheet=Image.open(OUT/'baseline_atlas.png').convert('RGBA')
    count=max(max(c.get('indices',[0])) for c in row['pose_clips'].values())+1
    assert count==len(refs)==24
    for reflected in [False,True]:
        for page in range(3):
            review=Image.new('RGB',(1920,1000),(27,38,29));draw=ImageDraw.Draw(review)
            for slot,index in enumerate(range(page*8,min(count,(page+1)*8))):
                x,y=slot%4*480,slot//4*500
                if slot%2:review.paste((221,213,197),(x,y,x+480,y+500))
                pose,(dx,dy)=old_pose(sheet,row,index)
                # Downsample exactly at the shared battle reference scale.
                native=pose.resize((round(pose.width*.5),round(pose.height*.5)),Image.Resampling.LANCZOS)
                nx,ny=round(dx*.5),round(dy*.5)
                if reflected:native=native.transpose(Image.Transpose.FLIP_LEFT_RIGHT);nx=-nx-native.width
                for multiplier,origin in [(1,(x+170,y+206)),(2,(x+240,y+460))]:
                    image=native.resize((native.width*multiplier,native.height*multiplier),Image.Resampling.NEAREST)
                    px,py=origin[0]+nx*multiplier,origin[1]+ny*multiplier
                    assert x<=px and px+image.width<=x+480 and y+25<=py and py+image.height<=y+500,(index,px,py,image.size)
                    review.paste(image,(px,py),image)
                    draw.line((x+8,origin[1],x+470,origin[1]),fill=(105,132,81))
                draw.text((x+9,y+8),f'{index}: {refs[index]["name"]}; native128 / 2x',fill=(153,113,65))
            review.save(REV/f'live_originals_facing{int(reflected)}_{page}.png')
    # Ready and all eight preserved idle paintings enlarged from original ink.
    detail=Image.new('RGB',(2048,1536),(27,38,29));draw=ImageDraw.Draw(detail)
    for slot,index in enumerate([0]+list(range(16,24))):
        x,y=slot%3*680,slot//3*512
        if slot%2:detail.paste((221,213,197),(x,y,x+680,y+512))
        im,offset=p.source_pose(refs[index],8)
        im=im.resize((im.width*2,im.height*2),Image.Resampling.NEAREST)
        assert im.width<=660 and im.height<=470,(index,im.size)
        detail.paste(im,(x+(680-im.width)//2,y+30),im)
        draw.text((x+8,y+8),f'{index}: {refs[index]["name"]}',fill=(153,113,65))
    detail.save(REV/'original_idle_mechanisms_enlarged.png')
    print('HELIOGRAPH ORIGINAL LINEAGE AND 24 NATIVE POSES READY; VISUAL ACCEPTANCE PENDING',flush=True)

if __name__=='__main__':main()
