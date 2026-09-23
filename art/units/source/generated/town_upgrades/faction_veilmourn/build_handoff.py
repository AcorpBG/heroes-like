from pathlib import Path
import json, hashlib
from PIL import Image
import numpy as np

ROOT=Path(__file__).resolve().parents[6]
SOURCE=Path(__file__).resolve().parent
DESIGNS=json.loads((ROOT/'content/unit_upgrade_designs/faction_veilmourn.json').read_text(encoding='utf-8-sig'))['items']
units=[]
for row in DESIGNS:
    uid=row['upgrade_id']; path=SOURCE/(uid+'.png')
    if not path.exists(): continue
    im=Image.open(path); a=np.asarray(im.getchannel('A')); h,w=a.shape
    frames=[]; observations=[]
    for band in range(2):
        y0,y1=band*h//2,(band+1)*h//2
        part=a[y0:y1]>8
        candidates=np.arange(int(w*.48),int(w*.58))
        counts=part[:,candidates].sum(axis=0)
        separator=int(candidates[np.argmin(counts)])
        for side,(x0,x1) in enumerate(((0,separator),(separator,w))):
            slot=band*2+side
            if uid=='unit_veilmourn_tidehook_deckhands_veteran' and slot==2: continue
            crop=a[y0:y1,x0:x1]>8
            ys,xs=np.where(crop)
            b=(x0+int(xs.min()),y0+int(ys.min()),x0+int(xs.max())+1,y0+int(ys.max())+1)
            fy,fx=np.where(crop[max(0,int(ys.max())-32):int(ys.max())+1])
            anchor=[x0+int(round((fx.min()+fx.max())/2)),b[3]-1]
            rects=[[x0,y0,x1,y1]]
            if uid=='unit_veilmourn_mirrorkeel_reavers_veteran' and band==1:
                rects=([[0,627,710,900],[0,900,601,1254]] if side==0 else [[710,627,1254,900],[601,900,1254,1254]])
            frames.append({'rects':rects,'anchor':anchor})
            observations.append({'slot':slot,'alpha_bbox':list(b),'separator_alpha_pixels':int(counts.min())})
    unit_entry={'unit_id':uid,'source':path.relative_to(ROOT).as_posix(),'frames':frames,'alpha_noise_cutoff':8}
    action_path=SOURCE/(uid+'_actions.png')
    if action_path.exists():
        action_image=Image.open(action_path);aa=np.asarray(action_image.getchannel('A'));ah,aw=aa.shape
        rows=np.arange(int(ah*.4),int(ah*.65));zero_rows=rows[(aa[rows]>8).sum(axis=1)==0]
        assert len(zero_rows),uid+' action row separation missing'
        cut=int(zero_rows[np.argmin(abs(zero_rows-ah/2))]);actions=[]
        for bi,(yy0,yy1) in enumerate(((0,cut),(cut,ah))):
            cc=np.arange(int(aw*.43),int(aw*.62));totals=(aa[yy0:yy1,cc]>8).sum(axis=0);zeros=cc[totals==0]
            if len(zeros):
                xx=int(zeros[np.argmin(abs(zeros-aw/2))]);regions=[[[0,yy0,xx,yy1]],[[xx,yy0,aw,yy1]]]
            else:
                regions=[[],[]]
                for yy in range(yy0,yy1,16):
                    ye=min(yy+16,yy1);tt=(aa[yy:ye,cc]>8).sum(axis=0);zz=cc[tt==0];assert len(zz),uid+' action strip separation missing'
                    xx=int(zz[np.argmin(abs(zz-aw/2))]);regions[0].append([0,yy,xx,ye]);regions[1].append([xx,yy,aw,ye])
            for side,rects in enumerate(regions):
                rects=[rect for rect in rects if (aa[rect[1]:rect[3],rect[0]:rect[2]]>8).any()]
                slot=bi*2+side;mask=np.zeros(aa.shape,dtype=bool)
                for l,t,r,b in rects:mask[t:b,l:r]=True
                ay,ax=np.where(mask&(aa>8));floor=int(ay.max());bottom=(ay>=floor-32);anchor=[int(round((ax[bottom].min()+ax[bottom].max())/2)),floor]
                actions.append({'source':action_path.relative_to(ROOT).as_posix(),'clip':('attack','attack','hit','dead')[slot],'name':('attack_windup','attack_release','hit_recoil','fallen')[slot],'rects':rects,'anchor':anchor})
        unit_entry['actions']=actions
        action_provenance={'unit_id':uid,'created_utc_date':'2026-09-23','generator':'built-in image_gen','source':action_path.relative_to(ROOT).as_posix(),'sha256':hashlib.sha256(action_path.read_bytes()).hexdigest(),'size':list(action_image.size),'mode':action_image.mode,'prompt_file':(SOURCE/(uid+'_actions.prompt.txt')).relative_to(ROOT).as_posix(),'reference_files':[{'source':path.relative_to(ROOT).as_posix(),'role':'Accepted original upgraded idle design; preserve character identity, equipment, camera and rendering.','sha256':hashlib.sha256(path.read_bytes()).hexdigest()}],'selected_actions':actions,'visual_review':'Four original articulated battle poses: attack windup, attack release, hit recoil and truly fallen corpse; transparent source exterior, no ground or gore.'}
        (SOURCE/(uid+'_actions.provenance.json')).write_text(json.dumps(action_provenance,indent=2)+'\n')
    units.append(unit_entry)
    prompts=sorted(SOURCE.glob(uid+'*.prompt.txt'))
    provenance={'unit_id':uid,'name':row['name'],'created_utc_date':'2026-09-23','generator':'built-in image_gen','source':path.relative_to(ROOT).as_posix(),'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'size':list(im.size),'mode':im.mode,'prompt_files':[p.relative_to(ROOT).as_posix() for p in prompts],'portable_reference_files':['art/units/battle_standees/unit_veilmourn_gloamkeel_bulwarks.png'],'reference_role':'Existing standee inspected for painterly rendering style only; no base sprite recoloring or pixel reuse.','frame_selection':observations,'quality_notes':'Visually reviewed genuinely distinct arm/weapon poses. Tidehook slot2 excluded for missing second hook.' if 'tidehook' in uid else 'Visually reviewed genuinely distinct arm/weapon poses, preserved generated alpha.'}
    provenance['selected_prompt_file']=(SOURCE/(uid+('.clean.prompt.txt' if 'leviathan' in uid else '.final.prompt.txt' if (SOURCE/(uid+'.final.prompt.txt')).exists() else '.prompt.txt'))).relative_to(ROOT).as_posix()
    provenance['preserved_candidates']=[{'source':p.relative_to(ROOT).as_posix(),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in SOURCE.glob(uid+'*_candidate.png')]
    if 'leviathan' in uid: provenance['quality_notes']='Final clean generation selected after two fog-haze candidates; four distinct jaw, neck and shoulder-fin poses, genuinely transparent exterior.'
    if 'mirrorkeel' in uid: provenance['quality_notes']='Four articulated blade/arm poses. Lower pair uses two-rectangle masks separated at y900 to preserve extended blade and neighboring trailing cape without clipping.'
    (SOURCE/(uid+'.provenance.json')).write_text(json.dumps(provenance,indent=2)+'\n')
out=ROOT/'.artifacts/veil_upgrade_art_20260923/handoff.json';out.parent.mkdir(parents=True,exist_ok=True);out.write_text(json.dumps({'faction_id':'faction_veilmourn','units':units},indent=2)+'\n')
print(json.dumps({'units':len(units),'frames':sum(len(u['frames']) for u in units),'handoff':str(out),'observations':[{'unit':u['unit_id'],'frames':u['frames']} for u in units]},indent=2))
