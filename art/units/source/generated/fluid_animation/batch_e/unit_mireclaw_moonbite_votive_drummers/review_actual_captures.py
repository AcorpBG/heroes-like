"""Make exact native and enlarged battle crops for personal visual review."""
import argparse
from pathlib import Path
from PIL import Image, ImageDraw


def run(directory):
    files=sorted(directory.glob('battle-phase-*.png'),key=lambda p:int(p.stem.rsplit('-',1)[1]))
    assert len(files)==8
    for scale,columns in [(1,4),(2,2)]:
        w,h=380*scale,170*scale
        chart=Image.new('RGB',(columns*w,((len(files)+columns-1)//columns)*(h+22)),(215,215,215))
        draw=ImageDraw.Draw(chart)
        for i,file in enumerate(files):
            original=Image.open(file).convert('RGB')
            assert original.size==(1280,720)
            crop=original.crop((450,210,830,380))
            if scale!=1:crop=crop.resize((w,h),Image.Resampling.NEAREST)
            x,y=(i%columns)*w,(i//columns)*(h+22)
            draw.text((x+3,y+3),directory.name+' actual capture '+str(i),fill='black')
            chart.paste(crop,(x,y+22))
        if scale==1:
            chart.save(directory/'actual_battle_all_1x.png')
        else:
            for page in range(2):
                chart.crop((0,page*2*(h+22),chart.width,(page+1)*2*(h+22))).save(directory/('actual_battle_2x_page_'+str(page)+'.png'))


if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('directory',type=Path)
    run(parser.parse_args().directory)
