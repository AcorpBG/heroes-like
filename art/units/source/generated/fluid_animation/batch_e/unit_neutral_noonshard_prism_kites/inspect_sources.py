"""Lossless chronological RGB and transparent anatomy review at fixed crops."""
import argparse,hashlib,json
from pathlib import Path
import av
from PIL import Image,ImageDraw
import produce as p

def inspect(take):
    folder=p.SOURCE_DIR/take;record=json.loads((folder/'original.json').read_bytes())
    assert p.sha(folder/'original_lossless.mkv')==record['sha256']
    rgb=[]
    with av.open(str(folder/'original_lossless.mkv')) as video:
        for i,frame in enumerate(video.decode(video=0)):
            im=frame.to_image().convert('RGB')
            assert hashlib.sha256(im.tobytes()).hexdigest()==record['decoded_rgb_sha256'][i]
            rgb.append(im)
    assert len(rgb)==124
    target=p.ROOT/'.artifacts/noonshard_prism_kite_h3'/take;target.mkdir(exist_ok=True)
    for page in range(8):
        sheet=Image.new('RGB',(1536,1664),(16,32,64));draw=ImageDraw.Draw(sheet)
        for j,index in enumerate(range(page*16,min(124,(page+1)*16))):
            im=rgb[index].resize((384,282),Image.Resampling.LANCZOS)
            x,y=j%4*384,j//4*416;sheet.paste(im,(x,y+25))
            draw.text((x+8,y+5),f'original RGB {index}, {index/24:.3f}s',fill='white')
        sheet.save(target/f'original_rgb_{page:02}.png')
    manifest='edge_matte' if (folder/'edge_matte.json').exists() else 'matte'
    if not (folder/(manifest+'.json')).exists():return
    hashes=json.loads((folder/(manifest+'.json')).read_bytes())['rgba_sha256']
    frames=[Image.open(folder/manifest/f'rgba_{i:03}.png').convert('RGBA') for i in range(124)]
    for i,im in enumerate(frames):assert p.sha(folder/manifest/f'rgba_{i:03}.png')==hashes[i]
    bounds=[im.getbbox() for im in frames];assert all(bounds)
    crop=(max(0,min(b[0] for b in bounds)-16),max(0,min(b[1] for b in bounds)-16),min(rgb[0].width,max(b[2] for b in bounds)+16),min(rgb[0].height,max(b[3] for b in bounds)+16))
    for page in range(8):
        sheet=Image.new('RGB',(1536,1760),(28,38,28));draw=ImageDraw.Draw(sheet)
        for j,index in enumerate(range(page*16,min(124,(page+1)*16))):
            x,y=j%4*384,j//4*440
            if j%2:sheet.paste((219,212,197),(x,y,x+384,y+440))
            im=frames[index].crop(crop);im.thumbnail((380,408),Image.Resampling.LANCZOS)
            sheet.paste(im,(x+(384-im.width)//2,y+26),im)
            draw.text((x+7,y+5),f'original matte {index}',fill=(135,115,65))
        sheet.save(target/f'enlarged_rgba_{page:02}.png')
    print('FULL124_RGB_AND_RGBA_REVIEW_PAGES',take,'fixed_crop',crop,flush=True)

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('takes',nargs='+');args=parser.parse_args()
    for take in args.takes:inspect(take)
