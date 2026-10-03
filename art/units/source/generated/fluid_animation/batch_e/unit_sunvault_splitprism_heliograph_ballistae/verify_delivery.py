"""Prove seven published action pixels, anchors, hashes and preserved exact idle."""
import argparse,hashlib,json
from pathlib import Path
import av
from PIL import Image
import produce as p
from integrate_fluid_creature_animation import old_pose,source_pose,clip_indices,resolve
from pack_overworld_creature_idle import extract

UID=p.SOURCE_DIR.name
REQUIRED={'move','attack','ranged','hit','defend','cast','death'}
def read(path):return json.loads(Path(path).read_bytes())
def equal_pose(a,b):
    assert a[1]==b[1],(a[1],b[1]);assert a[0].size==b[0].size;assert a[0].tobytes()==b[0].tobytes()

def verify(baseline):
    oldrows=read(baseline/'baseline_manifest.json')['items'];rows=read(p.ROOT/'content/unit_animation_manifest.json')['items']
    assert [r for r in oldrows if r['unit_id']!=UID]==[r for r in rows if r['unit_id']!=UID]
    new=next(r for r in rows if r['unit_id']==UID);old=next(r for r in oldrows if r['unit_id']==UID)
    sheet=Image.open(resolve(new['pose_sheet'])).convert('RGBA')
    assert max(sheet.size)<=4096 and sheet.width*sheet.height*4<=64*1024*1024
    handoff=read(p.SOURCE_DIR/'handoff.json')['units'][0];assert set(handoff['clips'])==REQUIRED
    published=0
    for name,spec in handoff['clips'].items():
        live=clip_indices(new['pose_clips'][name],new['pose_columns']);assert len(live)==len(spec['indices'])
        for idx,packed in zip(spec['indices'],live):
            frame=handoff['frames'][idx];original=Image.open(p.ROOT/frame['source']).convert('RGBA')
            bounds=original.getchannel('A').point(lambda a:255 if a>=8 else 0).getbbox()
            assert bounds and bounds[0]>0 and bounds[1]>0 and bounds[2]<original.width and bounds[3]<original.height,('Clipped original wheel/operator/launcher',frame['source'],bounds)
            assert frame['rects']==[[0,0,*original.size]] and frame['scale']==.45 and frame['anchor']==[480,576]
            equal_pose(source_pose(frame,0),old_pose(sheet,new,packed));published+=1
    for rec in handoff['provenance'].values():assert p.sha(p.ROOT/rec['path'])==rec['sha256'],rec['path']
    assert new['pose_clips']['dead']['indices']==[new['pose_clips']['death']['indices'][-1]]
    assert set(new['pose_accepted_clips'])==REQUIRED|{'idle'}
    assert 'cast' not in new.get('pose_aliases',{})
    assert 'ranged' not in new.get('pose_aliases',{})
    oldmap=read(baseline/'baseline_map.json')['units'];newmap=read(p.ROOT/'art/overworld/creature_idle.json')['units']
    assert {k:v for k,v in oldmap.items() if k!=UID}=={k:v for k,v in newmap.items() if k!=UID}
    rebuilt,meta=extract(new);actual=Image.open(resolve(newmap[UID]['path'])).convert('RGBA')
    assert max(actual.size)<=4096
    assert rebuilt.size==actual.size and rebuilt.tobytes()==actual.tobytes()
    assert {k:v for k,v in newmap[UID].items() if k!='sha256'}==meta
    assert newmap[UID]['sha256']==p.sha(resolve(newmap[UID]['path']))
    assert newmap[UID]['source_sheet']==new['pose_sheet'] and newmap[UID]['source_sha256']==p.sha(resolve(new['pose_sheet']))
    assert newmap[UID]['source_indices']==clip_indices(new['pose_clips']['idle'],new['pose_columns'])
    baseline_idle=Image.open(baseline/'baseline_map_idle.png').convert('RGBA')
    assert actual.size==baseline_idle.size and actual.tobytes()==baseline_idle.tobytes()
    assert newmap[UID]['frame_msec']==oldmap[UID]['frame_msec']==240
    baseline_sheet=Image.open(baseline/'baseline_atlas.png').convert('RGBA')
    before=clip_indices(old['pose_clips']['idle'],old['pose_columns']);after=clip_indices(new['pose_clips']['idle'],new['pose_columns'])
    assert len(before)==len(after)==8
    for a,b in zip(before,after):equal_pose(old_pose(baseline_sheet,old,a),old_pose(sheet,new,b))
    hashes_total=0;delivery=read(p.SOURCE_DIR/'delivery.json')
    originals=[]
    for take_name in delivery['takes']+delivery.get('rejected_takes',[]):
        take=p.SOURCE_DIR/take_name
        if (take/'config.json').exists() and read(take/'config.json').get('composite'):
            recipe=read(take/'recipe.json')
            originals.extend([recipe['body'],recipe['wheels']])
            assert read(take/'matte.json')['recipe_sha256']==p.sha(take/'recipe.json')
            for frame in recipe['frames']:
                i=frame['frame']
                for key,parent in [('body',recipe['body']),('wheel',recipe['wheels'])]:
                    assert frame[key+'_sha256']==p.sha(p.SOURCE_DIR/parent/'matte'/f'rgba_{i:03}.png')
        else: originals.append(take_name)
    for take_name in dict.fromkeys(originals):
        take=p.SOURCE_DIR/take_name;record=read(take/'original.json');assert p.sha(take/'original_lossless.mkv')==record['sha256']
        with av.open(str(take/'original_lossless.mkv')) as video:hashes=[hashlib.sha256(f.to_image().convert('RGB').tobytes()).hexdigest() for f in video.decode(video=0)]
        assert hashes==record['decoded_rgb_sha256'];hashes_total+=len(hashes)
        for guide in read(take/'reference.json')['guides']:
            assert p.sha(take/guide['input_file'])==guide['input_sha256'];assert p.sha(p.ROOT/guide['source_frame']['source'])==guide['source_sha256']
    print('Original RGB frames:',hashes_total,'published action poses:',published)
    print('Other231 battle/map rows preserved; accepted eight idle poses and map pixels/240ms preserved exactly.')
    print('Atlas:',sheet.size,'RGBA bytes:',sheet.width*sheet.height*4)

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--baseline-dir',type=Path,required=True);args=parser.parse_args();verify(args.baseline_dir)
