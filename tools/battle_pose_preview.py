#!/usr/bin/env python3
"""Build an offline animation art desk from actual manifest clips.

Production review only: this does not launch Godot, assert gameplay behavior,
write acceptance metadata or register assets. Original pixels remain unchanged.
The self-contained HTML works without a server or network access.
"""
import argparse
import base64
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REQUIRED = ('idle', 'move', 'attack', 'defend', 'death', 'dead')

PAGE = r'''<!doctype html><html lang="en"><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Battle animation art desk</title>
<style>
*{box-sizing:border-box}body{margin:0;background:#20252c;color:#eee;font:15px system-ui}
header{padding:12px 18px;background:#11161c;position:sticky;top:0;z-index:2}
button,select,input{font:inherit;margin:4px;padding:5px}label{white-space:nowrap}
h1{font-size:20px;margin:0 0 5px}main{padding:16px;display:grid;grid-template-columns:repeat(auto-fit,minmax(340px,1fr));gap:16px}
article{background:#121820;padding:10px;border:1px solid #52606a}h2{font-size:17px;margin:0 0 8px}
canvas{display:block;max-width:100%;height:auto}small{display:block;overflow-wrap:anywhere;color:#acbac9}
output{display:block;min-height:22px}.warn{color:#ffd075}#error{color:#ff9e91}
</style>
<header><h1>Battle animation art desk — production preview, not acceptance</h1>
<label>Unit <select id="unit"></select></label><button id="play">Pause</button>
<button id="restart">Restart clips</button><button id="previous">Previous frame</button><button id="next">Next frame</button>
<label>Speed <select id="speed"><option value="0.5">½×</option><option selected value="1">1×</option><option value="2">2×</option></select></label>
<label>Timing <select id="timing"><option value="battle">Battle event progress</option><option value="source">Source frame timing</option></select></label>
<label title="Normal battle cue duration is currently 700 ms. One-shot poses follow event progress; loops retain their authored frame timing.">Event ms <input id="eventms" type="number" min="1" max="10000" value="700" style="width:90px"></label>
<label>Scale <select id="scale"><option value="0.5">½×</option><option selected value="1">1×</option><option value="2">2×</option></select></label>
<label>Background <select id="back"><option value="#354b38">Landscape green</option><option value="#ece5d6">Light</option><option value="#151b24">Dark</option><option value="#675a50">Earth</option></select></label>
<label><input type="checkbox" id="flip">Opposite facing</label>
<label><input type="checkbox" id="reduce">Reduced motion</label>
<label><input type="checkbox" id="replay" checked>Replay non-looping actions for inspection</label>
<p id="identity"></p><p id="error" role="alert"></p></header><main></main>
<script id="payload" type="application/json">__PAYLOAD__</script><script>
const rows=JSON.parse(document.querySelector('#payload').textContent), $=s=>document.querySelector(s);
let row,texture,panels=[],playing=true,elapsed=0,last=null,request=0,stepping=false;
for(const r of rows){const o=document.createElement('option');o.value=r.unit_id;o.textContent=r.unit_id;$('#unit').append(o)}
function frameIndices(spec){return spec.indices??Array.from({length:spec.frames??1},(_,i)=>(spec.row??0)*row.pose_columns+(spec.column??0)+i)}
function setup(){
 row=rows.find(r=>r.unit_id===$('#unit').value);elapsed=0;stepping=false;panels=[];const seq=++request;texture=null;$('main').replaceChildren();$('#error').textContent='';
 $('#identity').textContent=row.unit_id+' | '+row.pose_review_status+' | '+row.source+' | '+row.sha256;
 for(const name of [...new Set([...['idle','move','attack','defend','death','dead'],...Object.keys(row.pose_clips),...Object.keys(row.pose_aliases??{})])]){
   const key=(row.pose_aliases??{})[name]??name,spec=row.pose_clips[key],a=document.createElement('article'),h=document.createElement('h2');h.textContent=name+(key!==name?' → '+key:'');a.append(h);
   if(!spec){const e=document.createElement('p');e.className='warn';e.textContent='MISSING — cannot accept';a.append(e);$('main').append(a);continue}
   const c=document.createElement('canvas'),out=document.createElement('output'),info=document.createElement('small');c.width=row.pose_frame_size.width;c.height=row.pose_frame_size.height+26;
   info.textContent=JSON.stringify(spec);a.append(c,out,info);$('main').append(a);panels.push({name,spec,c,out,indices:frameIndices(spec)});
 }
 const img=new Image();img.onload=()=>{if(seq===request){texture=img;draw()}};img.onerror=()=>{$('#error').textContent='Unable to decode atlas'};img.src=row.image;
}
function indexFor(p){
 if($('#reduce').checked)return Math.min(p.indices.length-1,p.spec.static_frame??0);
 if(stepping)return p.manual??0;
 if(p.name==='dead')return 0;
 // Match BattleUnitPose.region: loops follow elapsed clip time, but one-shot
 // actions span event progress. Per-frame authoring timing is optional review,
 // not the runtime authority. Replay is an art-desk convenience only.
 const frameMsec=!p.spec.loop&&$('#timing').value==='battle'
   ?Math.max(1,Number($('#eventms').value)||700)/p.indices.length
   :Math.max(1,p.spec.frame_msec??150);
 const n=Math.floor(elapsed/frameMsec);
 return p.spec.loop||$('#replay').checked?n%p.indices.length:Math.min(p.indices.length-1,n);
}
function draw(){if(!texture)return;$('main').style.gridTemplateColumns=`repeat(auto-fit,minmax(min(100%,${row.pose_frame_size.width*Number($('#scale').value)+24}px),1fr))`;for(const p of panels){
 const ctx=p.c.getContext('2d'),w=row.pose_frame_size.width,h=row.pose_frame_size.height,scale=Number($('#scale').value),f=indexFor(p),idx=p.indices[f],x=idx%row.pose_columns*w,y=Math.floor(idx/row.pose_columns)*h;
 const cw=Math.round(w*scale),ch=Math.round(h*scale)+26;if(p.c.width!==cw||p.c.height!==ch){p.c.width=cw;p.c.height=ch}
 ctx.fillStyle=$('#back').value;ctx.fillRect(0,0,cw,ch);
 ctx.strokeStyle='#9ba8ad';ctx.beginPath();ctx.moveTo(0,h*scale);ctx.lineTo(cw,h*scale);ctx.stroke();
 const groundOffset=Math.max(0,Math.min(h-1,row.pose_ground_margin??0))*scale;
 ctx.save();if($('#flip').checked!==(row.pose_source_facing==='left')){ctx.translate(cw,0);ctx.scale(-1,1)}
 if(row.pose_frame_rects){const [rx,ry,rw,rh]=row.pose_frame_rects[idx],a=row.pose_region_anchors[`${rx},${ry}`];ctx.drawImage(texture,rx,ry,rw,rh,((row.pose_anchor_x??w/2)-a[0])*scale,(h-a[1])*scale,rw*scale,rh*scale)}
 else ctx.drawImage(texture,x,y,w,h,0,groundOffset,cw,h*scale);ctx.restore();
 p.out.textContent='Frame '+(f+1)+'/'+p.indices.length+' · atlas '+idx+' · '+(p.spec.loop?'loop':'one-shot');
 }}
function tick(t){if(last!==null&&playing)elapsed+=Math.min(t-last,100)*Number($('#speed').value);last=t;draw();requestAnimationFrame(tick)}
$('#unit').onchange=setup;$('#play').onclick=()=>{playing=!playing;if(playing)stepping=false;$('#play').textContent=playing?'Pause':'Play'};
$('#restart').onclick=()=>{elapsed=0;stepping=false;draw()};
function step(d){playing=false;$('#play').textContent='Play';for(const p of panels)p.manual=(indexFor(p)+d+p.indices.length)%p.indices.length;stepping=true;draw()}
$('#previous').onclick=()=>step(-1);$('#next').onclick=()=>step(1);
for(const id of ['scale','back','flip','reduce','replay','timing','eventms'])$('#'+id).onchange=draw;
setup();requestAnimationFrame(tick);
</script></html>'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--unit', action='append', help='Repeat for a cohort; default all registered candidates')
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--atlas', type=Path, help='One-unit candidate override; never changes runtime registration')
    parser.add_argument('--recipe', type=Path, help='Unregistered packing recipe with explicit pose_clips for art review')
    args = parser.parse_args()
    if args.atlas and (not args.unit or len(args.unit) != 1):
        raise ValueError('--atlas requires exactly one --unit')
    candidate = None
    if args.recipe:
        if not args.atlas or not args.recipe.resolve().is_relative_to((ROOT/'art/animation/source').resolve()):
            raise ValueError('--recipe requires --atlas and a scoped source recipe')
        candidate = json.loads(args.recipe.read_text())
        if candidate['unit_id'] != args.unit[0] or not candidate.get('pose_clips'):
            raise ValueError('Recipe identity/explicit clips required; never invent missing states')
    import hashlib
    manifest = json.loads((ROOT/'content/unit_animation_manifest.json').read_text())
    rows = []
    for item in manifest['items']:
        if (not item.get('pose_sheet') and not candidate) or (args.unit and item['unit_id'] not in args.unit):
            continue
        path = args.atlas.resolve() if args.atlas else (ROOT/item['pose_sheet'].removeprefix('res://')).resolve()
        if not path.is_relative_to((ROOT/'art/animation').resolve()):
            raise ValueError('Out-of-scope art source')
        data = path.read_bytes()
        row = {k: v for k, v in item.items() if k.startswith('pose_') or k == 'unit_id'}
        if candidate:
            width, height = candidate['frame_size']
            row.update(pose_frame_size={'width': width, 'height': height},
                       pose_columns=candidate['columns'], pose_clips=candidate['pose_clips'],
                       pose_ground_margin=candidate['ground_margin'],
                       pose_aliases=candidate.get('pose_aliases', {}),
                       pose_source_facing=candidate.get('pose_source_facing', 'right'))
        row.update(image='data:image/png;base64,'+base64.b64encode(data).decode(),
                   sha256=hashlib.sha256(data).hexdigest(), source=str(path.relative_to(ROOT)))
        if args.atlas:
            row['pose_review_status'] = 'unregistered candidate override'
        rows.append(row)
    if not rows or (args.unit and set(args.unit) != {r['unit_id'] for r in rows}):
        raise ValueError('Requested unit lacks a registered pose atlas')
    if args.output.exists():
        raise ValueError('Use a new review output path; do not overwrite evidence')
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(PAGE.replace('__PAYLOAD__', json.dumps(rows).replace('<', '\\u003c')))
    print(f'{len(rows)} candidate(s): {args.output}')


if __name__ == '__main__':
    main()
