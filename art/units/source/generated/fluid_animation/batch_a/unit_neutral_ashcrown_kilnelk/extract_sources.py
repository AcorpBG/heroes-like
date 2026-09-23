"""Separate original RGBA sheet components without repainting any artwork."""
from pathlib import Path
import numpy as np
from PIL import Image

HERE=Path(__file__).resolve().parent

def components(path,count=8,columns=4):
    a=np.array(Image.open(path).convert('RGBA'))
    parents=[]; runs=[]; previous=[]
    def find(x):
        while parents[x]!=x:
            parents[x]=parents[parents[x]]; x=parents[x]
        return x
    for y,row in enumerate(a[:,:,3]>8):
        padded=np.pad(row,(1,1)).astype(np.int8)
        edges=np.flatnonzero(np.diff(padded))
        current=[]
        for x0,x1 in zip(edges[::2],edges[1::2]):
            i=len(parents); parents.append(i)
            for p0,p1,pid in previous:
                if p1<x0: continue
                if p0>x1: break
                parents[find(i)]=find(pid)
            runs.append((y,int(x0),int(x1),i));current.append((x0,x1,i))
        previous=current
    groups={}
    for y,x0,x1,i in runs: groups.setdefault(find(i),[]).append((y,x0,x1))
    data=[]
    for rs in groups.values():
        area=sum(x1-x0 for _,x0,x1 in rs)
        box=[min(x0 for _,x0,_ in rs),rs[0][0],max(x1 for _,_,x1 in rs),rs[-1][0]+1]
        data.append(dict(area=area,box=box,runs=rs))
    big=sorted(data,key=lambda r:r['area'],reverse=True)[:count]
    # The largest eight connected figures define the original sheet order.
    big.sort(key=lambda d:d['box'][1])
    ordered=[]
    for n in range(0,count,columns): ordered.extend(sorted(big[n:n+columns],key=lambda d:d['box'][0]))
    for item in data:
        if item in big: continue
        box=item['box'];x=(box[0]+box[2])/2;y=(box[1]+box[3])/2
        def distance(core):
            l,t,r,b=core['box']
            return max(l-x,0,x-r)**2+max(t-y,0,y-b)**2
        nearest=min(ordered,key=distance)
        if distance(nearest)<1600: nearest['runs'].extend(item['runs'])
    result=[]
    for i,d in enumerate(ordered):
        rs=d['runs']; l=min(x0 for _,x0,_ in rs);r=max(x1 for _,_,x1 in rs);t=min(y for y,_,_ in rs);b=max(y for y,_,_ in rs)+1
        cut=np.zeros((b-t,r-l,4),dtype=np.uint8)
        for y,x0,x1 in rs: cut[y-t,x0-l:x1-l]=a[y,x0:x1]
        dest=HERE/'extracted'/f'{path.stem}_{i}.png';dest.parent.mkdir(exist_ok=True)
        Image.fromarray(cut).save(dest)
        result.append(dict(file=dest.name,box=[l,t,r,b],area=d['area']))
    return result

if __name__=='__main__':
    import json
    out={stem:components(HERE/(stem+'.png')) for stem in ['move_v1','attack_v1','reactions_v1','death_v1']}
    # Two portrait-row figures touch through a faint ember at the gutter.
    # Their authored cell boundaries separate the drawings without repainting.
    cast=Image.open(HERE/'cast_v3.png').convert('RGBA');out['cast_v3']=[]
    for i,box in enumerate([[95,0,480,383],[600,0,970,384],[110,383,480,768],[600,383,975,768],[140,770,480,1151],[620,770,970,1151],[120,1151,480,1536],[585,1151,970,1536]]):
        cut=cast.crop(box);cut.putalpha(cut.getchannel('A').point(lambda a:0 if a<=8 else a))
        name=f'cast_v3_{i}.png';cut.save(HERE/'extracted'/name)
        out['cast_v3'].append(dict(file=name,box=box,area=sum(a>8 for a in cut.getchannel('A').getdata())))
    out['move_return_v1']=components(HERE/'move_return_v1.png',4,2)
    (HERE/'extraction.json').write_text(json.dumps(out,indent=2)+'\n',encoding='utf-8')
    print({k:[v['box'] for v in vs] for k,vs in out.items()})
