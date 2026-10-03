"""Current-live, bounded non-upgrade completion review, with original sources.

CPU prepare checks each selected original against its exact packed pose and
provides enlarged identity/contact/support/fall crops. Rendering uses the real
Godot imported textures and grounded pose functions. This never accepts art or
changes a catalog. Personal inspection remains a separate required step.
"""
from pathlib import Path
import argparse, hashlib, json, math, os, subprocess, sys
from PIL import Image, ImageDraw
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'));sys.path.insert(0,str(ROOT/'tests'))
DEFAULT_GODOT=os.environ.get('GODOT_BINARY', 'D:/Games/godot/Godot_v4.6.2-stable_win64_console.exe' if os.name=='nt' else 'godot')

def read(path):return json.loads(path.read_bytes())
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def roster():
    units={r['id']:r for r in read(ROOT/'content/units.json')['items']}
    upgraded={r['upgraded_unit_id'] for es in read(ROOT/'content/town_development.json')['rosters'].values() for r in es}
    non=sorted(set(units)-upgraded)
    assert (len(units),len(upgraded),len(non))==(232,72,160)
    return units,non[:54]

def prepare(output,selected):
    from integrate_fluid_creature_animation import source_pose,old_pose,resolve,clip_indices
    rows={r['unit_id']:r for r in read(ROOT/'content/unit_animation_manifest.json')['items']}
    records=[]
    for uid in selected:
        row=rows[uid];directory=output/'cpu'/uid;directory.mkdir(parents=True,exist_ok=True)
        base=ROOT/'art/animation/source/fluid'/uid
        entry=read(base/'reviewed_handoff.json')['units'][0]
        prov=read(base/'provenance.json');atlas=Image.open(resolve(row['pose_sheet'])).convert('RGBA')
        failures=[];count=0;details=[]
        for name,spec in entry['clips'].items():
            current=row['pose_clips'][name]
            if len(current['indices'])!=len(spec['indices']):failures.append(name+': frame count differs');continue
            for j,i in enumerate(spec['indices']):
                f=entry['frames'][i];source=resolve(f['source']);key='res://'+source.relative_to(ROOT).as_posix()
                if prov['sources'].get(key)!=sha(source):failures.append(name+': original source hash differs '+str(j))
                ink,offset=source_pose(f,f.get('alpha_noise_cutoff',entry.get('alpha_noise_cutoff',0)))
                if entry['source_facing']!=row.get('pose_source_facing','right'):
                    ink=ink.transpose(Image.Transpose.FLIP_LEFT_RIGHT);offset=(-offset[0]-ink.width,offset[1])
                live,live_offset=old_pose(atlas,row,current['indices'][j])
                if ink.size!=live.size or ink.tobytes()!=live.tobytes() or offset!=live_offset:failures.append(name+': packed original pixels/anchor differ '+str(j))
                count+=1
            landmarks=sorted({0,len(spec['indices'])-1,int(spec.get('contact_frame',len(spec['indices'])//2))})
            if name in ['death','cast','attack','ranged']:landmarks=sorted(set(landmarks)|{len(spec['indices'])//3,2*len(spec['indices'])//3})
            for j in landmarks:
                f=entry['frames'][spec['indices'][j]];original=Image.open(resolve(f['source'])).convert('RGBA')
                # Original delivered source rectangles before the registered
                # uniform scale. Atlas sources must show the selected pose,
                # never an accidentally miniaturized whole sprite sheet.
                left=min(r[0] for r in f['rects']);top=min(r[1] for r in f['rects']);right=max(r[2] for r in f['rects']);bottom=max(r[3] for r in f['rects'])
                im=Image.new('RGBA',(right-left,bottom-top))
                for l,t,r,b in f['rects']:im.paste(original.crop((l,t,r,b)),(l-left,t-top))
                bounds=im.getchannel('A').getbbox();details.append((name+' '+str(j)+' original alpha',im.crop(bounds)))
        identity=Image.open(resolve(row['curated_source'])).convert('RGBA');details.insert(0,('Original identity',identity.crop(identity.getchannel('A').getbbox())))
        for start in range(0,len(details),20):
            chunk=details[start:start+20];page=Image.new('RGB',(1200,60+300*math.ceil(len(chunk)/4)),(24,30,24));draw=ImageDraw.Draw(page);draw.text((8,8),uid+' / original retained source ink; preview only',(240,240,220))
            for k,(label,im) in enumerate(chunk):
                im=im.copy();im.thumbnail((284,265),Image.Resampling.LANCZOS);x=(k%4)*300+(300-im.width)//2;y=50+(k//4)*300;page.paste(im,(x,y),im);draw.text(((k%4)*300+5,y+272),label,(240,240,220))
            page.save(directory/f'original-details-{start//20}.png')
        records.append(dict(unit_id=uid,selected_original_packed_checks=count,failures=failures,atlas_sha256=sha(resolve(row['pose_sheet'])),row_sha256=hashlib.sha256(json.dumps(row,sort_keys=True).encode()).hexdigest(),detail_pages=math.ceil(len(details)/20)))
        print('CPU_PREPARED',uid,count,len(failures),flush=True)
    (output/'cpu_sources.json').write_text(json.dumps(records,indent=2)+'\n')
    return int(any(r['failures'] for r in records))

def expected_import_reference(output,selected,godot=DEFAULT_GODOT):
    """Use the actual default importer border operation, no hand approximation."""
    rows={r['unit_id']:r for r in read(ROOT/'content/unit_animation_manifest.json')['items']}
    maps=read(ROOT/'art/overworld/creature_idle.json')['units']
    definitions=[dict(unit_id=uid,atlas=rows[uid]['pose_sheet'],map=maps[uid]['path']) for uid in selected]
    script=output/'expected-import.gd'
    script.write_text('extends SceneTree\nfunc _initialize():\n\tvar definitions:Array=JSON.parse_string('+json.dumps(json.dumps(definitions))+')\n\tfor item in definitions:\n\t\tfor label in ["atlas","map"]:\n\t\t\tvar original:Image=Image.load_from_file(ProjectSettings.globalize_path(item[label]))\n\t\t\toriginal.fix_alpha_edges()\n\t\t\toriginal.save_png('+json.dumps(str(output).replace('\\','/'))+'.path_join(item.unit_id+"-expected-"+label+".png"))\n\tquit()\n')
    try:
        env=dict(os.environ,APPDATA=str(output/'reference_profile'),XDG_DATA_HOME=str(output/'reference_profile'))
        result=subprocess.run([godot,'--headless','--path',str(ROOT),'--script','res://'+script.relative_to(ROOT).as_posix(),'--audio-driver','Dummy'],env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=60,creationflags=subprocess.CREATE_NO_WINDOW if os.name=='nt' else 0)
        assert result.returncode==0,result.stdout.decode(errors='replace')
    finally:script.unlink()

def compare_import(output,selected):
    import numpy as np
    rows={r['unit_id']:r for r in read(ROOT/'content/unit_animation_manifest.json')['items']}
    maps=read(ROOT/'art/overworld/creature_idle.json')['units']
    for uid in selected:
        for label,path in [('atlas',rows[uid]['pose_sheet']),('map',maps[uid]['path'])]:
            original=np.array(Image.open(ROOT/path.removeprefix('res://')).convert('RGBA'))
            expected=np.array(Image.open(output/(uid+'-expected-'+label+'.png')).convert('RGBA'))
            actual=np.array(Image.open(output/(uid+'-imported-'+label+'.png')).convert('RGBA'))
            assert original.shape==actual.shape==expected.shape,(uid,label,'import shape')
            assert np.array_equal(original[:,:,3],actual[:,:,3]),(uid,label,'original import alpha')
            assert np.array_equal(expected[expected[:,:,3]>0],actual[expected[:,:,3]>0]),(uid,label,'default processed import visible pixels')
    print('CURRENT_IMPORTED_VISIBLE_PIXELS_EXACT_AFTER_DEFAULT_BORDER_FIX',selected,flush=True)

def render(output,selected,mirrored,godot=DEFAULT_GODOT):
    import fluid_creature_animation_regression as f
    def replace(old,new,count=1):
        assert f.SCRIPT.count(old)==count,(old,f.SCRIPT.count(old));f.SCRIPT=f.SCRIPT.replace(old,new)
    old='\tfunc cell_width()->int:return maxi(155,ceili(float(row.pose_frame_size.width)*128.0/float(row.get("pose_reference_height",row.pose_frame_size.height)))+20)'
    replace(old,'''\tfunc cell_width()->int:
\t\tvar reference:float=float(row.get("pose_reference_height",row.pose_frame_size.height))
\t\tvar extent:float=120.0
\t\tif row.has("pose_frame_rects"):
\t\t\tfor r in row.pose_frame_rects:
\t\t\t\tvar anchor:Array=row.pose_region_anchors["%d,%d" % [int(r[0]),int(r[1])]]
\t\t\t\textent=maxf(extent,maxf(absf(float(anchor[0])),absf(float(r[2])-float(anchor[0])))*128.0/reference)
\t\telse:
\t\t\tvar anchor:float=float(row.get("pose_anchor_x",float(row.pose_frame_size.width)*.5))
\t\t\textent=maxf(extent,maxf(absf(anchor),absf(float(row.pose_frame_size.width)-anchor))*128.0/reference)
\t\treturn ceili(extent*2.0)+20''')
    needle='\t\t\t\tvar imported:Texture2D=load(row.pose_sheet)'
    replace(needle,needle+'\n\t\t\t\timported.get_image().save_png(OS.get_environment("FLUID_OUTPUT").path_join(change.unit_id+"-imported-atlas.png"))')
    needle='\t\t\t\t\tvar material=Idle.material(pose,change.unit_id,true)'
    replace(needle,'\t\t\t\t\tpose.texture.get_image().save_png(OS.get_environment("FLUID_OUTPUT").path_join(change.unit_id+"-imported-map.png"))\n'+needle)
    if mirrored:
        replace('var rect:Rect2=Pose.grounded_rect(ground,128,region,row)','var rect:Rect2=Pose.grounded_rect(ground,128,region,row,true)')
        replace('\t\t\t\tdraw_texture_rect_region(sheet,rect,region)','\t\t\t\tdraw_set_transform(Vector2(rect.end.x,0),0,Vector2(-1,1))\n\t\t\t\tdraw_texture_rect_region(sheet,Rect2(Vector2(0,rect.position.y),rect.size),region)\n\t\t\t\tdraw_set_transform(Vector2.ZERO,0,Vector2.ONE)',2)
    needle='\t\t\t\t\tbatch.set_motion_enabled(false)'
    replace(needle,'''\t\t\t\t\tfor phase_index in range(int(row.pose_clips.idle.frames)):
\t\t\t\t\t\tmaterial.set_shader_parameter("clock_override",float(material.get_shader_parameter("frame_seconds"))*(float(phase_index)+.01))
\t\t\t\t\t\tvar map_phase:Image=await capture()
\t\t\t\t\t\tmap_phase.save_png(OS.get_environment("FLUID_OUTPUT").path_join(change.unit_id+"-map-phase-"+str(phase_index)+".png"))
'''+needle)
    replace('\t\t\t\t\tvar still:Image=await capture()','\t\t\t\t\tvar still:Image=await capture()\n\t\t\t\t\tstill.save_png(OS.get_environment("FLUID_OUTPUT").path_join(change.unit_id+"-map-reduced.png"))')
    # contacts-only retains every authored hold/grounding check and map checks;
    # the full shell fixture is reserved for an actual suspected live defect.
    sys.argv=[__file__,'--godot',godot,'--live','--unit',*selected,'--render','--contacts-only','--overview-only','--output',str(output)]
    code=f.main()
    expected_import_reference(output,selected,godot);compare_import(output,selected)
    return code

def pages(output,selected):
    rows={r['unit_id']:r for r in read(ROOT/'content/unit_animation_manifest.json')['items']}
    for facing in ['normal','reflected']:
        directory=output/facing
        if not directory.exists():continue
        for uid in selected:
            im=Image.open(directory/(uid+'-overview.png'))
            row=rows[uid];rh=row.get('pose_reference_height',row['pose_frame_size']['height']);extent=120.0
            if row.get('pose_frame_rects'):
                for x,y,w,h in row['pose_frame_rects']:
                    ax=row['pose_region_anchors'][f'{x},{y}'][0];extent=max(extent,max(abs(ax),abs(w-ax))*128/rh)
            else:
                w=row['pose_frame_size']['width'];ax=row.get('pose_anchor_x',w*.5);extent=max(extent,max(abs(ax),abs(w-ax))*128/rh)
            cw=math.ceil(extent*2)+20;columns=im.width//cw;assert cw*columns==im.width
            tile_width=cw*max(1,min(columns,1600//cw));number=0
            for start in range(35,im.height,190*6):
                for left in range(0,im.width,tile_width):
                    # Keep review below the image tool's resize limits while
                    # preserving every native pixel and whole gallery cells.
                    right=min(left+tile_width,im.width);bottom=min(start+190*6,im.height)
                    page=Image.new('RGB',(right-left,35+bottom-start),(30,40,26));draw=ImageDraw.Draw(page);draw.text((5,5),uid+' / '+facing+' / exact128 native; rows '+str((start-35)//190)+'+', (240,240,220));page.paste(im.crop((left,start,right,bottom)),(0,35));page.save(directory/(uid+f'-page-{number}.png'));number+=1
            captures=sorted(directory.glob(uid+'-map-phase-*.png'))+[directory/(uid+'-map-reduced.png')]
            map_page=Image.new('RGB',(1600,260*math.ceil(len(captures)/4)),(30,40,26));draw=ImageDraw.Draw(map_page)
            for k,path in enumerate(captures):
                # Exact unscaled 96px map drawing, entire authored creature ROI.
                source=Image.open(path).convert('RGB')
                from PIL import ImageChops
                bounds=ImageChops.difference(source,Image.new('RGB',source.size,source.getpixel((0,0)))).getbbox()
                assert bounds and bounds[0]>=0 and bounds[1]>=60 and bounds[2]<=400 and bounds[3]<=290,(uid,path,bounds,'map review crop would clip')
                cut=source.crop((0,60,400,290));map_page.paste(cut,((k%4)*400,(k//4)*260));draw.text(((k%4)*400+4,(k//4)*260+237),path.stem.rsplit('-map-',1)[-1],(240,240,220))
            map_page.save(directory/(uid+'-map-pages.png'))

def main():
    a=argparse.ArgumentParser(description=__doc__);a.add_argument('mode',choices=['prepare','lease','resumelease','render','pages']);a.add_argument('--output',type=Path,required=True);a.add_argument('--start',type=int,default=0);a.add_argument('--count',type=int,default=6);a.add_argument('--mirrored',action='store_true');a.add_argument('--godot',default=DEFAULT_GODOT,help='Godot executable; defaults to GODOT_BINARY or the platform default');args=a.parse_args()
    units,partition=roster();selected=partition[args.start:args.start+args.count];assert selected and len(selected)<=6
    output=args.output.resolve();output.mkdir(parents=True,exist_ok=True)
    if args.mode=='prepare':return prepare(output,selected)
    if args.mode=='pages':pages(output,selected);return 0
    if args.mode=='render':
        assert os.environ.get('CREATURE_REVIEW_GPU_LEASE'), 'render is an internal lease child; use lease for GPU serialization'
        return render(output,selected,args.mirrored,args.godot)
    from creature_animation_lock import exclusive
    with exclusive('gpu'):
        import urllib.request
        q=json.load(urllib.request.urlopen('http://127.0.0.1:8189/queue'));assert not q['queue_running'] and not q['queue_pending']
        if args.mode=='resumelease':
            prepared={r['unit_id']:r for r in read(output/'cpu_sources.json')}
            rows={r['unit_id']:r for r in read(ROOT/'content/unit_animation_manifest.json')['items']}
            for uid in selected:assert sha(ROOT/rows[uid]['pose_sheet'].removeprefix('res://'))==prepared[uid]['atlas_sha256'],'source changed before retained normal import closure'
            expected_import_reference(output/'normal',selected,args.godot);compare_import(output/'normal',selected)
        for facing in (['reflected'] if args.mode=='resumelease' else ['normal','reflected']):
            cmd=[sys.executable,'-B',__file__,'render','--output',str(output/facing),'--start',str(args.start),'--count',str(args.count),'--godot',args.godot]+(['--mirrored'] if facing=='reflected' else [])
            code=subprocess.call(cmd,env=dict(os.environ,CREATURE_REVIEW_GPU_LEASE=str(os.getpid())))
            if code:return code
    pages(output,selected);print('BOUNDED_BATCH_TERMINAL',selected,flush=True);return 0

if __name__=='__main__':raise SystemExit(main())
