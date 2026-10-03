"""Record personally reviewed original frame indices, then rebuild their handoff."""
import argparse,json
import produce as p

def indices(text):
 result=[]
 for part in text.split(','):
  bounds=[int(n) for n in part.split(':')]
  result.extend(range(bounds[0],bounds[1]+1,bounds[2] if len(bounds)==3 else 1) if len(bounds)>1 else bounds)
 assert result and len(result)==len(set(result)) and all(0<=n<124 for n in result)
 return result

if __name__=='__main__':
 parser=argparse.ArgumentParser(description=__doc__)
 parser.add_argument('take');parser.add_argument('frames',help='Comma-separated indices or start:end:step inclusive ranges')
 parser.add_argument('--msec',type=int,required=True);parser.add_argument('--contact-source',type=int)
 parser.add_argument('--note',required=True);parser.add_argument('--durations',help='Exact authored timing for each selected original frame')
 args=parser.parse_args();out=p.SOURCE_DIR/args.take;c=json.loads((out/'config.json').read_bytes())
 chosen=indices(args.frames);assert args.msec>=30
 selection=dict(source_frames=chosen,frame_msec=args.msec,review_note=args.note)
 if args.contact_source is not None:selection['contact_frame']=chosen.index(args.contact_source)
 if args.durations:
  durations=[int(n) for n in args.durations.split(',')];assert len(durations)==len(chosen) and min(durations)>=30
  selection['frame_durations_msec']=durations
 p.write(out/'selection.json',selection);p.build(out,c)
 print(c['clip'],len(chosen),'original frames; duration',sum(selection.get('frame_durations_msec',[args.msec]*len(chosen))),flush=True)
