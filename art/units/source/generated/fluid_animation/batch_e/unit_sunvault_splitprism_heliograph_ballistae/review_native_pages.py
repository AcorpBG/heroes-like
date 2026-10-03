"""Create disposable exact-pixel native review crops; never transform art."""
from pathlib import Path
from PIL import Image
import produce as p

UID=p.SOURCE_DIR.name
OUT=p.ROOT/'.artifacts/parallel_animation_20261003'/UID

def main():
    names = [stage+'_'+facing
             for stage in ['candidate_pair','candidate_ranged','live_pair','live_ranged']
             for facing in (['native','mirrored'] if stage.endswith('_pair') else ['ranged','ranged_reflected'])]
    for name in names:
        folder=OUT/name
        path=folder/f'{UID}-overview.png'
        if not path.exists():
            continue
        source=Image.open(path).convert('RGBA')
        pages=folder/'review_pages';pages.mkdir(exist_ok=True)
        for y in range(0,source.height,960):
            for x in range(0,source.width,1040):
                source.crop((x,y,min(x+1040,source.width),min(y+960,source.height))).save(pages/f'{y//960}_{x//1040}.png')
        # Keep the complete actual viewport. A fixed actor crop misses the
        # enemy's real position and can hide rods, operator or reaction targets.
        captures=[]
        for mode in ['normal','fast','reduced']:
            files=sorted(folder.glob('battle-'+mode+'-phase-*.png'))
            assert len(files)==(1 if mode=='reduced' else 8),(name,mode,len(files))
            for file in files:
                with Image.open(file) as raw:
                    assert raw.size==(1280,720),(file,raw.size)
            captures.extend(files)
        maps=sorted(folder.glob(f'{UID}-map-preserved-phase-*.png'))
        if maps:
            assert len(maps)==8
            map_sheet=Image.new('RGBA',(720,320),(27,27,30,255))
            for i,file in enumerate(maps):
                raw=Image.open(file).convert('RGBA')
                map_sheet.alpha_composite(raw.crop((110,130,290,290)),((i%4)*180,(i//4)*160))
            map_sheet.save(folder/'all_actual_map_idle_native.png')
        print(name,source.size,'complete actual viewports',len(captures))

if __name__=='__main__':main()
