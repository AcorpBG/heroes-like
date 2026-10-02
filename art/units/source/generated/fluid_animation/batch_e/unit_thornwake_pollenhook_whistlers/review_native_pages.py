"""Split wide native pose gallery into unscaled readable chronological pages."""
from PIL import Image
from pathlib import Path
import argparse
if __name__=='__main__':
 a=argparse.ArgumentParser();a.add_argument('folder',type=Path);args=a.parse_args()
 uid='unit_thornwake_pollenhook_whistlers';im=Image.open(args.folder/(uid+'-overview.png'))
 # Overlap by160 pixels so a128-pixel native sprite is never split between
 # two inspection pages without a complete copy on an adjacent page.
 starts=[0]+list(range(1015,im.height,980))
 for i,start in enumerate(starts):
  end=1175 if i==0 else start+1140;im.crop((0,start,im.width,min(end,im.height))).save(args.folder/f'native_page_{i}.png')
 print('Native readable pages',len(starts),im.size)
