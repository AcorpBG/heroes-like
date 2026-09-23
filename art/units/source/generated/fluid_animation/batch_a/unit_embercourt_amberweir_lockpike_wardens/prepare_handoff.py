"""Original component crops; same extraction recipe as the Ember Archer."""
from pathlib import Path
import runpy,json,hashlib
HERE=Path(__file__).resolve().parent
ROOT=next(p for p in HERE.parents if (p/'project.godot').exists())
helpers=runpy.run_path(str(HERE.parent/'unit_ember_archer/prepare_handoff.py'))
uid=HERE.name
configs={
 'move':(.525,[222,690,1158,1626]*2,[409,410,409,409,829,824,824,828]),
 'idle':(.525,[290,748]*4,[382,381,757,757,1142,1141,1518,1520]),
 'attack':(.50,[249,749,245,741,246,742,258,774],[433,430,764,765,1092,1094,1513,1515]),
 'cast':(.55,[320,777]*4,[399,399,785,790,1156,1156,1516,1517]),
 'death':(.45,[293,786]*4,[463,463,858,864,1162,1140,1416,1419]),
 'reactions':(.53,[320,770]*4,[382,377,759,768,1141,1134,1513,1509])}
generation_ids={'idle_v1':'cc3b459e-c70f-49f4-ace6-0bbac127175b','move_v1':'18002d9a-bf83-43f3-a27c-5e194c6a18bc','move_v2':'b0fde166-7718-4246-a07b-44b250585f21','move_v3':'6e50c139-4705-4981-950d-bc4981d7eead','attack_v1':'3d62ecde-c23e-4271-94ac-0772083b775c','cast_v1':'d872cc47-e948-47e8-a08a-d0ba66564b30','death_v1':'ac8b44d5-a822-4eb0-9bd0-308a8e2d8064','reactions_v1':'03416593-7cd5-4ee5-b122-2669afa60462'}
generation_ids['move_v4']='4e370097-2c12-411f-a6d5-412b6efe72a4'
frames=[];clips={};provenance=[]
for kind,(scale,xs,ys) in configs.items():
 path=HERE/(kind+('_v4.png' if kind=='move' else '_v1.png'))
 im,labels,found=helpers['components'](path)
 mains=sorted((c for c in found if c['size']>10000),key=lambda c:c['center'][1])
 assert len(mains)==8,(kind,len(mains))
 columns=4 if kind=='move' else 2
 mains=[c for start in range(0,8,columns) for c in sorted(mains[start:start+columns],key=lambda c:c['center'][0])]
 start=len(frames)
 for i,main in enumerate(mains):
  clip=kind if kind!='reactions' else ('hit' if i<4 else 'defend')
  frames.append({'name':f'{clip}_{i if kind!="reactions" else i%4:02d}','clip':clip,'source':path.relative_to(ROOT).as_posix(),'rects':helpers['safe_rects'](labels,main,[o for o in mains if o!=main]),'anchor':[xs[i],ys[i]],'scale':scale})
 if kind=='reactions':
  clips['hit']={'indices':list(range(start,start+4)),'frame_msec':100,'loop':False,'static_frame':1}
  clips['defend']={'indices':list(range(start+4,start+8)),'frame_msec':110,'loop':False,'static_frame':3}
 else:
  clips[kind]={'indices':list(range(start,start+8)),'frame_msec':125 if kind=='idle' else 100 if kind!='death' else 120,'loop':kind in ('idle','move'),'static_frame':0}
  if kind in ('attack','cast'):clips[kind]['contact_frame']=4
  if kind=='death':clips['dead']={'indices':[start+7],'frame_msec':120,'loop':False,'static_frame':0}
for stem,generation_id in generation_ids.items():
 prompt=HERE/(stem+'.prompt.txt');prompt.write_bytes(prompt.read_bytes().rstrip(b'\r\n'))
 path=HERE/(stem+'.png');ref=HERE/'move_v2.png' if stem=='move_v3' else ROOT/f'art/units/source/curated/{uid}.png'
 sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
 provenance.append({'clip':stem,'tool':'built-in image_gen','status':'rejected_gait' if stem.startswith('move') else 'pending_review','reason':'same visible leg keeps leading; not a complete alternating gait' if stem.startswith('move') else '', 'prompt':prompt.relative_to(ROOT).as_posix(),'prompt_sha256':sha(prompt),'reference':ref.relative_to(ROOT).as_posix(),'reference_sha256':sha(ref),'master':path.relative_to(ROOT).as_posix(),'master_sha256':sha(path),'generation_output':'C:/Users/acorp/.codex/generated_images/01a0ccce-2711-7133-9769-7d380293a5ac/exec-'+generation_id+'.png'})
entry={'unit_id':uid,'reference_height':256,'source_facing':'right','alpha_noise_cutoff':8,'frames':frames,'clips':clips,'accepted_clips':[],'preserve_clips':['move'],'source_scale_by_image':{f['source']:f['scale'] for f in frames},'source_scale_reason':'One fixed scale per original sheet aligns upright head-to-boot anatomy with the current runtime character. No per-frame scaling; collapse and crouch retain original proportions.','visual_review':{'status':'pending','artist_notes':'Partial candidate. Idle has articulated shield-arm lift/lower, attack is pike thrust, cast is physical pike salute, dedicated hit/guard and collapse. Movement versions1-3 rejected: insufficient alternating leg lead. Existing move retained only as unfinished compatibility, not quality acceptance.'},'unfinished_clips':['move']}
entry['preserve_clips']=[]
entry['unfinished_clips']=[]
entry['visual_review']['artist_notes']='Version4 movement uses newly painted character identity over the reviewed Weirshield eight-pose skeleton guide: opposite leading contacts and passing phases now visible. Other actions remain pending root acceptance. No source poses are duplicated or warped.'
for record in provenance:
 if record['clip']=='move_v4':
  record['status']='pending_review';record['reason']=''
  guide=HERE/'move_pose_reference.png'
  record['pose_reference']=guide.relative_to(ROOT).as_posix();record['pose_reference_sha256']=hashlib.sha256(guide.read_bytes()).hexdigest()
  record['pose_reference_lineage']='Reviewed original Weirshield contact/inbetween sequence composed by fluid_art_a as move_preview.png; copied as durable generation input.'
(HERE/'handoff.json').write_text(json.dumps({'schema_version':1,'units':[entry]},indent=2)+'\n')
(HERE/'provenance.json').write_text(json.dumps(provenance,indent=2)+'\n')
print('Prepared 48 original poses including corrected eight-pose movement candidate')
