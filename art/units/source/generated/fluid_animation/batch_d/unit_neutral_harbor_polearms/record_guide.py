"""Record generated guide masters and their real edit-target lineage."""
import argparse
from PIL import Image
import produce as p

parser=argparse.ArgumentParser()
parser.add_argument('name')
parser.add_argument('--target', required=True)
parser.add_argument('--output', required=True)
parser.add_argument('--status', required=True)
parser.add_argument('--reason', required=True)
args=parser.parse_args()
image=p.SOURCE_DIR/(args.name+'.png')
prompt=p.SOURCE_DIR/(args.name+'.prompt.txt')
target=p.ROOT/args.target
im=Image.open(image)
p.write(image.with_suffix('.generation.json'),dict(
    tool='builtin image_gen',generated_output_path=args.output,
    image=dict(path=image.relative_to(p.ROOT).as_posix(),sha256=p.sha(image)),
    prompt=dict(path=prompt.relative_to(p.ROOT).as_posix(),sha256=p.sha(prompt)),
    references=[dict(path=args.target,sha256=p.sha(target),role='edit target')],
    status=args.status,review_reason=args.reason,
    size=list(im.size),mode=im.mode,alpha_extrema=list(im.getchannel('A').getextrema()),
    h3_eligible=args.status=='approved_guide'))
