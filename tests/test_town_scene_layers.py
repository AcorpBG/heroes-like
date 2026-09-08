"""Strict original-raster provenance and exact scene-layer geometry checks."""
import copy
import hashlib
import json
from pathlib import Path
import unittest

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / 'content/town_building_scene_art_manifest.json'

def validate_scene_layers(payload=None):
    errors = []
    if payload is None:
        if not MANIFEST.is_file():
            return ['Missing authoritative Town scene-art manifest']
        payload = json.loads(MANIFEST.read_text())
    def require(condition, message):
        if not condition:
            errors.append(message)
    require(payload.get('schema_id')=='town_building_scene_art_v1', 'Invalid Town scene-art schema')
    require(payload.get('missing_declared_layer_policy')=='validation_failure_no_catalog_or_procedural_fallback', 'Scene layers must not silently fall back')
    require(bool(payload.get('owner_approval')) and bool(payload.get('rights')), 'Missing art approval/rights')
    require(payload.get('generation',{}).get('tool')=='built_in_image_gen', 'Missing generated art provenance')
    factions = payload.get('factions', {})
    bellwake = next(town for town in json.loads((ROOT/'content/towns.json').read_text())['items'] if town['id']=='town_veilmourn_bellwake_harbor')
    required_bellwake = set(bellwake['starting_building_ids'] + bellwake['buildable_building_ids']) - {'building_town_hall'}
    require(required_bellwake.issubset(factions.get('faction_veilmourn',{})), 'Missing constructible Bellwake scene mapping: '+', '.join(sorted(required_bellwake-set(factions.get('faction_veilmourn',{})))))
    veilmourn = factions.get('faction_veilmourn',{})
    sounding = veilmourn.get('building_veilmourn_leviathan_sounding',{})
    court = veilmourn.get('building_veilmourn_memory_rite_court',{})
    if sounding and court:
        # Alpha crops may differ, but both full master canvases must occupy the
        # same scenic site. Compare reconstructed pre-crop bounds, not pixels.
        def site(row):
            rect, crop, size = row.get('normalized_rect',[]), row.get('trim_box',[]), row.get('source_size',[])
            if len(rect)!=4 or len(crop)!=4 or len(size)!=2 or crop[2]<=crop[0] or crop[3]<=crop[1]:
                return None
            width = rect[2]*1600*size[0]/(crop[2]-crop[0])
            height = rect[3]*900*size[1]/(crop[3]-crop[1])
            return [rect[0]*1600-width*crop[0]/size[0],rect[1]*900-height*crop[1]/size[1],width,height]
        first, upgrade = site(sounding), site(court)
        require(first is not None and upgrade is not None and all(abs(a-b)<0.001 for a,b in zip(first,upgrade)), 'Memory-Rite Court moved the Sounding scenic site')
        require(sounding.get('ground_anchor')==court.get('ground_anchor'), 'Memory-Rite Court moved the Sounding ground anchor')
    require(set(factions.get('faction_veilmourn',{})) >= {'building_veilmourn_black_sail_loft','building_veilmourn_tideglass_chapel'}, 'Missing accepted Bellwake rigging/magic scene mapping')
    require(set(factions.get('faction_veilmourn',{})) >= {'building_veilmourn_harpoon_gantry','building_veilmourn_bell_chain_watch','building_veilmourn_obituary_vault','building_veilmourn_wake_oratory','building_veilmourn_mistgate_slip'}, 'Missing accepted Bellwake defense/memory scene mapping')
    require(set(factions.get('faction_veilmourn',{})) >= {'building_veilmourn_salt_counting_house','building_veilmourn_mourner_pilot_guild','building_veilmourn_saltwake_factor'}, 'Missing accepted Bellwake salt/pilot scene mapping')
    require(set(factions.get('faction_veilmourn',{})) >= {'building_veilmourn_bell_harbor','building_wayfarers_hall','building_market_square','building_veilmourn_fog_signal_buoys','building_veilmourn_salvage_ledger','building_veilmourn_ransom_exchange','building_veilmourn_mirror_drydock'}, 'Missing accepted Bellwake scene mapping')
    paths = set()
    hashes = set()
    catalogs = json.loads((ROOT/'content/town_building_scene_layouts.json').read_text())['factions']
    for faction, layers in factions.items():
        require(faction in catalogs, 'Unknown scene faction: '+faction)
        known = {id for plot in catalogs.get(faction,{}).get('plots',[]) for id in plot['building_ids']}
        for building, row in layers.items():
            label = faction+'/'+building
            require(building in known, 'Unknown scene building: '+label)
            require(row.get('asset_id')==faction+'_'+building, 'Mismatched scene identity: '+label)
            rect = row.get('normalized_rect',[])
            valid_rect = isinstance(rect,list) and len(rect)==4 and all(isinstance(n,(int,float)) for n in rect) and rect[2]>0 and rect[3]>0 and min(rect)>=0 and rect[0]+rect[2]<=1 and rect[1]+rect[3]<=1
            require(valid_rect, 'Invalid normalized scene bounds: '+label)
            anchor = row.get('ground_anchor',[])
            require(len(anchor)==2 and all(isinstance(n,(int,float)) and 0<=n<=1 for n in anchor), 'Invalid ground anchor: '+label)
            require(row.get('modulate')==[1,1,1,1], 'Scene painting must retain authored lighting: '+label)
            require(row.get('hit_alpha_threshold')==0.25, 'Missing painted-pixel hit authority: '+label)
            for kind in ('source','trimmed','runtime'):
                resource = row.get(kind+'_path','')
                path = ROOT / resource.removeprefix('res://')
                expected = f'art/towns/runtime/scene_layers/{label}.png' if kind=='runtime' else f'art/towns/source/{"generated" if kind=="source" else "trimmed"}/scene_layers/{label}.png'
                require(resource=='res://'+expected, 'Wrong exact '+kind+' path: '+label)
                if not path.is_file():
                    errors.append('Missing '+kind+' scene raster: '+label)
                    continue
                require(hashlib.sha256(path.read_bytes()).hexdigest()==row.get(kind+'_sha256'), 'Changed '+kind+' scene raster: '+label)
                with Image.open(path) as image:
                    require(image.mode=='RGBA', 'Non-RGBA scene raster: '+label)
                    if kind=='runtime':
                        require(list(image.size)==row.get('runtime_size'), 'Wrong runtime dimensions: '+label)
                        require(max(image.size)<=512, 'Oversized scene layer: '+label)
                        if valid_rect:
                            require(abs((rect[2]*1600)/(rect[3]*900)-image.width/image.height)<0.005, 'Stretched/square scene layer: '+label)
                        alpha = image.getchannel('A')
                        require(alpha.getextrema()[0]==0 and alpha.getextrema()[1]>=250, 'No true transparency or solid painted body: '+label)
                        imported = path.with_suffix('.png.import')
                        require(imported.is_file() and 'mipmaps/generate=true' in imported.read_text(), 'Missing imported scene mipmaps: '+label)
            require(row.get('runtime_path') not in paths, 'Shared scene fallback path: '+label)
            require(row.get('runtime_sha256') not in hashes, 'Duplicate scene painting: '+label)
            paths.add(row.get('runtime_path')); hashes.add(row.get('runtime_sha256'))
            prompt = ROOT / row.get('prompt_path','').removeprefix('res://')
            prompt_text = prompt.read_text() if prompt.is_file() else ''
            text_only = row.get('reference_inputs') == []
            require(bool(prompt_text.strip()) and ('image 1' in prompt_text.lower() or (text_only and 'transparent-background rgba png game sprite' in prompt_text.lower())), 'Missing exact generation prompt: '+label)
            if prompt.is_file():
                require(hashlib.sha256(prompt.read_bytes()).hexdigest()==row.get('prompt_sha256'), 'Changed generation prompt: '+label)
    return errors

class TownSceneLayersTests(unittest.TestCase):
    def setUp(self):
        self.payload = json.loads(MANIFEST.read_text())
    def test_production_manifest_and_rasters(self):
        self.assertEqual(validate_scene_layers(), [])
    def test_every_constructible_bellwake_mapping_is_required(self):
        town = next(t for t in json.loads((ROOT/'content/towns.json').read_text())['items'] if t['id']=='town_veilmourn_bellwake_harbor')
        for building in set(town['starting_building_ids']+town['buildable_building_ids'])-{'building_town_hall'}:
            with self.subTest(building=building):
                payload=copy.deepcopy(self.payload)
                payload['factions']['faction_veilmourn'].pop(building, None)
                self.assertTrue(any(e.startswith('Missing constructible Bellwake scene mapping:') and building in e for e in validate_scene_layers(payload)))
    def test_upgrade_site_relocation_is_rejected(self):
        veilmourn=self.payload['factions']['faction_veilmourn']
        # The production check requires both actual paintings. This synthetic
        # row isolates the negative geometry control even before art import.
        base=copy.deepcopy(veilmourn.get('building_veilmourn_leviathan_sounding',veilmourn['building_wayfarers_hall']))
        veilmourn['building_veilmourn_leviathan_sounding']=base
        veilmourn['building_veilmourn_memory_rite_court']=copy.deepcopy(base)
        veilmourn['building_veilmourn_memory_rite_court']['normalized_rect'][0]+=0.01
        self.assertIn('Memory-Rite Court moved the Sounding scenic site',validate_scene_layers(self.payload))
    def test_upgrade_ground_anchor_change_is_rejected(self):
        veilmourn=self.payload['factions']['faction_veilmourn']
        base=copy.deepcopy(veilmourn.get('building_veilmourn_leviathan_sounding',veilmourn['building_wayfarers_hall']))
        veilmourn['building_veilmourn_leviathan_sounding']=base
        veilmourn['building_veilmourn_memory_rite_court']=copy.deepcopy(base)
        veilmourn['building_veilmourn_memory_rite_court']['ground_anchor'][1]+=0.01
        self.assertIn('Memory-Rite Court moved the Sounding ground anchor',validate_scene_layers(self.payload))
    def test_missing_mapping_is_rejected(self):
        del self.payload['factions']['faction_veilmourn']['building_wayfarers_hall']
        self.assertIn('Missing accepted Bellwake scene mapping', validate_scene_layers(self.payload))
    def test_missing_constructible_market_mapping_is_rejected(self):
        del self.payload['factions']['faction_veilmourn']['building_market_square']
        self.assertIn('Missing accepted Bellwake scene mapping', validate_scene_layers(self.payload))
    def test_changed_prompt_is_rejected(self):
        self.payload['factions']['faction_veilmourn']['building_market_square']['prompt_sha256']='0'*64
        self.assertTrue(any('Changed generation prompt' in e for e in validate_scene_layers(self.payload)))
    def test_missing_harbor_growth_mappings_are_rejected(self):
        for building in ('building_veilmourn_fog_signal_buoys','building_veilmourn_salvage_ledger'):
            with self.subTest(building=building):
                payload=copy.deepcopy(self.payload)
                del payload['factions']['faction_veilmourn'][building]
                self.assertIn('Missing accepted Bellwake scene mapping',validate_scene_layers(payload))
    def test_catalog_icon_cannot_impersonate_scene_layer(self):
        self.payload['factions']['faction_veilmourn']['building_wayfarers_hall']['runtime_path']='res://art/towns/runtime/buildings/building_wayfarers_hall.png'
        self.assertTrue(any('Wrong exact runtime path' in e for e in validate_scene_layers(self.payload)))
    def test_missing_exchange_growth_mappings_are_rejected(self):
        for building in ('building_veilmourn_ransom_exchange','building_veilmourn_mirror_drydock'):
            with self.subTest(building=building):
                payload=copy.deepcopy(self.payload)
                payload['factions']['faction_veilmourn'].pop(building, None)
                self.assertIn('Missing accepted Bellwake scene mapping',validate_scene_layers(payload))
    def test_missing_raster_is_rejected(self):
        self.payload['factions']['faction_veilmourn']['building_wayfarers_hall']['runtime_path']='res://missing-town-scene.png'
        self.assertTrue(any('Missing runtime scene raster' in e for e in validate_scene_layers(self.payload)))
    def test_missing_salt_pilot_mappings_are_rejected(self):
        for building in ('building_veilmourn_salt_counting_house','building_veilmourn_mourner_pilot_guild','building_veilmourn_saltwake_factor'):
            with self.subTest(building=building):
                payload=copy.deepcopy(self.payload)
                payload['factions']['faction_veilmourn'].pop(building, None)
                self.assertIn('Missing accepted Bellwake salt/pilot scene mapping',validate_scene_layers(payload))
    def test_missing_defense_memory_mappings_are_rejected(self):
        for building in ('building_veilmourn_harpoon_gantry','building_veilmourn_bell_chain_watch','building_veilmourn_obituary_vault','building_veilmourn_wake_oratory','building_veilmourn_mistgate_slip'):
            with self.subTest(building=building):
                payload=copy.deepcopy(self.payload)
                payload['factions']['faction_veilmourn'].pop(building, None)
                self.assertIn('Missing accepted Bellwake defense/memory scene mapping',validate_scene_layers(payload))
    def test_text_only_prompt_requires_explicit_no_image_inputs(self):
        row=self.payload['factions']['faction_veilmourn']['building_veilmourn_obituary_vault']
        row.pop('reference_inputs',None)
        self.assertTrue(any('Missing exact generation prompt' in e for e in validate_scene_layers(self.payload)))
    def test_missing_rigging_magic_mappings_are_rejected(self):
        for building in ('building_veilmourn_black_sail_loft','building_veilmourn_tideglass_chapel'):
            with self.subTest(building=building):
                payload=copy.deepcopy(self.payload)
                payload['factions']['faction_veilmourn'].pop(building, None)
                self.assertIn('Missing accepted Bellwake rigging/magic scene mapping',validate_scene_layers(payload))
    def test_square_stretch_is_rejected(self):
        self.payload['factions']['faction_veilmourn']['building_wayfarers_hall']['normalized_rect']=[0.5,0.3,0.18,0.32]
        self.assertTrue(any('Stretched/square' in e for e in validate_scene_layers(self.payload)))
    def test_outside_source_bounds_is_rejected(self):
        self.payload['factions']['faction_veilmourn']['building_wayfarers_hall']['normalized_rect']=[0.9,0.3,0.3,0.3]
        self.assertTrue(any('Invalid normalized' in e for e in validate_scene_layers(self.payload)))

if __name__ == '__main__':
    unittest.main()
