"""Assemble reviewed original H3 intervals into one continuous death action.

No synthesized, reversed or normalized frames. Selection records exact take,
frame index and authored playback duration; immutable videos remain the source.
"""
import json
from pathlib import Path
import produce

S=Path(__file__).resolve().parent
R=produce.ROOT

def build():
    out=S/'death_complete'
    selection=json.loads((out/'selection.json').read_bytes())
    frames=[];durations=[];provenance={};seen=set()
    for segment in selection['segments']:
        take=S/segment['take']
        config=json.loads((take/'config.json').read_bytes())
        matte=json.loads((take/'matte.json').read_bytes())
        for name in ['original_lossless.mkv','original.json','workflow_api.json','prompt.txt','reference.json','matte.json']:
            p=take/name
            provenance[take.name+'/'+name]={'path':p.relative_to(R).as_posix(),'sha256':produce.sha(p)}
        for index in segment['source_frames']:
            identity=(take.name,index)
            assert identity not in seen
            seen.add(identity)
            p=take/'matte'/f'rgba_{index:03}.png'
            assert produce.sha(p)==matte['rgba_sha256'][index]
            frames.append(dict(name=f'death_{take.name}_{index:03}',clip='death',source=p.relative_to(R).as_posix(),rects=[[0,0,960,544]],anchor=config['anchor'],scale=config['scale'],alpha_noise_cutoff=0,video_frame=index,video_time_seconds=index/24))
            durations.append(segment['frame_msec'])
    assert len(frames)>=8
    entry=dict(unit_id='unit_embercourt_ash_oath_bailiffs',reference_height=256,source_facing='right',frames=frames,clips={'death':dict(indices=list(range(len(frames))),frame_msec=durations[0],frame_durations_msec=durations,loop=False,static_frame=len(frames)-1)},alpha_noise_cutoff=0,provenance=provenance,visual_review={'status':'pending','notes':selection['review_note']})
    produce.write(out/'handoff.json',{'schema_version':1,'units':[entry]})
    return entry

if __name__=='__main__':
    build()
    produce.assemble()
