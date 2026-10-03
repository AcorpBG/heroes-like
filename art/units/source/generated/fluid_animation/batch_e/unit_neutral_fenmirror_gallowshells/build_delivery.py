"""Pack personally selected original video pixels; never auto-accept art."""
import json
from PIL import Image
import produce as p

REQUIRED={'move','attack','hit','defend','cast','death'}

def read(path):return json.loads(path.read_bytes())

def build(take):
    folder=p.SOURCE_DIR/take;c=read(folder/'config.json');s=read(folder/'selection.json')
    name=c['action'];assert name in REQUIRED
    indices=s['source_frames'];assert len(indices)==len(set(indices)) and indices==sorted(indices)
    assert all(isinstance(i,int) and 0<=i<124 for i in indices)
    assert len(indices)>=(4 if name in {'hit','defend'} else 8)
    assert s['frame_msec']>=30
    manifest=read(folder/'matte.json')
    frames=[]
    for index in indices:
        file=folder/'matte'/f'rgba_{index:03}.png'
        assert p.sha(file)==manifest['rgba_sha256'][index]
        im=Image.open(file);assert im.mode=='RGBA' and list(im.size)==c['canvas']
        bound=im.getchannel('A').point(lambda a:255 if a>=8 else 0).getbbox()
        assert bound and bound[0]>0 and bound[1]>0 and bound[2]<im.width and bound[3]<im.height,('Clipped original subject',index,bound)
        frames.append(dict(name=f'{name}_original_h3_{index:03}',clip=name,source=file.relative_to(p.ROOT).as_posix(),rects=[[0,0,*c['canvas']]],anchor=c['anchor'],scale=c['scale'],alpha_noise_cutoff=0,video_frame=index,video_time_seconds=index/24))
    clip=dict(indices=list(range(len(frames))),frame_msec=s['frame_msec'],loop=name=='move',static_frame=len(frames)-1 if name in {'death','defend'} else 0)
    for key in ['contact_frame','frame_durations_msec']:
        if key in s:clip[key]=s[key]
    if 'contact_frame' in clip:assert 0<clip['contact_frame']<len(frames)-1
    if 'frame_durations_msec' in clip:assert len(clip['frame_durations_msec'])==len(frames) and min(clip['frame_durations_msec'])>=30
    provenance={}
    for name in ['config.json','selection.json','visual_review.json','guide_review.json','original_lossless.mkv','original.mp4','original.json','original.latent','reference.json','prompt.txt','matte.json','segmentation_recipe.json','workflow_api.json','sampling_workflow_api.json','sampling_submission.json','sampling_history.json','decode_submission.json','generation_history.json','staged_generation.json']:
        file=folder/name
        if file.exists():provenance[name]=dict(path=file.relative_to(p.ROOT).as_posix(),sha256=p.sha(file))
    unit=dict(unit_id=c['unit_id'],reference_height=256,source_facing='right',frames=frames,clips={c['action']:clip},source_scale_reason='One fixed original anatomical scale and anchor for all frames in each124-frame source; no frame stabilization, resizing to pose bounds, interpolation or repaint.',provenance=provenance,visual_review=dict(status='pending',notes=s['review_note']))
    p.write(folder/'handoff.json',dict(schema_version=1,units=[unit]))
    return unit

def assemble():
    delivery=read(p.SOURCE_DIR/'delivery.json');unit=None
    for take in delivery['takes']:unit=p.combine(unit,build(take))
    assert set(unit['clips'])==REQUIRED
    unit['preserved_accepted_clips']=['idle']
    unit['visual_review']=delivery.get('visual_review',dict(status='pending',notes='Six selected original H3 clips; native review pending. Preserve original eight-pose270ms idle; melee-only ranged fallback remains attack.'))
    provenance={}
    for take in delivery['takes']:
        part=read(p.SOURCE_DIR/take/'handoff.json')['units'][0]
        provenance.update({take+'_'+k:v for k,v in part['provenance'].items()})
    for name in ['prepare.py','prepare_corrected_pair.py','prepare_terminal_actions.py','prepare_attack_reference.py','qualify_corrected_key.py','qualify_attack_hit.py','inspect_sources.py','produce.py','stage_video.py','run_actions.py','segment.py','matting_model.json','runtime_profile.json','brief.json','delivery.json','original_unit_baseline.json','original_reference_poses.json','support_registration.json','support_guide_v1/original.png','support_guide_v1/original.generation.json','support_guide_v1.prompt.txt','references/ready_original.png','references/ready_original.crop.json','attack_closed_registration.json','attack_closed_guide_v1/original.png','attack_closed_guide_v1/original.generation.json','attack_closed_guide_v1.prompt.txt','attack_closed_guide_v2/original.png','attack_closed_guide_v2/original.generation.json','attack_closed_guide_v2.prompt.txt','references/extended_open_pincer_original.png','references/extended_open_pincer_original.crop.json']:
        file=p.SOURCE_DIR/name;assert file.is_file(),name
        provenance[name]=dict(path=file.relative_to(p.ROOT).as_posix(),sha256=p.sha(file))
    for name in ['prepare_death_guides.py','qualify_guard_support.py','qualify_death.py']:
        file=p.SOURCE_DIR/name
        provenance[name]=dict(path=file.relative_to(p.ROOT).as_posix(),sha256=p.sha(file))
    for ref in read(p.SOURCE_DIR/'original_reference_poses.json')['frames']:
        provenance['original_'+ref['source']]=dict(path=ref['source'],sha256=p.sha(p.ROOT/ref['source']))
    file=p.ROOT/'art/units/source/curated'/f'{p.SOURCE_DIR.name}.png'
    provenance['original_curated_identity']=dict(path=file.relative_to(p.ROOT).as_posix(),sha256=p.sha(file))
    unit['provenance']=provenance
    p.write(p.SOURCE_DIR/'handoff.json',dict(schema_version=1,units=[unit]))

if __name__=='__main__':assemble()
