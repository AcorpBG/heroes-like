#!/usr/bin/env python3
"""Package approved scene-matched raster masters, never synthesize building art."""
import argparse
import copy
import hashlib
import json
from pathlib import Path
import subprocess

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
FACTION = 'faction_veilmourn'
BRIEFS = {
    'building_veilmourn_bell_harbor': {
        'source_sha256':'8da88597e30bd95d3ae5d172e100ffd34c85c644cb002a1bded726a38cc0e97d',
        'scene_bounds':[690,390,320,300], 'ground_anchor':[850,650],
        'grounding':'Left gangway joins the existing main quay; wet pilings descend into the central harbor. Preserve the open navigation water.',
    },
    'building_wayfarers_hall': {
        'source_sha256':'a42efba0e557456853265365df4000c223df86c6b22085e4eab30d6c1394d5f5',
        'scene_bounds':[945,330,390,260], 'ground_anchor':[1140,552],
        'grounding':'Lodge occupies the middle-distance right shore, behind the foreground gate and quay. Its covered stair opens toward the bell docks.',
    },
    'building_market_square': {
        'source_sha256':'9afc680fe3311278da44f54c069854764ef3f17d2f9020e32925a1b4b27aafe1',
        'scene_bounds':[200,560,375,250], 'ground_anchor':[390,755],
        'grounding':'Low trading arcade attaches to the foreground-left quay below the main tower; wet pilings and boat-loading ramp continue its working waterfront. Preserve the tower door, central water and accepted bell docks.',
    },
    'building_veilmourn_fog_signal_buoys': {
        'source_sha256':'3b4b49e32f73eae6d2f2d0b4c9dc72c45fbbef9f9cc32f2df14fde4498c22075',
        'scene_bounds':[860,650,180,120], 'ground_anchor':[950,750],
        'grounding':'Small floating bell and lantern buoys mark the foreground channel below Bell Harbor, clear of bottom navigation and developed quay structures. Their separate hulls preserve water gaps.',
    },
    'building_veilmourn_salvage_ledger': {
        'source_sha256':'9dbf801a2053651a467237e38fd01c082b1241aad600505b67e29b7897436467',
        'scene_bounds':[480,450,260,260*1024/1536], 'ground_anchor':[600,600],
        'grounding':'Compact claims office extends the left working quay above the Market Square and below the main tower; preserve the tower door and the Bell Harbor gangway.',
    },
    'building_veilmourn_ransom_exchange': {
        'source_sha256':'95e4fe8730c7c9ae10493a83c6330b92ba2bfdcb8cc2c98052c89e31c2657a1d',
        'scene_bounds':[1080,515,310,310*1024/1536], 'ground_anchor':[1225,690],
        'grounding':'Low exchange counters continue the right waterfront below Wayfarers Hall; the open left ramp reaches the quay behind the foreground gate. Preserve the main water channel and bell docks.',
    },
    'building_veilmourn_mirror_drydock': {
        'source_sha256':'61def7c852073bd01f16aca34660e3cb19233632e53075265559c77438443313',
        'scene_bounds':[1210,570,350,350*1024/1536], 'ground_anchor':[1395,780],
        'grounding':'Long mirror-lined hull and working slip attach to the foreground-right quay along its receding plank direction; the shore-end shelter sits below the gate. Keep the complete cradle inside the cover crop and clear of bottom navigation.',
    },
    'building_veilmourn_salt_counting_house': {
        'source_sha256':'5245eb438fb32cee3d432e09a511602239b2382eabd036ad9aa95ed055b4e19f',
        'scene_bounds':[530,515,245,245*1024/1536], 'ground_anchor':[650,660],
        'grounding':'Twin-roof salt treasury extends the left working quay below Salvage Ledger, with the receiving stair toward the Market and the side pier toward Bell Harbor. Preserve the main tower and existing entrances.',
    },
    'building_veilmourn_mourner_pilot_guild': {
        'source_sha256':'6b056be68c19e4ad943a63ee9ed49697d6f53c8d31db5439f8a0dd3e9dae6888',
        'scene_bounds':[1300,500,270,180], 'ground_anchor':[1450,660],
        'grounding':'Pilot lookout and skiff attach to the right quay below the old oratory plot and behind the foreground Drydock. Preserve the lookout silhouette and its painted information target through later waterfront growth.',
    },
    'building_veilmourn_saltwake_factor': {
        'source_sha256':'08f638373513e882b5d9676c98c652368fb1c91977377d7e97c46406af80b879',
        'scene_bounds':[640,585,280,280*1024/1536], 'ground_anchor':[795,760],
        'grounding':'Broad receiving warehouse extends the salt treasury quay seaward below Bell Harbor; its covered loading bays remain distinct from the older Mistgate plot and leave the buoy channel and bottom controls clear.',
    },
    'building_veilmourn_harpoon_gantry': {
        'source_sha256':'c12da98f94bfc64eb26e654396e87964dd647991b3172cdc928d4f52dfa7f63b',
        'scene_bounds':[55,540,250,250], 'ground_anchor':[180,780], 'reference_inputs':[],
        'grounding':'Harpoon training platform rises from the foreground-left quay below the tower, with pilings joining the waterfront and exposed launchers over the harbor. Keep the complete base above navigation.',
    },
    'building_veilmourn_bell_chain_watch': {
        'source_sha256':'f1d58aab18cb5e1b40fdad3789deeeaa95cc390d75aff8ecb9a77c639dcad620',
        'scene_bounds':[300,510,210,210], 'ground_anchor':[410,705], 'reference_inputs':[],
        'grounding':'Narrow signal post sits on the left working quay behind the Market, leaving its three-bell frame exposed above the arcade and the main tower unobstructed.',
    },
    'building_veilmourn_obituary_vault': {
        'source_sha256':'deffa6c894ad6d79d157c2e27dd81805621227dd9a017877d339767cd47c0d93',
        'scene_bounds':[300,625,255,170], 'ground_anchor':[435,785], 'reference_inputs':[],
        'grounding':'Low memory archive continues the foreground-left trading quay, with stone entry steps facing its approach and pilings meeting the harbor below the Market; leave bottom navigation clear.',
    },
    'building_veilmourn_wake_oratory': {
        'source_sha256':'296dc225d56ed1c226a14b6575e5e0e370c3e8dc5ee8ebf5ea6b07860c74cccf',
        'scene_bounds':[1310,415,270,180], 'ground_anchor':[1440,585], 'reference_inputs':[],
        'grounding':'Open bell-rite pavilion joins the right shoreline behind the Pilot Guild and Drydock; its pitched canopy remains exposed without hovering above the quay or covering commands.',
    },
    'building_veilmourn_mistgate_slip': {
        'source_sha256':'d9931a2a94030e9d5dde2f39d300e0586389c1ec99741f56f9cf9e9f981e6674',
        'scene_bounds':[985,620,270,180], 'ground_anchor':[1115,790], 'reference_inputs':[],
        'grounding':'Mirror-lined boarding slip attaches to the foreground-right quay beside the Drydock, with its walkway directed toward shore and the main channel kept open beside the buoys.',
    },
    'building_veilmourn_black_sail_loft': {
        'source_sha256':'a3709f1f7604457b7fe07e080564bbc6b5685761d88ec1446e5d0607e8bdf52d',
        'scene_bounds':[40,435,320,320*1024/1536], 'ground_anchor':[205,640],
        'reference_inputs':[], 'generation_date':'2026-09-08',
        'grounding':'Sail-making workshop and drying frames extend the foreground-left warehouse quay, behind the Harpoon Gantry. Preserve exposed canvas, the main tower door and the established trading approach.',
    },
    'building_veilmourn_tideglass_chapel': {
        'source_sha256':'27bf61402edaddc7be477b56a36332f863a84c738334b7be67720655e8a6b876',
        'scene_bounds':[565,320,250,250], 'ground_anchor':[690,565],
        'reference_inputs':[], 'generation_date':'2026-09-08',
        'grounding':'Tideglass study chapel joins the inner-left quay beside the main bell tower, behind the Ledger and salt treasury. Its reflective roof and bell remain exposed above the working waterfront; preserve the Bell Harbor gangway and open channel.',
    },
    'building_veilmourn_drowned_map_room': {
        'source_sha256':'9379e7472873d31c86fe378b7d318d5cddd9daf059e676b5f077b448d8fed0ac',
        'scene_bounds':[195,305,250,250*1024/1536], 'ground_anchor':[310,455],
        'generation_date':'2026-09-08',
        'grounding':'Chart house extends the inner-left shore between the original foreground warehouse and main bell tower, behind the sail workshop; keep its navigation roof exposed and the tower doorway clear.',
        'curation':'Inspected ordinary 1280x720 construction and the developed Town at 1280x720, 1920x1080 and 2048x1079; source input/save checks pass. Platform acceptance is recorded separately in the art-repair report.',
    },
    'building_veilmourn_memory_anchor': {
        'source_sha256':'54f74fa81dc09706aeee43ad48cd72c4283f01b971b4ab1635fd2ff27465cb8e',
        'scene_bounds':[540,610,120,180], 'ground_anchor':[605,775],
        'reference_inputs':[], 'generation_date':'2026-09-08',
        'grounding':'Narrow memory-salt anchor stands on the existing left quay in front of the counting house, between the low Vault and seaward Factor warehouse; retain an exposed anchor and its stone approach.',
        'curation':'Inspected ordinary 1280x720 construction and the developed Town at 1280x720, 1920x1080 and 2048x1079; source input/save checks pass. Platform acceptance is recorded separately in the art-repair report.',
    },
    'building_veilmourn_leviathan_sounding': {
        'source_sha256':'4a4bf8919b772d8d85812ce1be4146b99b3298a3e1d4c85a1b7618aef317d8e6',
        'scene_bounds':[745,325,320,320*1024/1536], 'ground_anchor':[940,520],
        'reference_inputs':[], 'generation_date':'2026-09-08',
        'grounding':'Sounding jetty joins the middle-distance right shore through its rightward gangway, behind Bell Harbor; open piling gaps preserve the channel, with paired acoustic horns exposed above the foreground docks.',
        'curation':'Inspected ordinary 1280x720 construction and the developed Town at 1280x720, 1920x1080 and 2048x1079; source input/save checks pass. Platform acceptance is recorded separately in the art-repair report.',
    },
    'building_veilmourn_drowned_admiralty': {
        'source_sha256':'5620b5cee9a562b6bc27c0fa6fd54c818e857c73b8e2ba1324237f2264f9f91b',
        'scene_bounds':[940,210,290,290], 'ground_anchor':[1090,480],
        'reference_inputs':[], 'generation_date':'2026-09-08',
        'grounding':'Admiralty occupies the right shoreline behind Wayfarers Hall; the navigation turret rises above the inn roof while its lower approach joins that established waterfront, clear of the command rail.',
        'curation':'Inspected ordinary 1280x720 construction and the developed Town at 1280x720, 1920x1080 and 2048x1079; source input/save checks pass. Platform acceptance is recorded separately in the art-repair report.',
    },
    'building_veilmourn_memory_rite_court': {
        'source_sha256':'cb03c475af5513a0dc8fcef82b63197cb3ad49db06c06efa107d6b7a76acab8d',
        'scene_bounds':[745,325,320,320*1024/1536], 'ground_anchor':[940,520],
        'reference_inputs':[], 'generation_date':'2026-09-08',
        'grounding':'Developed sounding station retains the same middle-distance jetty site and rightward shore approach, adding an open memory canopy, mirrors and salt rails. A new original painting from the inspected Sounding composition, not a claim of pixel-identical image editing.',
        'curation':'Inspected ordinary 1280x720 Sounding-to-Court replacement at the same site and the developed Town at 1280x720, 1920x1080 and 2048x1079; source input/save checks pass. Fresh original painting, not a pixel-identical base edit. Platform acceptance is recorded separately in the art-repair report.',
    },
}

EMBERCOURT_BRIEFS = {
    'building_muster_yard': {
        'source_sha256':'53c09e19ab13788bd7a2d53677ac1efc7772eabfdd80bc316dd960da472f8ce3',
        'scene_bounds':[215,355,340,340*1024/1536], 'ground_anchor':[390,565],
        'grounding':'Levy hall and fenced practice court stand on the left bank behind the existing stone quay; preserve the lock, shore wall and water approach.',
    },
    'building_wayfarers_hall': {
        'source_sha256':'b0c926b8109558b555017c8229eff0d0483c038c36a9342fe08ed78116eb3d5a',
        'scene_bounds':[1240,490,305,305*1024/1536], 'ground_anchor':[1400,680],
        'grounding':'Hired-roads lodge sits on the right bank beside the fenced training ground, with its porch opening onto the shore path; preserve the main civic hall and lock.',
    },
    'building_market_square': {
        'source_sha256':'0ebb2935cd503cfc188df7c9e217107de96f253004de1c239aaa77692d345974',
        'scene_bounds':[85,530,310,310*1024/1536], 'ground_anchor':[240,713],
        'grounding':'Weigh house and trade arcades extend the foreground-left working quay beside the original riverside house, leaving the lock and main navigation channel open.',
    },
}
for brief in EMBERCOURT_BRIEFS.values():
    brief.update(reference_inputs=[], generation_date='2026-09-08',
                 curation='Inspected original opening, ordinary Market purchase and developed Riverwatch composition at 1280x720. Exact three-resolution input/save and platform acceptance is recorded separately in the art-repair report; other Embercourt catalog layers remain unaccepted.')

EMBERCOURT_GROWTH_BRIEFS = {
    'building_stone_store': {
        'source_sha256':'b2d9736d1fe36502c5eb549bd87f6c0bf6491b0365d9c9eff1802f2708a190f5',
        'scene_bounds':[1270,358,280,280*1024/1536], 'ground_anchor':[1410,537],
        'grounding':'Low masonry reserve stands on the right-bank ground behind Wayfarers Hall, with open storage bays facing the working shore.',
    },
    'building_watch_barracks': {
        'source_sha256':'285de7e09f4c5c559c2505df5fb40f30041bd2775640ddf6ef8fbb56b0fd7ca3',
        'scene_bounds':[215,355,340,340*1024/1536], 'ground_anchor':[390,565],
        'grounding':'Permanent masonry quarters replace the Muster Yard on the same left-bank court and ground anchor; preserve the original quay and canal.',
    },
    'building_bowyer_lodge': {
        'source_sha256':'5218717d3845925529be66aae7d0d9da52b6945ca800d2a48d267b490619f752',
        'scene_bounds':[790,378,270,270*1024/1536], 'ground_anchor':[925,552],
        'grounding':'Bow-making workshop and firing lane stand on the right bank west of the civic hall, above the lock-side shore wall; preserve the main hall entrance.',
    },
    'building_beacon_range': {
        'source_sha256':'dd681cc83638e73a2809f4ad8082d6d08ee0345c20bbfa7d391d39486ccdb0b9',
        'scene_bounds':[790,378,270,270*1024/1536], 'ground_anchor':[925,552],
        'grounding':'Issue loft and signal tower upgrade the Bowyer workshop and firing lane on the identical right-bank site and ground anchor.',
    },
}
for brief in EMBERCOURT_GROWTH_BRIEFS.values():
    brief.update(reference_inputs=[], generation_date='2026-09-08',
                 curation='Inspected normal paid Stone/Watch/Bowyer/Beacon progression and the recorded developed Riverwatch composition at 1280x720. Both upgrade pairs retain their scenic site and ground anchor. Three-resolution input/save and official-platform acceptance is recorded separately in the art-repair report; later catalog paintings remain unaccepted.')
EMBERCOURT_BRIEFS.update(EMBERCOURT_GROWTH_BRIEFS)

EMBERCOURT_SUPPLY_BRIEFS = {
    'building_river_granary_exchange': {
        'source_sha256':'e017aa529e8b362b4fab272990569a06262670208adddee0d504c1930a80c797',
        'scene_bounds':[40,305,270,180], 'ground_anchor':[180,473],
        'grounding':'Bonded grain warehouse joins the left-bank settlement behind the Muster/Watch court; its loading floor meets the existing shore.',
    },
    'building_quartermasters_depot': {
        'source_sha256':'44b3994b3cdee69d1540f4cfa51e881574b33442d2258952c2c85ca32c3746cb',
        'scene_bounds':[400,395,245,245*1024/1536], 'ground_anchor':[510,546],
        'grounding':'Low supply lodge stands by the left lock buttress, behind the Watch court, with its stores facing the quay approach.',
    },
    'building_lantern_archive': {
        'source_sha256':'4e3f3a2c4281add1f8435e594b8346616f077aa34608aa42ff5b2ec34100fbe5',
        'scene_bounds':[0,205,300,200], 'ground_anchor':[180,385],
        'grounding':'Civic records lodge rises on the rear left-bank terrace behind the granary, clear of the command rail; the observatory retains this same site.',
    },
    'building_starseer_annex': {
        'source_sha256':'a276bcce673d063d35ad5505633a9325d021ac49a6f0344775ce23afcaeb01b0',
        'scene_bounds':[0,205,300,200], 'ground_anchor':[180,385],
        'grounding':'Expanded records lodge adds a book wing and observation balcony on the identical rear left-bank Archive terrace; its tower remains visible above the granary and away from controls.',
    },
    'building_citadel_pikehall': {
        'source_sha256':'6e0f60dacccf22ff583401c8dc152adf3087c645f40b85c34b6870b867c08306',
        'scene_bounds':[720,258,275,275*1024/1536], 'ground_anchor':[875,430],
        'grounding':'Low drilled pike hall stands on the right-bank slope behind the bowyer/beacon yard, leaving the main civic entrance and navigation channel intact.',
    },
}
for brief in EMBERCOURT_SUPPLY_BRIEFS.values():
    brief.update(reference_inputs=[], generation_date='2026-09-08',
                 curation='Original text-only paintings from the inspected Riverwatch panorama and normal paid-growth draft. Revised developed composition inspected at 1280x720: observatory on the rear left-bank terrace, with exposed supply roof and right-bank pike hall. Archive and Annex share source-space bounds and ground anchor but are not pixel-identical edits. Final three-resolution paid-growth, input/save and platform acceptance is recorded separately in the art-repair report.')
EMBERCOURT_BRIEFS.update(EMBERCOURT_SUPPLY_BRIEFS)

EMBERCOURT_RIVERWORKS_BRIEFS = {
    'building_embercourt_granary_lock_exchange': {
        'source_sha256':'c260b2b98b021921e2510bec6f9b4486906e6f51b9651e517d14c971375bfbf0',
        'generation_output':'exec-20e63457-9b35-42d0-82f5-f6309010f883.png',
        'scene_bounds':[260,285,260,260*1024/1536], 'ground_anchor':[390,448],
        'grounding':'Bonded grain exchange extends the left-bank settlement behind the Watch court; keep its paired warehouse roofs exposed above the older court and preserve the river approach.',
    },
    'building_embercourt_lockhouse_tally': {
        'source_sha256':'8d1672c35b2c3c9fd4cba6a1eb573a6d104b5c9ca7aede83dda17ad1f86d76ea',
        'generation_output':'exec-ffeed79c-1774-4672-a80d-c0232c698644.png',
        'scene_bounds':[115,680,235,235*1024/1536], 'ground_anchor':[232,821],
        'grounding':'Low tally office stands directly on the foreground-left stone quay, below the Market arcade; its receiving counter faces the working waterfront and leaves navigation controls clear.',
    },
    'building_embercourt_tollstone_weir': {
        'source_sha256':'28745ff79ef6736c550eac717795d7ece2716b100fa94c995f4f7b2688e72b69',
        'generation_output':'exec-3fca8a1c-fafc-4cfe-95af-32e17e7bdea4.png',
        'scene_bounds':[545,470,310,310*1024/1536], 'ground_anchor':[700,660],
        'grounding':'Operational toll sluice continues the existing central weir and masonry abutments, with transparent gate openings revealing the original river rather than a separate painted water tile.',
    },
    'building_embercourt_bargebow_slip': {
        'source_sha256':'c143423cbe307e42515cb68d8882398b3609a8eb21fb7b885dfa8d9ae4e88dfc',
        'generation_output':'exec-05faa746-1269-4b43-9c0f-6c60ac0742a3.png',
        'scene_bounds':[1060,570,330,220], 'ground_anchor':[1225,775],
        'grounding':'Barge cradle projects from the right working quay into the near channel; its shore-end workshop and gangway meet the existing bank below the civic hall, leaving the Wayfarers porch exposed.',
    },
    'building_embercourt_oath_pikehall': {
        'source_sha256':'40bc88d3b7dfd945d60cc67532866e353c8fb642293e7947debed79f5328700e',
        'generation_output':'exec-fd3e1d33-ce0c-4ed3-a899-3eae2024f983.png',
        'scene_bounds':[1340,610,245,245*1024/1536], 'ground_anchor':[1465,760],
        'grounding':'Low oath court extends the foreground-right bank below Wayfarers Hall, with the arcade toward the river. Keep its bell and roof below the command dock, its approach above navigation and the main civic hall unobstructed.',
    },
    'building_embercourt_beacon_writs': {
        'source_sha256':'8d6aab8fc60337147c86f6fa3c89954cb7d17efb5a04b334881d021f178e6c28',
        'generation_output':'exec-6729bdfa-4f23-4cb2-acc0-225b425e9425.png',
        'scene_bounds':[1000,180,260,260*1024/1536], 'ground_anchor':[1120,345],
        'grounding':'Narrow signal-and-charter station stands on the rear right-bank rise above the civic hall, with its small beacon visible against the hillside and clear of the command rail.',
    },
}
for brief in EMBERCOURT_RIVERWORKS_BRIEFS.values():
    brief.update(reference_inputs=[], generation_date='2026-09-08',
                 curation='Original text-only paintings matched to the inspected Riverwatch panorama. Revised developed composition and exact input inspected at 1280x720: grain exchange behind the Watch court, tally office on the left quay, central working weir, right-shore barge slip, foreground-right oath court and rear-bank beacon. Foreground Slip/Lantern pixels retain ownership; the exposed Oath right gable opens its own information. Full paid-growth, three-resolution and official-platform results are recorded separately in the art-repair report; registration alone is not acceptance.')
EMBERCOURT_BRIEFS.update(EMBERCOURT_RIVERWORKS_BRIEFS)

EMBERCOURT_CIVIC_BRIEFS = {
    'building_embercourt_lantern_court': {
        'source_sha256':'f34d056a814a65e2cb46967bf040128680118d6a9ae721d7062e0296add76738',
        'generation_output':'exec-008e04ee-92e3-47b4-bddf-7820ce9d37d4.png',
        'scene_bounds':[1330,665,240,160], 'ground_anchor':[1450,812],
        'grounding':'Low lantern-lit hearing arcade and records wing extend the foreground-right stone bank below the Oath court. Their narrow steps meet the existing quay, with no separate landscape tile; preserve the upper roofs and command controls.',
    },
    'building_embercourt_relief_quay': {
        'source_sha256':'4cffe2a4a5b569b1c17fa4a0d27436688f1214cc6436542d6f02101dceb1d7ca',
        'generation_output':'exec-07981847-b39d-4354-b993-1aa3a0f885e4.png',
        'scene_bounds':[345,630,300,200], 'ground_anchor':[495,819],
        'grounding':'Relief store and timber hoist meet the existing foreground-left stone quay, beside the Tally office. Their attached boarding pontoon and plain supply barge project into the near channel; no painted water or isolated pedestal.',
    },
}
for brief in EMBERCOURT_CIVIC_BRIEFS.values():
    brief.update(reference_inputs=[], generation_date='2026-09-08',
                 curation='Original text-only RGBA paintings matched to the inspected Riverwatch panorama. Source masters and earned/mixed-developed 1280x720 scenes inspected: low hearing arcade on the foreground-right stone bank, relief store/hoist on the left quay with an attached pontoon and plain supply barge. Preserve original alpha, adjacent roofs, channel and command controls. Paid Day-18/19 construction and full non-clock save equality pass; three-resolution and official Linux/Windows acceptance are recorded separately in the art-repair report. Registration alone is not acceptance.')
EMBERCOURT_BRIEFS.update(EMBERCOURT_CIVIC_BRIEFS)

FACTION_BRIEFS = {FACTION: BRIEFS, 'faction_embercourt': EMBERCOURT_BRIEFS}

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def prepare_layers(faction, briefs):
    layers = {}
    for building_id, brief in briefs.items():
        source = ROOT / f'art/towns/source/generated/scene_layers/{faction}/{building_id}.png'
        trimmed = ROOT / f'art/towns/source/trimmed/scene_layers/{faction}/{building_id}.png'
        runtime = ROOT / f'art/towns/runtime/scene_layers/{faction}/{building_id}.png'
        assert digest(source) == brief['source_sha256'], f'Unapproved master: {source}'
        with Image.open(source) as image:
            assert image.mode == 'RGBA'
            source_size = image.size
            bounds = image.getchannel('A').getbbox()
            assert bounds is not None
        trimmed.parent.mkdir(parents=True, exist_ok=True)
        runtime.parent.mkdir(parents=True, exist_ok=True)
        x0,y0,x1,y1 = bounds
        subprocess.run(['convert',str(source),'-crop',f'{x1-x0}x{y1-y0}+{x0}+{y0}','+repage','-strip',str(trimmed)],check=True)
        subprocess.run(['convert',str(trimmed),'-filter','Lanczos','-resize','512x512','-strip','-define','png:color-type=6',str(runtime)],check=True)
        with Image.open(runtime) as image:
            runtime_size = list(image.size)
        x,y,w,h = brief['scene_bounds']
        sw,sh = source_size
        # Exact visible alpha crop in the original scenic coordinate system.
        rect = [(x+w*x0/sw)/1600, (y+h*y0/sh)/900, w*(x1-x0)/sw/1600, h*(y1-y0)/sh/900]
        layers[building_id] = {
            'asset_id':f'{faction}_{building_id}',
            'source_path':'res://'+str(source.relative_to(ROOT)), 'source_sha256':digest(source),
            'source_size':list(source_size), 'trim_box':list(bounds),
            'trimmed_path':'res://'+str(trimmed.relative_to(ROOT)), 'trimmed_sha256':digest(trimmed),
            'runtime_path':'res://'+str(runtime.relative_to(ROOT)), 'runtime_sha256':digest(runtime),
            'runtime_size':runtime_size, 'normalized_rect':rect,
            'ground_anchor':[brief['ground_anchor'][0]/1600,brief['ground_anchor'][1]/900],
            'modulate':[1,1,1,1], 'hit_alpha_threshold':0.25,
            'grounding':brief['grounding'],
            'prompt_path':f'res://art/towns/source/generated/scene_layers/{faction}/{building_id}.prompt.txt',
            'prompt_sha256':digest(source.with_suffix('.prompt.txt')),
            'curation':brief.get('curation','Inspected actual Large08 Bellwake Town composition at 1280x720 and 2048x1079; runtime/input/package validation required separately.'),
        }
        if 'reference_inputs' in brief:
            layers[building_id]['reference_inputs'] = brief['reference_inputs']
        if 'generation_date' in brief:
            layers[building_id]['generation_date'] = brief['generation_date']
        if 'generation_output' in brief:
            layers[building_id]['generation_output'] = brief['generation_output']
    return layers


def merge_layers(payload, prepared):
    """A selected packet cannot erase another faction or an earlier layer."""
    if payload.get('schema_id') != 'town_building_scene_art_v1':
        raise ValueError('Refusing to replace an unknown scene-art manifest')
    result = copy.deepcopy(payload)
    for faction, layers in prepared.items():
        for building, row in layers.items():
            if row.get('asset_id') != faction+'_'+building:
                raise ValueError('Cross-faction scene identity: '+faction+'/'+building)
        result.setdefault('factions', {}).setdefault(faction, {}).update(copy.deepcopy(layers))
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--faction', choices=sorted(FACTION_BRIEFS), action='append',
                        help='Prepare only this faction; preserve all other manifest rows and files')
    args = parser.parse_args()
    manifest = ROOT/'content/town_building_scene_art_manifest.json'
    payload = json.loads(manifest.read_text()) if manifest.is_file() else {
        'schema_id':'town_building_scene_art_v1', 'source_size':[1600,900],
        'source_docs':['docs/generated-full-match-quality-requirements.md','docs/town-integrated-building-progression-requirements.md','docs/generated-full-match-art-repair-report.md'],
        'owner_approval':'2026-09-07: owner approved scene-matched Town layers and resuming full-match quality.',
        'generation':{'tool':'built_in_image_gen','model':'not_exposed','date':'2026-09-07','references':'Original Veilmourn village panorama, original catalog icons and accepted original scene-layer masters; exact inputs are described in each hash-locked prompt. No copyrighted game references.'},
        'processing_tool':'tools/prepare_town_scene_layers.py',
        'processing':'Crop only fully transparent outer margins, preserve generated alpha and aspect, Lanczos downsample to maximum 512px, strip derivative metadata for reproducible bytes; no drawn geometry, recoloring, background replacement or generated panorama substitution.',
        'rights':'Original project-generated art. No copied game pixels, names, protected symbols or third-party source assets.',
        'catalog_icons':'Unchanged; these exact-faction scene layers are not shared catalog replacements.',
        'migration_scope':'Twenty-two Bellwake scene layers cover its authored starting and constructible buildings apart from the embedded Town Hall, including the same-site Sounding/Court upgrade. Source curation and normal growth pass; official-platform evidence is recorded separately in the art-repair report. Other factions remain unaccepted. Text-only rows explicitly record no image inputs and later rows record their generation date.',
        'missing_declared_layer_policy':'validation_failure_no_catalog_or_procedural_fallback',
        'factions':{},
    }
    prepared = {faction: prepare_layers(faction, FACTION_BRIEFS[faction])
                for faction in dict.fromkeys(args.faction or FACTION_BRIEFS)}
    payload = merge_layers(payload, prepared)
    manifest.write_text(json.dumps(payload,indent=2)+'\n')
    print(json.dumps({faction: {k:{'runtime_size':v['runtime_size'],'normalized_rect':v['normalized_rect'],'runtime_sha256':v['runtime_sha256']} for k,v in layers.items()} for faction,layers in prepared.items()},indent=2))

if __name__ == '__main__':
    main()
