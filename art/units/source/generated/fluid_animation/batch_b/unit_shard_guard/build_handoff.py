"""Original source-frame extraction recipe. Does not modify live catalogs."""
import hashlib,json
from pathlib import Path
from PIL import Image
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[6]
REL=HERE.relative_to(ROOT).as_posix()
UID='unit_shard_guard'
OUTPUT='C:/Users/acorp/.codex/generated_images/01a0cccf-7af7-75c2-ae2f-73ff433f51e8/'
ids={'move_v1':'exec-c77f5bf9-681c-42c3-a613-b62a9580d00c.png','attack_v1':'exec-3fcc9695-69d5-4094-9eb6-7655ed86a819.png','cast_v1':'exec-ee79f26c-a021-449e-b0e2-155e107fbb50.png','reactions_v1':'exec-6da36ac4-aba6-40e8-ab66-5bbd04a1fe4b.png','death_v1':'exec-ede9f6be-662a-4e4c-82e9-edb257b0970a.png'}
frames=[];clips={};scales={}
def add(master,clip,ys,ground,xs,scale=.61,first=0,count=8):
    im=Image.open(HERE/(master+'.png')).convert('RGBA')
    source=REL+'/'+master+'.png';scales[source]=scale;start=len(frames)
    for i in range(first,first+count):
        r,c=divmod(i,2)
        split=560 if master=='attack_v1' and r==2 else 512
        box=(0 if c==0 else split,ys[r],split if c==0 else 1024,ys[r+1])
        b=im.crop(box).getchannel('A').point(lambda a:255 if a>8 else 0).getbbox()
        if not b: raise ValueError((master,i))
        rect=[box[0]+b[0],box[1]+b[1],box[0]+b[2],box[1]+b[3]]
        frames.append(dict(name=f'{clip}_{i-first:02}',clip=clip,source=source,rects=[rect],anchor=[xs[i],ground[i]],scale=scale))
    clips[clip]=dict(indices=list(range(start,len(frames))),frame_msec=100,loop=clip=='move',static_frame=0)
add('move_v1','move',[0,386,761,1130,1536],[378,378,746,746,1127,1127,1497,1497],[279,740,279,740,279,740,279,740])
add('attack_v1','attack',[0,386,764,1125,1536],[382,382,762,762,1117,1120,1505,1505],[280,755,267,758,261,745,270,753])
clips['attack'].update(contact_frame=4,frame_msec=95)
add('cast_v1','cast',[0,367,758,1144,1536],[364,364,756,756,1136,1136,1510,1510],[258,753,258,753,258,753,258,753],.63)
add('reactions_v1','hit',[0,380,763,1118,1536],[377,377,760,756,1117,1100,1478,1478],[348,729,350,730,350,730,350,730],.61,count=4)
add('reactions_v1','defend',[0,380,763,1118,1536],[377,377,760,756,1117,1100,1478,1478],[348,729,350,730,345,730,345,730],.61,first=4,count=4)
clips['defend']['static_frame']=3
add('death_v1','death',[0,482,879,1232,1536],[444,444,830,830,1152,1158,1471,1471],[260,785,256,768,267,768,265,768],.54)
clips['death'].update(frame_msec=135,static_frame=7)
clips['dead']=dict(indices=[len(frames)-1],frame_msec=100,loop=False,static_frame=0)
entry=dict(unit_id=UID,reference_height=256,source_facing='right',alpha_noise_cutoff=8,frames=frames,clips=clips,preserve_clips=['idle'],accepted_clips=[],source_scale_by_image=scales,source_scale_reason='Fixed anatomical scale per original: regular sheets ~365px body versus old ~223px idle; salute drawn slightly smaller, death armor drawn larger. No per-pose resizing.',visual_review=dict(status='pending',notes=['Existing eight idle poses visibly articulate spear elbow and shield hand through a coherent return; proposed retention requires coordinator acceptance.','New move, single spear strike, physical weapon salute, hit/brace and death paintings reviewed for identity and articulation; final engine motion/grounding pending.']))
(HERE/'handoff.json').write_text(json.dumps(dict(schema_version=1,units=[entry]),indent=2)+'\n',encoding='utf-8')
sources=[]
reference=f'art/units/source/curated/{UID}.png'
for name,id in ids.items():
    p=HERE/(name+'.prompt.txt');p.write_bytes(p.read_bytes().rstrip(b'\r\n'))
    sources.append(dict(master=f'{REL}/{name}.png',sha256=hashlib.sha256((HERE/(name+'.png')).read_bytes()).hexdigest(),prompt=f'{REL}/{name}.prompt.txt',prompt_sha256=hashlib.sha256(p.read_bytes()).hexdigest(),reference=reference,reference_sha256=hashlib.sha256((ROOT/reference).read_bytes()).hexdigest(),generation_output=OUTPUT+id,tool='built-in image_gen',status='pending coordinator visual acceptance'))
(HERE/'provenance.json').write_text(json.dumps(dict(schema_version=1,unit_id=UID,sources=sources),indent=2)+'\n',encoding='utf-8')
print(len(frames),'original frames ready for review')
