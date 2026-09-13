#!/usr/bin/env python3
"""Publish checked production records into existing cue manifests and banks."""
import argparse
from collections import defaultdict
import hashlib
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'art/audio/source/stable_audio_3_v1'

def load(path):
    return json.loads(path.read_text(encoding='utf-8'))

def save(path,value):
    path.write_text(json.dumps(value,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')

def profiles():
    units=load(ROOT/'content/units.json')['items']
    art={r['unit_id']:r for r in load(ROOT/'content/unit_art_manifest.json')['items']}
    groups={
      'machine':['unit_embercourt_charter_colossus','unit_brasshollow_rivet_hounds','unit_brasshollow_boiler_rivetcasters','unit_brasshollow_debt_engine_exactors','unit_brasshollow_crucible_crawlers','unit_brasshollow_foundry_saint','unit_brasshollow_pressure_lancers','unit_brasshollow_quenchbell_mortars','unit_brasshollow_quenchspool_slingers','unit_brasshollow_whitegauge_datum_breach_cannons','unit_neutral_quenchbell_ironbacks'],
      'crystal':['unit_aurora_ballista','unit_sunvault_solar_array_striders','unit_sunvault_aurora_ballistae','unit_sunvault_daybreak_colossus','unit_sunvault_splitprism_heliograph_ballistae'],
      'living_wood':['unit_thornwake_barkmantle_rams','unit_thornwake_stagknot_runners','unit_thornwake_graft_matriarchs','unit_thornwake_worldroot_bastion','unit_thornwake_dawnseed_bolters','unit_thornwake_canopy_rammers','unit_thornwake_seedglass_cantors','unit_thornwake_seedshield_wardens','unit_thornwake_bramblekite_needlers','unit_thornwake_pollenhook_whistlers','unit_neutral_rootvault_barkhulks','unit_thornwake_woundroot_rootmaul_behemoths','unit_neutral_rootcrown_knotstags'],
      'spectral':['unit_veilmourn_obituary_scribes','unit_veilmourn_mirrorkeel_reavers','unit_veilmourn_tidehook_deckhands','unit_veilmourn_wakeglass_navigators','unit_veilmourn_saltwake_eulogists','unit_veilmourn_wakechain_boarders','unit_veilmourn_saltbell_casters','unit_veilmourn_gloamkeel_bulwarks','unit_veilmourn_dreamwake_foganchor_colossi'],
      'hound':['unit_gorefen_ripper','unit_mireclaw_gorefen_rippers','unit_neutral_fenhound_runners'],
      'antlered':['unit_mireclaw_drowned_antler_sovereign','unit_neutral_cinderwake_aurochs','unit_neutral_galehorn_striders','unit_neutral_ashcrown_kilnelk','unit_mireclaw_moonbite_mirehorn_breakers'],
      'wyrm':['unit_embercourt_sluicefire_lindworms','unit_neutral_deepforge_vaultwyrms','unit_neutral_gaugecoil_orewyrms'],
      'bear':['unit_neutral_brambleback_knucklebears'],
      'amphibian':['unit_neutral_mireglass_belltoads','unit_neutral_miremoon_crownmaws','unit_neutral_fenmirror_gallowshells'],
      'winged':['unit_neutral_rimebell_skyrakers','unit_neutral_cindervane_censerwings'],
      'insect':['unit_neutral_sunscale_lanternmoths','unit_neutral_noonshard_prism_kites'],
      'ray':['unit_neutral_tideglass_skyrays','unit_neutral_prismwake_raylings','unit_neutral_gloambell_wake_mantas'],
      'leviathan':['unit_veilmourn_fogbound_leviathan','unit_neutral_saltwake_bellwhales'],
    }
    body_by_id={id:body for body,ids in groups.items() for id in ids}
    known={u['id'] for u in units}
    assert set(body_by_id)<=known
    result={}
    for u in units:
        id=u['id']; body=body_by_id.get(id,'humanoid'); weapon='blade'
        if u.get('ranged'):
            weapon='arcane'
            for key,terms in [('bow',['archer','hearthbow','thornbow']),('sling',['sling','millstone']),
              ('bolt',['bow_crews','scrapbow','reefbolt','cartbow','bolter','arbalist']),
              ('thrown',['throw','tosser','hurl','jarrier','lobber','dart','needler','net_']),
              ('chain',['harpoon']),('siege',['ballista','mangonel','cannon','mortar','bombard','rivetcast','crucible'])]:
                if any(t in id for t in terms): weapon=key
        else:
            if any(t in id for t in ['pike','pole','lanc','halberd','fordhook','river_guard']):weapon='polearm'
            if any(t in id for t in ['maul','mallet','cudgel','brute']):weapon='blunt'
            if any(t in id for t in ['chain','lash','thornwhip']):weapon='chain'
        if body not in ['humanoid','machine','crystal','spectral']:
            weapon=''
        material={'machine':'machine','crystal':'stone','living_wood':'wood','spectral':'cloth',
            'amphibian':'wet','leviathan':'wet','ray':'wet'}.get(body,'metal' if body=='humanoid' and u.get('defense',0)>=5 else 'cloth')
        result[id]={'body_bank':'body_'+body,'weapon_bank':'weapon_'+weapon if weapon else '',
            'impact_bank':'impact_'+material,'art_path':art[id]['battle_standee'],
            'art_sha256':hashlib.sha256((ROOT/art[id]['battle_standee'].removeprefix('res://')).read_bytes()).hexdigest(),
            'review':'Inspected all 160 standees in four contact sheets, 2026-09-13; shared body/material design, not species-specific dialogue.'}
    return result

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--partial',action='store_true');args=parser.parse_args()
    jobs=load(SOURCE/'jobs.json')['jobs']
    records={}
    for job in jobs:
        path=SOURCE/'provenance'/(job['id']+'.json')
        if path.exists():
            record=load(path)
            if record.get('status')=='technical_checks_passed':
                runtime=ROOT/record['runtime_path'].removeprefix('res://')
                assert hashlib.sha256(runtime.read_bytes()).hexdigest()==record['runtime_sha256']
                records[job['id']]=record
    if not args.partial and len(records)!=len(jobs):
        raise RuntimeError(f'Only {len(records)}/{len(jobs)} audio jobs complete')
    manifests={name:load(ROOT/'content'/(name+'_manifest.json')) for name in ['ui_sfx','presentation_sfx','battle_sfx','ambient_sfx','music_runtime']}
    previous_cues={name:json.dumps(manifest['cues'],sort_keys=True) for name,manifest in manifests.items()}
    banks=defaultdict(list);cues={}
    for r in records.values():
        entry={'path':r['runtime_path'],'duration_msec':round(r['edit']['runtime_statistics']['seconds']*1000),
            'role':r['brief_id'],'volume_db':-15.0,'provenance':'res://'+str((SOURCE/'provenance'/(r['id']+'.json')).relative_to(ROOT)).replace('\\','/'),
            'sha256':r['runtime_sha256'],'priority_class':'normal','repeat_cooldown_msec':140}
        if r['category'] in ['movement','unit_body']:entry['volume_db']=-21.0
        if r['category']=='notifications':entry['repeat_cooldown_msec']=1000
        if r.get('gesture')=='defeat':entry['priority_class']='high'
        if r['priority']=='P0':
            for name,manifest in manifests.items():
                for cue in r['targets']:
                    if cue not in manifest['cues']:continue
                    if name=='music_runtime' and cue.endswith(('_harmony','_motion')):continue
                    old=manifest['cues'][cue]
                    updated={**old,**entry,'volume_db':old['volume_db'],'role':old['role'],
                        'priority_class':old.get('priority_class','normal'),
                        'repeat_cooldown_msec':old.get('repeat_cooldown_msec',140)}
                    if name=='music_runtime':updated.update(playback_mode='full_mix',volume_db=-15.0)
                    if name=='ambient_sfx':updated['volume_db']=-20.0 if 'pressure' not in cue else -29.0
                    manifest['cues'][cue]=updated
        else:
            bank=r['brief_id']+('_'+r['gesture'] if r['gesture'] else '')
            id='production_'+r['id']
            entry.update(cooldown_key=bank,id=id)
            cues[id]=entry;banks[bank].append(id)
            if r['category']=='town_ambience':
                manifests['ambient_sfx']['cues'][r['brief_id']]={**entry,'volume_db':-22.0}
    for name,manifest in manifests.items():
        manifest['generated_by']='tools/generate_production_audio.py'
        if name in ['music_runtime','ambient_sfx']:
            manifest.update(segment_duration_msec=0,duration_policy='per_cue',encoder_quality=5,
                master_sample_width_bits=24,asset_tier='generated_full_mix_v1' if name=='music_runtime' else 'generated_ambient_loop_v1')
        accepted=(not args.partial and manifest.get('production_status')=='accepted'
            and 'listening_acceptance' in manifest
            and previous_cues[name]==json.dumps(manifest['cues'],sort_keys=True))
        if not accepted:manifest.pop('listening_acceptance',None)
        manifest.update(production_source='stable_audio_3_v1',production_status='generation_in_progress' if args.partial else ('accepted' if accepted else 'technical_checks_passed_listening_review_pending'),
            generation_pipeline='tools/generate_production_audio.py',legacy_regeneration_protected=True)
        save(ROOT/'content'/(name+'_manifest.json'),manifest)
    spell_banks={}
    effect_names={'damage_enemy':'impact','attack_buff':'empower','defense_buff':'ward','initiative_buff':'haste','control_enemy':'bind','cleanse_ally':'cleanse','recover_ally':'heal','restore_movement':'field_march','reveal_radius':'field_reveal'}
    for s in load(ROOT/'content/spells.json')['items']:
        base='magic_'+s['school_id']+'_'
        spell_banks[s['id']]={'cast':base+'cast','effect':base+effect_names[s['effect']['type']],
            'expire':base+'expire' if s['effect'].get('duration_rounds',0)>0 else '', 'context':s['context']}
    save(ROOT/'content/audio_production_banks.json',{'schema':'audio_production_banks_v1','banks':dict(banks),'cues':cues,'unit_profiles':profiles(),'spell_banks':spell_banks})
    print('Published',len(records),'of',len(jobs),'checked jobs;',len(banks),'banks;',len(cues),'bank variants')

if __name__=='__main__':main()
