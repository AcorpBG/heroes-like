"""Bounded current-live town-upgrade review; actual rendered poses, no publication.

Each invocation reviews one unit/action/facing offscreen through the existing
focused fixture. The --lease option runs at most two invocations under the
shared continuous GPU mutex. Outputs are disposable review material.
"""
from pathlib import Path
import argparse, hashlib, json, subprocess, sys
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tests'))
sys.path.insert(0,str(ROOT/'tools'))

def declared_import_pixels(source):
    """Reproduce the existing lossless import recipe without changing files.

    Godot 4.6.2 Image::fix_alpha_edges uses original neighbors, radius4,
    alpha threshold20, and the first strictly nearest qualifying RGB.
    https://github.com/godotengine/godot/blob/4.6.2-stable/core/io/image.cpp
    This is an expected-image calculation, never an art/cache rewrite.
    """
    from PIL import Image
    import numpy as np,re
    original=np.array(Image.open(source).convert('RGBA'))
    recipe=Path(str(source)+'.import').read_text(encoding='utf-8-sig')
    for key,value in {'compress/mode':'0','mipmaps/generate':'false','process/premult_alpha':'false','process/normal_map_invert_y':'false','process/hdr_as_srgb':'false','process/hdr_clamp_exposure':'false','process/size_limit':'0'}.items():
        setting=re.search(r'(?m)^'+re.escape(key)+r'=(.*)$',recipe)
        assert setting is not None and setting.group(1)==value,'Unsupported existing import recipe: '+key
    match=re.search(r'(?m)^process/fix_alpha_border=(true|false)\s*$',recipe)
    assert match is not None,'Unknown existing alpha-border import recipe'
    if match.group(1)=='false':return original
    expected=original.copy();height,width=original.shape[:2]
    closest=np.full((height,width),0x7fffffff,dtype=np.int32)
    low=original[:,:,3]<20
    for dy in range(-4,5):
        for dx in range(-4,5):
            distance=dy*dy+dx*dx
            y0=max(0,-dy);y1=min(height,height-dy)
            x0=max(0,-dx);x1=min(width,width-dx)
            neighbor=original[y0+dy:y1+dy,x0+dx:x1+dx]
            best=closest[y0:y1,x0:x1]
            mask=low[y0:y1,x0:x1]&(neighbor[:,:,3]>=20)&(distance<best)
            rgb=expected[y0:y1,x0:x1,:3]
            rgb[mask]=neighbor[:,:,:3][mask]
            best[mask]=distance
    return expected

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--godot',required=True)
    p.add_argument('--unit',required=True)
    p.add_argument('--additional-unit',nargs='*',default=[],help='At most one further upgrade in the same short review run')
    p.add_argument('--output',type=Path,required=True)
    p.add_argument('--action',choices=['strike','shoot'],default='strike')
    p.add_argument('--mirrored',action='store_true')
    p.add_argument('--lease',action='store_true')
    a=p.parse_args()
    requested=[a.unit,*a.additional_unit]
    assert len(requested)<=2 and len(requested)==len(set(requested)), 'Bounded review accepts at most two distinct units'
    rows={r['unit_id']:r for r in json.loads((ROOT/'content/unit_animation_manifest.json').read_bytes())['items']}
    units={r['id']:r for r in json.loads((ROOT/'content/units.json').read_bytes())['items']}
    town=json.loads((ROOT/'content/town_development.json').read_bytes())
    upgraded={r['upgraded_unit_id'] for entries in town['rosters'].values() for r in entries}
    assert set(requested)<=upgraded
    row=rows[a.unit]
    for uid in requested:
        assert rows[uid]['pose_review_status']=='accepted_selected_fluid_clips'
        if a.action=='shoot':assert units[uid]['ranged'] is True
    atlas=ROOT/row['pose_sheet'].removeprefix('res://')
    digest=hashlib.sha256(atlas.read_bytes()).hexdigest()
    source_digests={uid:hashlib.sha256((ROOT/rows[uid]['pose_sheet'].removeprefix('res://')).read_bytes()).hexdigest() for uid in requested}
    if a.lease:
        from creature_animation_lock import exclusive
        command=[sys.executable,'-B',__file__,'--godot',a.godot,'--unit',a.unit,'--action',a.action]
        if a.additional_unit:command+=['--additional-unit',*a.additional_unit]
        # One lease, maximum two focused review runs, terminally awaited.
        with exclusive('gpu'):
            for mirrored in [False,True]:
                out=a.output/('reflected' if mirrored else 'normal')
                code=subprocess.call(command+['--output',str(out)]+(['--mirrored'] if mirrored else []))
                if code:return code
        assert hashlib.sha256(atlas.read_bytes()).hexdigest()==digest
        print(json.dumps({'unit_id':a.unit,'atlas_sha256':digest,'action':a.action,'terminal':0}),flush=True)
        return 0
    import fluid_creature_animation_regression as f
    def replace(old,new,count=1):
        assert f.SCRIPT.count(old)==count,(old,f.SCRIPT.count(old))
        f.SCRIPT=f.SCRIPT.replace(old,new)
    replace('func cell_width()->int:return maxi(155,','func cell_width()->int:return maxi(260,')
    # Keep exact loaded runtime texture pixels for CPU verification against
    # the current source hash; hidden zero-alpha RGB is deliberately ignored.
    needle='\t\t\t\tvar imported:Texture2D=load(row.pose_sheet)'
    replace(needle,needle+'\n\t\t\t\timported.get_image().save_png(OS.get_environment("FLUID_OUTPUT").path_join(change.unit_id+"-imported-atlas.png"))')
    needle='\t\t\t\t\tvar material=Idle.material(pose,change.unit_id,true)'
    replace(needle,'\t\t\t\t\tpose.texture.get_image().save_png(OS.get_environment("FLUID_OUTPUT").path_join(change.unit_id+"-imported-map.png"))\n'+needle)
    replace('\t\t\t\t\tvar still:Image=await capture()','\t\t\t\t\tvar still:Image=await capture()\n\t\t\t\t\tstill.save_png(OS.get_environment("FLUID_OUTPUT").path_join(change.unit_id+"-map-idle-reduced.png"))')
    # Render every map shader phase, preserving the real material and geometry.
    needle='\t\t\t\t\tbatch.set_motion_enabled(false)'
    replace(needle,'''\t\t\t\t\tfor phase_index in range(int(row.pose_clips.idle.frames)):
\t\t\t\t\t\tmaterial.set_shader_parameter("clock_override",float(material.get_shader_parameter("frame_seconds"))*(float(phase_index)+.01))
\t\t\t\t\t\tvar map_phase:Image=await capture()
\t\t\t\t\t\tmap_phase.save_png(OS.get_environment("FLUID_OUTPUT").path_join(change.unit_id+"-map-phase-"+str(phase_index)+".png"))
'''+needle)
    if a.mirrored:
        replace('var rect:Rect2=Pose.grounded_rect(ground,128,region,row)','var rect:Rect2=Pose.grounded_rect(ground,128,region,row,true)')
        replace('\t\t\t\tdraw_texture_rect_region(sheet,rect,region)','\t\t\t\tdraw_set_transform(Vector2(rect.end.x,0),0,Vector2(-1,1))\n\t\t\t\tdraw_texture_rect_region(sheet,Rect2(Vector2(0,rect.position.y),rect.size),region)\n\t\t\t\tdraw_set_transform(Vector2.ZERO,0,Vector2.ONE)',2)
    clip='ranged' if a.action=='shoot' else 'attack'
    if a.action=='shoot':
        replace('stacks[index].ranged = false','stacks[index].ranged = index==0\n\t\tstacks[index].shots_remaining = 7')
        replace('var action:Dictionary=shell._perform_action("strike")','var action:Dictionary=shell._perform_action("shoot")')
        replace('record.get("event_id","")=="battle_unit_melee_attack"','record.get("event_id","")=="battle_unit_ranged_attack"')
        replace('var pose_index:int=Pose.timed_frame(ContentService.get_unit_animation(attack_id).pose_clips.attack,','var pose_index:int=Pose.timed_frame(ContentService.get_unit_animation(attack_id).pose_clips.ranged,')
        replace('int(ContentService.get_unit_animation(attack_id).pose_clips.attack.frames)','int(ContentService.get_unit_animation(attack_id).pose_clips.ranged.frames)')
    n=max(int(rows[uid]['pose_clips'][clip]['frames']) for uid in requested)
    replace('capture_count<3 and pose_index in [0,2,4]',f'capture_count<{n} and pose_index>=0')
    # Warm actual viewport/readback before committing the action; no pose clock,
    # animation timing, simulation, accepted art or settings are altered.
    needle='\t\tvar action:Dictionary=shell._perform_action('
    assert f.SCRIPT.count(needle)==1
    f.SCRIPT=f.SCRIPT.replace(needle,'\t\tvar warmed:Image=await capture()\n'+needle)
    observe_after_draw(f)
    if a.mirrored:
        # Use normal enemy initiative and AI action playback for the opposing
        # facing. Do not override the runtime renderer's facing transform.
        replace('rendered.battle.stacks[0].unit_id=attack_id','rendered.battle.stacks[1].unit_id=attack_id')
        replace('rendered.battle.stacks[0].name=ContentService.get_unit(attack_id).name','rendered.battle.stacks[1].name=ContentService.get_unit(attack_id).name')
        replace('rendered.battle.stacks[0].battle_id','rendered.battle.stacks[1].battle_id',3)
        # Set enemy initiative after shell startup/warm-up: startup itself runs
        # ready, which would otherwise consume this action before observation.
        needle='\t\tvar action:Dictionary=shell._perform_action('
        # Keep the canonical commander intact. The fixture starts after that
        # round's commander spell, so normal AI reviews a creature action.
        replace(needle,'\t\trendered.battle.active_stack_id=rendered.battle.stacks[1].battle_id\n\t\trendered.battle.turn_index=1\n\t\trendered.battle.commander_spell_cast_rounds={"enemy":int(rendered.battle.get("round",1))}\n'+needle)
        replace('var action:Dictionary=shell._perform_action("'+a.action+'")','var action:Dictionary=shell._perform_action("ready")')
        if a.action=='shoot':replace('stacks[index].ranged = index==0','stacks[index].ranged = index==1')
        else:
            # A ranged creature at distance would legitimately choose Shoot.
            # The melee review starts adjacent, so normal AI takes Strike.
            needle='\t\trendered.battle.active_stack_id=rendered.battle.stacks[1].battle_id'
            replace(needle,'\t\trendered.battle.stacks[1].hex={"q":3,"r":3}\n\t\tBattleRules._sync_occupied_hexes(rendered.battle)\n\t\tBattleRules._sync_distance_from_hexes(rendered.battle)\n'+needle)
    needle='\t\tcheck(not shell._action_playback_in_progress,"shell animation queue did not finish")'
    replace(needle,'\t\tprint("COMPLETION_DRAWN_POSES "+JSON.stringify({"unit_id":attack_id,"clip":"'+clip+'","seen":seen_attack_frames,"captured":captured_poses}))\n'+needle)
    # Inspect actual shell Normal/Fast playback and the real reduced-motion
    # held pose in this same focused run, using isolated fixture preferences.
    start=f.SCRIPT.index('\tif DisplayServer.get_name()!="headless" and not attack_id.is_empty() and OS.get_environment("FLUID_CONTACTS_ONLY")!="1":')
    end=f.SCRIPT.index('\tprint("FLUID_ANIMATION_REPORT ',start)
    block=f.SCRIPT[start:end]
    block=block.replace('SettingsService.set_reduced_motion_enabled(false)','SettingsService.set_reduced_motion_enabled(review_mode=="reduced")')
    block=block.replace('SettingsService.set_battle_playback_speed_id("normal")','SettingsService.set_battle_playback_speed_id("fast" if review_mode=="fast" else "normal")')
    block=block.replace('"battle-phase-"+str(i)','"battle-"+review_mode+"-phase-"+str(i)')
    block=block.replace('"captured":captured_poses','"captured":captured_poses,"mode":review_mode')
    mismatch='\t\tcheck(rendered.to_dict()==committed,"shell presentation changed committed saved simulation")'
    assert block.count(mismatch)==1
    block=block.replace(mismatch,'''\t\tif rendered.to_dict()!=committed:
\t\t\tvar diff_file=FileAccess.open(OS.get_environment("FLUID_OUTPUT").path_join("state-"+review_mode+".json"),FileAccess.WRITE)
\t\t\tdiff_file.store_string(JSON.stringify({"before":committed,"after":rendered.to_dict()}))
\t\t\tvar canonical=Store.new_session_data()
\t\t\tcanonical.from_dict(committed.duplicate(true))
\t\t\tBattleRules.normalize_battle_state(canonical)
\t\t\tprint("COMPLETION_NORMALIZED_REFERENCE "+JSON.stringify({"unit_id":attack_id,"mode":review_mode,"equal":canonical.to_dict()==rendered.to_dict()}))
'''+mismatch)
    assertion='\t\tcheck(seen_attack_frames.size()==int(ContentService.get_unit_animation(attack_id).pose_clips.'+clip+'.frames),"shell did not show every authored attack pose including recovery; observed="+str(seen_attack_frames))'
    assert block.count(assertion)==1
    block=block.replace(assertion,'\t\tif review_mode=="reduced":\n\t\t\tcheck(seen_attack_frames==[int(ContentService.get_unit_animation(attack_id).pose_clips.'+clip+'.get("static_frame",0))],"reduced actual action did not hold authored static pose; observed="+str(seen_attack_frames))\n\t\telse:\n\t'+assertion)
    lines=block.splitlines()
    block=lines[0]+'\n\t\tfor review_mode in ["normal","fast","reduced"]:\n'+'\n'.join('\t'+line for line in lines[1:])+'\n'
    f.SCRIPT=f.SCRIPT[:start]+block+f.SCRIPT[end:]
    if a.additional_unit:
        # Native/map loops already cover every selected row. Run real shell
        # actions for each row too, so batching never substitutes last-unit
        # action proof for another creature's actual runtime presentation.
        start=f.SCRIPT.index('\tif DisplayServer.get_name()!="headless" and not attack_id.is_empty() and OS.get_environment("FLUID_CONTACTS_ONLY")!="1":')
        end=f.SCRIPT.index('\tprint("FLUID_ANIMATION_REPORT ',start)
        lines=f.SCRIPT[start:end].splitlines()
        f.SCRIPT=f.SCRIPT[:start]+lines[0]+'\n\t\tfor review_change in patch.units:\n\t\t\tattack_id=String(review_change.unit_id)\n'+'\n'.join('\t'+line for line in lines[1:])+'\n'+f.SCRIPT[end:]
        # Unit prefixes make multi-unit captures and failure deltas unambiguous;
        # single-unit filenames stay compatible with existing review helpers.
        f.SCRIPT=f.SCRIPT.replace('"battle-"+review_mode+"-phase-"','"battle-"+attack_id+"-"+review_mode+"-phase-"')
        f.SCRIPT=f.SCRIPT.replace('"state-"+review_mode+".json"','"state-"+attack_id+"-"+review_mode+".json"')
    for uid in requested:print(json.dumps({'unit_id':uid,'atlas_sha256':source_digests[uid],'mirrored_native':a.mirrored,'action':a.action}),flush=True)
    sys.argv=[__file__,'--godot',a.godot,'--live','--unit',*requested,'--render','--overview-only','--output',str(a.output)]
    code=f.main()
    from PIL import Image
    import numpy as np
    map_rows=json.loads((ROOT/'art/overworld/creature_idle.json').read_bytes())['units']
    for uid in requested:
        for label,source in [('atlas',ROOT/rows[uid]['pose_sheet'].removeprefix('res://')),('map',ROOT/map_rows[uid]['path'].removeprefix('res://'))]:
            cached=a.output/(uid+'-imported-'+label+'.png')
            if not cached.exists():continue
            expected=declared_import_pixels(source)
            actual=np.array(Image.open(cached).convert('RGBA'))
            assert expected.shape==actual.shape
            assert np.array_equal(expected[:,:,3],actual[:,:,3]),'Runtime imported alpha mismatch: '+uid+'/'+label
            assert np.array_equal(expected[expected[:,:,3]>0],actual[expected[:,:,3]>0]),'Runtime imported visible pixel mismatch: '+uid+'/'+label
            print(json.dumps({'unit_id':uid,'imported_visible_pixels_exact':label,'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest()}),flush=True)
        assert hashlib.sha256((ROOT/rows[uid]['pose_sheet'].removeprefix('res://')).read_bytes()).hexdigest()==source_digests[uid]
    assert hashlib.sha256(atlas.read_bytes()).hexdigest()==digest
    return code


def observe_after_draw(fixture):
    # The shared probe observes process_frame, then yields frame_post_draw
    # again for selected screenshots. That can miss short authored poses in
    # its observation list. Sample each rendered frame once and read back
    # that same completed viewport. All pose/timing assertions stay intact.
    before='while shell._action_playback_in_progress and Time.get_ticks_msec()<deadline:\n\t\t\tawait get_tree().process_frame'
    assert fixture.SCRIPT.count(before)==1
    fixture.SCRIPT=fixture.SCRIPT.replace(before,before.replace('await get_tree().process_frame','await RenderingServer.frame_post_draw'))
    before='\t\t\t\t\t\tawait RenderingServer.frame_post_draw\n\t\t\t\t\t\tphase_captures.append'
    assert fixture.SCRIPT.count(before)==1
    fixture.SCRIPT=fixture.SCRIPT.replace(before,'\t\t\t\t\t\tphase_captures.append')
    # GPU readback can cross a pose boundary after the real draw. Observe the
    # exact atlas region selected by the unchanged renderer, not a later clock
    # calculation. The preview subclass only records; it never freezes or
    # substitutes playback, source pixels, timing, or simulation state.
    observer='''class ObservedBoard extends Board:
\tvar drawn_pose_regions:Dictionary={}
\tvar observing_draw:bool=false
\tfunc _draw():
\t\tdrawn_pose_regions.clear();observing_draw=true
\t\tsuper._draw()
\t\tobserving_draw=false
\tfunc _animation_frame_region_for_stack(stack:Dictionary)->Rect2:
\t\tvar region:Rect2=super._animation_frame_region_for_stack(stack)
\t\tif observing_draw:drawn_pose_regions[String(stack.battle_id)]=region
\t\treturn region
'''
    needle='class ContactSheet extends Control:';assert fixture.SCRIPT.count(needle)==1
    fixture.SCRIPT=fixture.SCRIPT.replace(needle,observer+'\n'+needle)
    needle='\t\tadd_child(shell)';assert fixture.SCRIPT.count(needle)==1
    fixture.SCRIPT=fixture.SCRIPT.replace(needle,'\t\tshell.get_node("%BattleBoard").set_script(ObservedBoard)\n'+needle)
    lines=fixture.SCRIPT.splitlines();candidates=[line for line in lines if 'var pose_index:int=Pose.timed_frame(' in line];assert len(candidates)==1
    old=candidates[0];name='ranged' if '.pose_clips.ranged' in old else 'attack'
    replacement='''\t\t\t\t\tvar pose_index:int=-1
\t\t\t\t\tvar drawn:Rect2=shell._battle_board_view.drawn_pose_regions.get(rendered.battle.stacks[0].battle_id,Rect2())
\t\t\t\t\tvar animation:Dictionary=ContentService.get_unit_animation(attack_id)
\t\t\t\t\tvar indices:Array=animation.pose_clips.CLIP.indices
\t\t\t\t\tfor i in range(indices.size()):
\t\t\t\t\t\tvar frame_index:int=int(indices[i])\n\t\t\t\t\t\tvar r:Array=[]\n\t\t\t\t\t\tif animation.has("pose_frame_rects"):r=animation.pose_frame_rects[frame_index]\n\t\t\t\t\t\telse:\n\t\t\t\t\t\t\tvar columns:int=int(animation.pose_columns)\n\t\t\t\t\t\t\tvar size:Dictionary=animation.pose_frame_size\n\t\t\t\t\t\t\tr=[(frame_index%columns)*int(size.width),(frame_index/columns)*int(size.height),int(size.width),int(size.height)]
\t\t\t\t\t\tif drawn==Rect2(float(r[0]),float(r[1]),float(r[2]),float(r[3])):pose_index=i;break
'''.rstrip().replace('CLIP',name)
    fixture.SCRIPT=fixture.SCRIPT.replace(old,replacement)
    needle='if pose_index not in seen_attack_frames:seen_attack_frames.append(pose_index)';assert fixture.SCRIPT.count(needle)==1
    fixture.SCRIPT=fixture.SCRIPT.replace(needle,'if pose_index>=0 and pose_index not in seen_attack_frames:seen_attack_frames.append(pose_index)')



if __name__=='__main__':raise SystemExit(main())
