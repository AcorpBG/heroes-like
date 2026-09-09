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

VEILMOURN_VARIANT_BRIEFS = {
    "building_veilmourn_wakeglass_chart_house": {
        "source_sha256": "0cb9d6800b7ff996b4f668320248ad5d5d129404ecbe5e6de632227c3dcc9380",
        "generation_output": "exec-77a87ad1-48b7-4b1d-8806-aea74cec5b71.png",
        "scene_bounds": [
            775,
            260,
            350,
            233.33333333333334
        ],
        "ground_anchor": [
            985,
            490
        ],
        "grounding": "Navigator's compass house occupies the inner right shoreline behind the Sounding jetty; its shoreward gangway joins the existing bank, and the compass loft remains exposed above later harbor structures."
    },
    "building_veilmourn_saltwake_eulogy_house": {
        "source_sha256": "9fbac621f71d903fc693982dbde6338d05b0693473e0b6f03168512d86571792",
        "generation_output": "exec-d2438de9-eeba-476f-b924-cdd04b2209d2.png",
        "scene_bounds": [
            15,
            500,
            285,
            190
        ],
        "ground_anchor": [
            175,
            680
        ],
        "grounding": "Memorial house joins the permanent foreground-left quay below the sail-workshop roofs and behind the harpoon landing. Salt-stone steps, tablet veranda and its timber approach share that waterfront level rather than sitting on the old warehouse."
    },
    "building_veilmourn_pale_sounding_last_memory_beacon": {
        "source_sha256": "faeeaf5a04581ff3c68198fbce59fd3bd720c2e46eaa946167c81eba7cea6e1f",
        "generation_output": "exec-6edadf42-9201-4312-b187-a29b917578ad.png",
        "scene_bounds": [
            770,
            655,
            260,
            173.33333333333334
        ],
        "ground_anchor": [
            929,
            820
        ],
        "grounding": "Slender return beacon marks the downstream harbor with a narrow pile-supported mooring and mirror basin; keep open channel around it and its bell exposed above navigation."
    },
    "building_veilmourn_dreamwake_tideglass_oratory": {
        "source_sha256": "9d575417d6c5fdc6709e1291b366dd8466d5dd004300a259a93bd87d71cf1619",
        "generation_output": "exec-89d70eb8-7ebe-4dfc-b0e3-be1a45501445.png",
        "scene_bounds": [
            135,
            630,
            285,
            190
        ],
        "ground_anchor": [
            300,
            810
        ],
        "grounding": "Crescent training pavilion attaches to the permanent foreground-left quay below the harpoon landing. Its left approach meets the existing shore, with basins and roof exposed in sparse and developed towns."
    },
    "building_veilmourn_dreamwake_foganchor_slip": {
        "source_sha256": "13133177e67847775082dbe87f61e918b6d5d79ce5eec10dcdd010d5ac25cd1e",
        "generation_output": "exec-5d1c2f92-c83a-4185-9696-81d4bb9efceb.png",
        "scene_bounds": [
            885,
            455,
            330,
            220
        ],
        "ground_anchor": [
            1090,
            656
        ],
        "grounding": "Anchor-work drydock meets the right-bank working landing through its shoreward gangway; the cradle and folded mantle remain distinct from the older Mirror Drydock and Mistgate Slip, with open piling gaps into the channel."
    }
}
for brief in VEILMOURN_VARIANT_BRIEFS.values():
    brief.update(reference_inputs=[], generation_date='2026-09-09',
                 curation='Original built-in text-only RGBA paintings for the five remaining Veilmourn variant identities. Preserve moonlit wet timber, salt stone, silver-blue roofs and restrained warm lamps, original alpha, the village and all earlier scene layers. Composition, full build/input/save and platform acceptance are recorded separately in the art-repair report; detached fixtures are not earned development.')
BRIEFS.update(VEILMOURN_VARIANT_BRIEFS)

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

EMBERCOURT_LATE_COURT_BRIEFS = {
    'building_embercourt_beacon_court': {
        'source_sha256':'630a3f7b0a7f5274d6089b232a623fdc070b7a205047b09fba7b24c80599a461',
        'generation_output':'exec-533a06fb-665f-4c09-9de6-512ea380d2f5.png',
        'scene_bounds':[1115,340,252,168], 'ground_anchor':[1240,490],
        'grounding':'The low lector arcade extends the right-bank terrace below the Writs beacon and behind the stone store and waterfront halls; shallow steps join the existing settlement without an independent landscape tile.',
    },
    'building_embercourt_drake_sluice': {
        'source_sha256':'d9051dcd3e8c08f37a09f599a21fef871701f694af7b2a1a147670818a5a150d',
        'generation_output':'exec-846ece4d-21d2-4d47-9d83-9710c663fbff.png',
        'scene_bounds':[935,635,300,200], 'ground_anchor':[1090,818],
        'grounding':'Iron-barred beast pens descend from the right-bank lockworks toward the near channel; the attached right-hand landing meets the existing bank and Slip while transparent gate openings retain the original water.',
    },
    'building_embercourt_charter_bastion': {
        'source_sha256':'621cc7e7d0c3d3c9e3177ff62356ebc96f84873cca4f014928488c9e1b0144c2',
        'generation_output':'exec-ea80e3af-f83b-43f4-86b7-5e2c900ad6df.png',
        'scene_bounds':[350,155,360,240], 'ground_anchor':[525,386],
        'grounding':'A broad civic workshop crowns the rear-left settlement between the granary roofs and Citadel hall. Foreground roofs retain depth ownership; the bell tower and colossus assembly arch remain readable above them.',
    },
    'building_embercourt_charter_flame': {
        'source_sha256':'696181065d3000e2896610ed4a192ced892a882850abd97b5cf2d6daca149eea',
        'generation_output':'exec-e3f11bc9-0c63-4e16-a511-91339c56e570.png',
        'scene_bounds':[350,155,360,240], 'ground_anchor':[525,386],
        'grounding':'The fire-lit completion replaces its Bastion in the same rear-left plot and source canvas: pale civic arch, right bell tower, guarded assembly hall and small entrance charter fires. No separate monument or moved town footprint.',
    },
}
for brief in EMBERCOURT_LATE_COURT_BRIEFS.values():
    brief.update(reference_inputs=[], generation_date='2026-09-08',
                 curation='Original text-only RGBA paintings matched to the inspected Riverwatch panorama and faction architecture. Source masters and developed 1280x720 composition/input inspected: Court joins the right terrace, Drake pens meet the waterfront, and Bastion/Flame share the rear civic site. Preserve genuine alpha, the original village/prior layers and deliberate depth. Paid-growth, full-save, three-resolution and official-platform acceptance are recorded separately in the art-repair report; registration alone is not acceptance. Two rejected opaque tool edits of Flame are retained separately as failed generation evidence, not used in runtime art.')
EMBERCOURT_BRIEFS.update(EMBERCOURT_LATE_COURT_BRIEFS)

EMBERCOURT_VARIANT_BRIEFS = {
    "building_signal_citadel": {
        "source_sha256": "0a4e5e7dd2138698b862183ff6a3ca587a17a96bb4a5368ba57fe5c336da9eca",
        "generation_output": "exec-5e8ce9fa-2662-466d-87db-98884a6a5ea5.png",
        "scene_bounds": [
            735,
            205,
            210,
            140
        ],
        "ground_anchor": [
            842,
            340
        ],
        "grounding": "Compact relay station stands on the rear right-bank rise behind the Pikehall, with lens and horn clear of the civic colossus workshop."
    },
    "building_charter_bastion": {
        "source_sha256": "9cf452b6119e9a68d60baaa27266f6a5bd8781b94d5d8fef88a665ce62f12e73",
        "generation_output": "exec-c5e69ade-ae1a-4004-b0bc-d3e033c585d9.png",
        "scene_bounds": [
            420,
            360,
            260,
            173.3333333333
        ],
        "ground_anchor": [
            580,
            525
        ],
        "grounding": "Basin command hall joins the left lock approach in towns without Riverwatch's Quartermaster Depot; keep this headquarters separate from the faction Colossus Bastion and its Flame upgrade."
    },
    "building_embercourt_beaconline_charter_house": {
        "source_sha256": "b86eb52f8f64ffb8bb8b4880168d0c330e9ec4dfb0913f5cb618822ce2cb52e9",
        "generation_output": "exec-b934fc4e-61c7-4297-bacb-30a5a31682ac.png",
        "scene_bounds": [
            205,
            220,
            185,
            123.3333333333
        ],
        "ground_anchor": [
            307,
            335
        ],
        "grounding": "Veteran charter hall joins the rear left-bank terrace between the records lodge and civic workshop. Foreground granary roofs retain depth; the upper charter gable stays exposed away from the command dock."
    },
    "building_embercourt_rainwrit_stormseal_treasury": {
        "source_sha256": "cd8a4aa09cbdf4c0f3b4b4ba3ea815b64541f4ca4298db0d70ba1eef4fd3da3a",
        "generation_output": "exec-cfa1fd83-c1c8-454e-948d-67a99b9a951f.png",
        "scene_bounds": [
            325,
            665,
            250,
            166.6666666667
        ],
        "ground_anchor": [
            465,
            821
        ],
        "grounding": "Raised reserve court stands at the permanent foreground-left stone quay and timber landing, independent of whether Relief Quay has been built. Its adjoining pier follows the base waterfront; the rear Relief roof remains visible when developed."
    },
    "building_embercourt_amberweir_sluiceguard_lock": {
        "source_sha256": "0855f88065dc10099e8bbfa3a960d64680076126b849b020c64de4e9a3a5c400",
        "generation_output": "exec-0285c41c-a570-4492-9ce2-a57308540149.png",
        "scene_bounds": [
            745,
            545,
            265,
            176.6666666667
        ],
        "ground_anchor": [
            900,
            704
        ],
        "grounding": "Fortified lock extends the existing central weir toward the right bank; gate gaps reveal the river and the attached guardwalk meets the working lock route."
    },
    "building_embercourt_amberweir_counterweight_foundry": {
        "source_sha256": "bacc30e6af0d5e26fe5338eea9c0f7d35e9a93700919f3ce199d533ef419a270",
        "generation_output": "exec-f0164211-75bd-4e2a-a8fb-f345ac2220a0.png",
        "scene_bounds": [
            325,
            665,
            250,
            166.6666666667
        ],
        "ground_anchor": [
            465,
            821
        ],
        "grounding": "Water-driven workshop meets the permanent foreground-left stone quay and timber landing even without Relief Quay. Its waterwheel descends from that shore into the channel, while the developed Relief roof remains visible behind it. Rainwrit's same-site treasury cannot coexist in Amberweir."
    }
}
for brief in EMBERCOURT_VARIANT_BRIEFS.values():
    brief.update(reference_inputs=[], generation_date='2026-09-09',
                 curation='Original built-in text-only RGBA paintings for all six remaining Embercourt variant identities. Preserve original alpha, sunset light, cream river masonry, red tile and wet timber, with all earlier layers unchanged. Generic and faction Bastions remain distinct original paintings and sites. Actual composition, full build/input/save and platform evidence is recorded in the art-repair report; detached fixtures are not earned progression.')
EMBERCOURT_BRIEFS.update(EMBERCOURT_VARIANT_BRIEFS)

MIRECLAW_BRIEFS = {
    'building_blackbranch_den': {
        'source_sha256':'d0c8a1df8391f08940483ee55b521775c51d64b89e9a4999a33fc493d27ca0b3',
        'scene_bounds':[415,375,280,280*1024/1536], 'ground_anchor':[610,544],
        'generation_output':'exec-50bdfb12-3f05-49a7-aca8-47673fbb874d.png',
        'grounding':'Low connected reed chambers extend the middle-left shore behind the ferry landing. Their front-right stair reaches the existing boardwalk; wet short pilings descend into the marsh without a separate terrain disk.',
    },
    'building_wayfarers_hall': {
        'source_sha256':'3d315adc84489fe3a4a5e35310194263c9644d060f9de1d00a51904a9fb36a59',
        'scene_bounds':[1120,340,305,305*1024/1536], 'ground_anchor':[1250,530],
        'generation_output':'exec-c06f2362-c3dc-4dba-8ea1-283780a15022.png',
        'grounding':'Long reed-roofed hiring hall sits behind the right communal fire platform. Its front-left stair approaches the existing causeway, retaining the main hall and fire as distinct landmarks.',
    },
    'building_market_square': {
        'source_sha256':'c6dac6c22a564073798bc0e1e34e1701ea4d6a4590d894f1e3cc8d68f3713eeb',
        'scene_bounds':[410,530,300,200], 'ground_anchor':[645,710],
        'generation_output':'exec-23b1bc97-61b0-4235-b754-1c68a43b739f.png',
        'grounding':'Low reed-and-hide trade counters continue the left working landing below the Den. The short front-right loading stair faces the ferry approach; open piling gaps retain the original marsh below.',
    },
}
for brief in MIRECLAW_BRIEFS.values():
    brief.update(reference_inputs=[], generation_date='2026-09-09',
                 curation='Original built-in text-only paintings described from the inspected Duskfen village. Preserve generated alpha, camera, warm upper-left backlight and wet reed/timber materials. Actual composition, paid growth, input/save and platform acceptance are recorded separately in the art-repair report; registration alone is not acceptance.')


MIRECLAW_GROWTH_BRIEFS = {
    'building_mire_pens': {
        'source_sha256':'f1c3cd062158d9435741a601e4d8ad50bce1da13df05aa32e46158737f6cee69',
        'generation_output':'exec-ab2f3467-9a2b-48d6-af9c-443e97892d42.png',
        'scene_bounds':[390,245,290,193.33333333333334], 'ground_anchor':[626,424],
        'grounding':"Rear-left handler platforms join the reed shore behind the original Den; the exposed roof remains separate from the main hall and the foreground Den.",
    },
    'building_reed_warren': {
        'source_sha256':'6327d590b233fef5b0d8f5cd441ccc2a6b0c4713dd0692cc14c251950df46bd7',
        'generation_output':'exec-7e6c70b6-c832-4035-af76-0b8339b906d6.png',
        'scene_bounds':[415,375,280,186.66666666666666], 'ground_anchor':[610,544],
        'grounding':"The larger nested Warren replaces the original Den in its exact source-space site and grounding; saved predecessor identity is retained.",
    },
    'building_slingers_post': {
        'source_sha256':'1b48e2827f8809fb0993f37102c8b7e6b0f2cd8033cf0ab5707f66f6a10ee236',
        'generation_output':'exec-098ab0b7-6b4c-4873-8c13-578bbe1ce2d5.png',
        'scene_bounds':[1030,238,235,156.66666666666666], 'ground_anchor':[1075,382],
        'grounding':"Low firing deck follows the right rear shoreline above the Wayfarers Hall, leaving the central hall and fire approach intact.",
    },
    'building_rot_warren': {
        'source_sha256':'02766314a44fab62235eee9057f511db4543f0071ad3b4ac44be94d28b2a7558',
        'generation_output':'exec-05a0b25a-a02b-4f0c-97eb-f4020d4aa4d3.png',
        'scene_bounds':[1030,238,235,156.66666666666666], 'ground_anchor':[1075,382],
        'grounding':"Expanded gear shelters replace the Slingers Post in the exact same rear-right site, not a second disconnected plot.",
    },
    'building_fenscale_pens': {
        'source_sha256':'e9267ea805cd05b0424801e4e8727b758cc6c320300a2604a06ac5b2c3f820f5',
        'generation_output':'exec-ec72f739-3124-4b75-8855-f07329b45bd0.png',
        'scene_bounds':[390,245,290,193.33333333333334], 'ground_anchor':[626,424],
        'grounding':"Bogplate gates replace the earlier Mire Pens in the same footprint and ground anchor; no moved enclosure or separate new yard.",
    },
    'building_war_drum_circle': {
        'source_sha256':'ab9870e32eef792afafbd66c03b81ceb077bdcaaf63253d3d9271e6a505962d1',
        'generation_output':'exec-8cee1801-0b61-4c71-86bc-d27bfa01215a.png',
        'scene_bounds':[1070,550,240,160], 'ground_anchor':[1138,691],
        'grounding':"The low drum platform joins the right-hand shore below the communal fire and hiring hall; its steps face the existing main causeway.",
    },
    'building_lantern_archive': {
        'source_sha256':'ac6c3026a9921e6aee275bceece530b30ee6bd50c7f152af07fb7b78b92bb2e4',
        'generation_output':'exec-acc93383-863b-4666-a296-2ffe899ba0c3.png',
        'scene_bounds':[245,405,220,146.66666666666666], 'ground_anchor':[411,540],
        'grounding':"The compact records house occupies the left shore beside the Den and above the Market approach, set behind their nearer roofs.",
    },
    'building_starseer_annex': {
        'source_sha256':'299f709e6a115507f958d4325e71c51440a29225c7a3d8a5f31f0247e831193f',
        'generation_output':'exec-b36880fa-ed8c-4c8d-b247-351fe63f340e.png',
        'scene_bounds':[245,405,220,146.66666666666666], 'ground_anchor':[411,540],
        'grounding':"The sky-reader alcove grows out of the Archive in the identical source site and anchor; its low silhouette leaves the backdrop landmark clear.",
    },
    'building_gorefen_ring': {
        'source_sha256':'82733f8ba39aee397533186bf0199c7ca510d1c4be38f82df177ed345a57cbdf',
        'generation_output':'exec-8d89afaf-d461-45c3-8b2d-716869426a9c.png',
        'scene_bounds':[270,650,255,170], 'ground_anchor':[473,804],
        'grounding':"The low pack ring continues the dark foreground-left landing behind its nearer edge, retaining the original main bridge and central water lane.",
    },
}
for brief in MIRECLAW_GROWTH_BRIEFS.values():
    brief.update(reference_inputs=[], generation_date='2026-09-09',
                 curation='Original built-in text-only RGBA paintings for the owner-directed nine-building Duskfen batch. Preserve generated alpha, wet timber/reed materials, sunset backlight and shared upgrade sites. Masters inspected together; batch composition, ordinary progression, input/save and platform evidence are recorded separately in the art-repair report. Registration is not acceptance.')
MIRECLAW_BRIEFS.update(MIRECLAW_GROWTH_BRIEFS)

MIRECLAW_FACTION_BRIEFS = {
    "building_mireclaw_reed_toll": {
        "source_sha256": "c046c4651c4657163192fdb5418a3beeb94fd51ce9b9f01c25c50f355395057e",
        "generation_output": "exec-3cd953b4-9ec1-40f0-8ef2-f6a163f3fb73.png",
        "scene_bounds": [
            680,
            445,
            165,
            110
        ],
        "ground_anchor": [
            807,
            539
        ],
        "grounding": "Compact toll approach follows the middle-left causeway beside the market/Den routes, keeping the central main-hall entrance exposed."
    },
    "building_mireclaw_blackbranch_den": {
        "source_sha256": "9ececf80b90e06aef88484f6e194b34752d9ed58a28a6932dac1455acde1c778",
        "generation_output": "exec-5efe0086-f667-407e-9aaa-a3bb030e6b67.png",
        "scene_bounds": [
            240,
            290,
            205,
            136.66666666666666
        ],
        "ground_anchor": [
            402,
            413
        ],
        "grounding": "The faction snare dens occupy the rear-left marsh shore behind the Archive and existing Pens, distinct from the generic Den plot."
    },
    "building_mireclaw_silt_watch": {
        "source_sha256": "cf4d8586fb8df0a3cdfef245e6057969a9a6cd5aa089d8eff6e66840770cc4e8",
        "generation_output": "exec-c1197b26-7e91-434e-ad90-043ec32b2ef1.png",
        "scene_bounds": [
            830,
            500,
            180,
            120
        ],
        "ground_anchor": [
            885,
            609
        ],
        "grounding": "The lookout stands on the central causeway landing below the main hall, with its stair reaching the bridge approach. Its roof and body remain outside the command dock."
    },
    "building_mireclaw_war_drum_circle": {
        "source_sha256": "537ff316f227fb65a8286dab13119027dfd74835f9263d6d9f56538033769f4a",
        "generation_output": "exec-e28c3874-7fb5-4c53-ba36-7da4b941f9d9.png",
        "scene_bounds": [
            1375,
            605,
            190,
            126.6666666667
        ],
        "ground_anchor": [
            1432,
            716
        ],
        "grounding": "The mudglass rehearsal deck follows the far-right near shore, separate from the earlier communal War Drum Circle."
    },
    "building_mireclaw_floodtide_forge": {
        "source_sha256": "953852dc044568ff497a0835df172dfd6d652308da8f4a534657e1299d976593",
        "generation_output": "exec-e5ea0ba1-ac59-462e-9613-33e8eef21733.png",
        "scene_bounds": [
            1410,
            420,
            180,
            120
        ],
        "ground_anchor": [
            1485,
            529
        ],
        "grounding": "The flood-quenching forge occupies the easternmost working shore beside the hiring hall, without moving older paintings."
    },
    "building_mireclaw_chainboom_ferry": {
        "source_sha256": "309d212285cce22ed56ee93b01544086bebadf4dad9790630735f8fe4f475385",
        "generation_output": "exec-b4122dc8-047a-467e-868c-73d03c11e5af.png",
        "scene_bounds": [
            1110,
            685,
            230,
            153.33333333333334
        ],
        "ground_anchor": [
            1166,
            819
        ],
        "grounding": "The attached ferry boards from the lower-right waterfront and leaves the central bridge lane readable."
    },
    "building_mireclaw_bog_oracle_nest": {
        "source_sha256": "3ad91b62a53bca660c00d09e65e6610f011e8f1145727b11c628d51fc47a33e3",
        "generation_output": "exec-0bb09f3b-6caf-4d91-b86e-19a3af10d5ef.png",
        "scene_bounds": [
            970,
            555,
            155,
            103.33333333333333
        ],
        "ground_anchor": [
            1084,
            645
        ],
        "grounding": "The oracle alcove joins the right bridge landing between Silt Watch and the communal drum quay, with visible stairs and a short piling base. The command dock and hiring hall cannot conceal it."
    },
    "building_mireclaw_boneboom_palisade": {
        "source_sha256": "d95a14c73f90dbfd1375dc8ebebd4cb9165adbc12899fc05f7acd2aaef422c3b",
        "generation_output": "exec-9f5dd28d-f111-459c-bec5-817be1c5face.png",
        "scene_bounds": [
            1335,
            680,
            245,
            163.3333333333
        ],
        "ground_anchor": [
            1404,
            825
        ],
        "grounding": "The short irregular boom follows the near-right settlement edge and joins the ferry/drum approaches."
    },
    "building_mireclaw_sporewake_shrine": {
        "source_sha256": "1164ea8198563b20b0aed13496a6b1adff9f84ac04986d8ffed1e05f37740090",
        "generation_output": "exec-56bfea45-c9bf-4d98-bfaa-72d57be02d5c.png",
        "scene_bounds": [
            1260,
            520,
            195,
            130
        ],
        "ground_anchor": [
            1407,
            636
        ],
        "grounding": "The shrine occupies the east waterfront below the hiring hall and beside the forge, behind the nearer drum decks."
    },
    "building_mireclaw_fenbell_hunt_lodge": {
        "source_sha256": "77fe84973b97216cedd1f5794b080fbc3e3aa9488703c868f55520415dc67510",
        "generation_output": "exec-922e0fdf-7812-42a0-9429-fff09b4b84f6.png",
        "scene_bounds": [
            215,
            545,
            210,
            140
        ],
        "ground_anchor": [
            385,
            674
        ],
        "grounding": "The hunt lodge joins the left shore below the Archive and beside the Market, behind the nearer pack enclosure."
    },
    "building_mireclaw_nightglass_dominion": {
        "source_sha256": "dba7fb4f10bb71dd468e02370e27b0bdf4d5fc98c267616f4bec8bcf64493ff7",
        "generation_output": "exec-f5d0d97b-3957-440e-9abf-f8a304260315.png",
        "scene_bounds": [
            825,
            670,
            265,
            176.6666666667
        ],
        "ground_anchor": [
            916,
            826
        ],
        "grounding": "The low command house sits on the near-right landing beside the central bridge, keeping the original main hall distinct."
    },
    "building_mireclaw_antler_pit": {
        "source_sha256": "b1e90dfcb9c8f217aa3860e158daebac2815c7d1303f475cb85cd5b319ddb5ff",
        "generation_output": "exec-fcb9ee28-4601-4ea4-9b0e-219a2544723d.png",
        "scene_bounds": [
            510,
            695,
            255,
            170
        ],
        "ground_anchor": [
            715,
            850
        ],
        "grounding": "The shallow apex enclosure extends the left foreground landing beside the earlier pack ring."
    },
    "building_mireclaw_oathmire_court": {
        "source_sha256": "b7f9907ffc6d147a8831ea11ba7632fc53c3fe4e9d49528fad02f796ef63580b",
        "generation_output": "exec-316372ce-827b-4ed6-aaf5-81fef5cabe2c.png",
        "scene_bounds": [
            825,
            670,
            265,
            176.6666666667
        ],
        "ground_anchor": [
            916,
            826
        ],
        "grounding": "The expanded council gallery replaces the Dominion in its exact source-space site and ground anchor; the saved predecessor remains intact."
    }
}
for brief in MIRECLAW_FACTION_BRIEFS.values():
    brief.update(reference_inputs=[], generation_date='2026-09-09',
                 curation='Original built-in text-only RGBA paintings for the complete Duskfen faction-chain batch. Preserve generated alpha, wet timber/reed palette, camera and exact Dominion/Court site. The first referenced Court edit had an opaque checkerboard and was rejected; the accepted Court uses the documented original-house text description. Actual paid progression, visual/input/save and platform acceptance are separate in the art-repair report.')
MIRECLAW_BRIEFS.update(MIRECLAW_FACTION_BRIEFS)


MIRECLAW_VARIANT_BRIEFS = {
    'building_floodtide_forge': {
        'source_sha256':'af73753d4ef8ca189bc6b28d46111b4a7fd8561dbb4edecf91cab0c21becff59',
        'generation_output':'exec-3209afb2-f11b-42e0-8ba5-a429090c268c.png',
        'scene_bounds':[670,250,190,126.6666666667], 'ground_anchor':[803,367],
        'grounding':"Repair forge joins the rear-left settlement shore between Fenscale Pens and the main hall; it is a separate authored workshop from the eastern faction armor forge.",
    },
    'building_nightglass_dominion': {
        'source_sha256':'49f8dcb1f776b1b80977c92625188415a38f377de18d7a0792a0cea822e7c253',
        'generation_output':'exec-100efd28-c9be-44b4-9788-080fc597db55.png',
        'scene_bounds':[740,615,190,126.6666666667], 'ground_anchor':[867,730],
        'grounding':"Open signal ring meets the near central causeway, separate from the nearer Nightglass command house and its Court upgrade.",
    },
    'building_smugglers_flotilla': {
        'source_sha256':'b270b7e5fa0df5b64217b374f406f69d819e1d16b38097a75dbbfd51990411b5',
        'generation_output':'exec-643f188a-3f54-4db0-a58b-51d045c75fbf.png',
        'scene_bounds':[1070,550,240,160], 'ground_anchor':[1138,691],
        'grounding':"Hidden boat slip joins the right communal landing in Reedbarrow, whose catalog has no generic War Drum Circle at this site. Its boats retain transparent water gaps.",
    },
    'building_mireclaw_hollowreed_moonwax_ossuary': {
        'source_sha256':'b464382f709d6098adbf6973fde06391df8f32bd3c29a92f7742311b1485deff',
        'generation_output':'exec-5c314b4a-48b3-42b9-943a-8c7a96b4ad85.png',
        'scene_bounds':[215,205,185,123.3333333333], 'ground_anchor':[345,318],
        'grounding':"Moonwax storehouse joins the far-left rear shoreline behind the faction Den. Only Hollowreed offers this exact ossuary.",
    },
    'building_mireclaw_moonbite_votive_drum_court': {
        'source_sha256':'2d24560316d9d502b5890d6a9d5e85bfa85618366a8f69f5d4b5550ad15e46f4',
        'generation_output':'exec-c2632dbe-6693-42e9-ba36-dd3a09d8ea52.png',
        'scene_bounds':[215,205,185,123.3333333333], 'ground_anchor':[345,318],
        'grounding':"Low crescent training theater joins Moonbite's far-left rear shoreline behind the faction Den. Hollowreed's same-location ossuary is not in Moonbite's catalog.",
    },
    'building_mireclaw_moonbite_mirehorn_chain_pen': {
        'source_sha256':'cd3d17bb06b6e62c48cbb9b32aabd0e4ec52f79df636a251042cde8903da6e01',
        'generation_output':'exec-38f0ddf2-6954-497f-b9bf-8ef06d5e7c7e.png',
        'scene_bounds':[695,550,155,103.3333333333], 'ground_anchor':[802,642],
        'grounding':"Compact Mirehorn enclosure joins the left causeway landing between the Toll approach and nearer signal ring. It remains exposed outside the right command dock and distinct from the foreground apex Antler Pit.",
    },
}
for brief in MIRECLAW_VARIANT_BRIEFS.values():
    brief.update(reference_inputs=[], generation_date='2026-09-09',
                 curation='Original built-in text-only RGBA paintings for the six remaining Mireclaw variant identities. Masters inspected; preserve alpha, wet timber/reed architecture, sunset light and all earlier layers. Distinct generic/faction names remain separate art and gameplay identities. Actual seven-town composition, paid-authority fixtures, input/save and platform evidence are recorded separately in the art-repair report; fixtures are not earned full-match progression.')
MIRECLAW_BRIEFS.update(MIRECLAW_VARIANT_BRIEFS)


SUNVAULT_BRIEFS = json.loads((ROOT/'art/towns/source/generated/scene_layers/faction_sunvault/scene_briefs.json').read_text())
THORNWAKE_BRIEFS = json.loads((ROOT/'art/towns/source/generated/scene_layers/faction_thornwake/scene_briefs.json').read_text())
FACTION_BRIEFS = {FACTION: BRIEFS, 'faction_embercourt': EMBERCOURT_BRIEFS, 'faction_mireclaw': MIRECLAW_BRIEFS,
                 'faction_sunvault': SUNVAULT_BRIEFS, 'faction_thornwake': THORNWAKE_BRIEFS}

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
