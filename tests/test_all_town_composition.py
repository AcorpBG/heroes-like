"""Source-space composition guards complement, never replace, rendered review."""
import json
from pathlib import Path
import unittest

from PIL import Image, ImageChops

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / 'content/town_building_scene_art_manifest.json'

# Reviewed support corridors in the unchanged village paintings. Ground landmarks
# must remain on these shores/terraces; rectangles are not runtime placement code.
GROUND_SITES = {
    'faction_embercourt': {
        'building_lantern_archive': (.54, .28, .14, .10),
        'building_starseer_annex': (.54, .28, .14, .10),
        'building_embercourt_granary_lock_exchange': (.20, .52, .09, .10),
        'building_embercourt_beaconline_charter_house': (.42, .39, .08, .09),
        'building_charter_bastion': (.36, .42, .08, .08),
    },
    'faction_mireclaw': {
        'building_mireclaw_hollowreed_moonwax_ossuary': (.42, .42, .07, .08),
        'building_mireclaw_moonbite_votive_drum_court': (.42, .42, .07, .08),
    },
    'faction_sunvault': {
        'building_prism_range': (.18, .34, .08, .06),
        'building_lens_gallery': (.18, .34, .08, .06),
        'building_sunvault_splitprism_parallax_duel_hall': (.40, .40, .06, .05),
    },
    'faction_thornwake': {
        'building_thornwake_worldroot_gate': (.15, .40, .065, .06),
        'building_thornwake_verdant_concord_seat': (.15, .40, .065, .06),
        'building_thornwake_sporeglass_hothouse': (.41, .65, .09, .08),
        'building_thornwake_loam_ledger': (.55, .80, .09, .08),
    },
    'faction_brasshollow': {
        'building_brasshollow_rail_tax_office': (.78, .70, .07, .08),
        'building_brasshollow_whitegauge_datum_railhouse': (.39, .79, .08, .075),
        'building_brasshollow_scalehouse': (.54, .44, .08, .045),
    },
    'faction_veilmourn': {
        'building_veilmourn_drowned_map_room': (.12, .80, .09, .08),
    },
}


def validate_composition(payload=None):
    payload = payload or json.loads(MANIFEST.read_text())
    errors = []
    factions = payload['factions']
    for faction, sites in GROUND_SITES.items():
        for bid, (x, y, w, h) in sites.items():
            row = factions.get(faction, {}).get(bid, {})
            ground = row.get('ground_anchor', [-1, -1])
            if not (x <= ground[0] <= x+w and y <= ground[1] <= y+h):
                errors.append(f'Unsupported scenic ground: {faction}/{bid}')
    layouts = json.loads((ROOT/'content/town_building_scene_layouts.json').read_text())['factions']
    buildings = {b['id']: b for b in json.loads((ROOT/'content/buildings.json').read_text())['items']}
    masks = {}
    for town in json.loads((ROOT/'content/towns.json').read_text())['items']:
        faction = town['faction_id']
        built = set(town['starting_building_ids'] + town['buildable_building_ids'])
        visible = []
        for plot in layouts[faction]['plots']:
            if plot.get('embedded_in_base'): continue
            candidates = [bid for bid in plot['building_ids'] if bid in built]
            ancestors = set()
            for bid in candidates:
                ancestor = buildings[bid].get('upgrade_from', '')
                visited = set()
                while ancestor and ancestor not in visited:
                    ancestors.add(ancestor)
                    visited.add(ancestor)
                    ancestor = buildings[ancestor].get('upgrade_from', '')
            candidates = [bid for bid in candidates if bid not in ancestors]
            if candidates: visible.append(candidates[-1])
        front = Image.new('L', (1600, 900))
        for bid in sorted(visible, key=lambda b:factions[faction][b]['ground_anchor'][1], reverse=True):
            key = faction, bid
            if key not in masks:
                row = factions[faction][bid]
                x, y, w, h = [round(v*s) for v,s in zip(row['normalized_rect'], (1600,900,1600,900))]
                with Image.open(ROOT/row['runtime_path'].removeprefix('res://')) as raster:
                    alpha = raster.getchannel('A').resize((w,h)).point(lambda a:255 if a>64 else 0)
                mask = Image.new('L', (1600,900))
                mask.paste(alpha, (x,y))
                masks[key] = mask
            mask = masks[key]
            painted = mask.histogram()[255]
            hidden = ImageChops.multiply(mask,front).histogram()[255]
            # Prevent a return to 60-85% buried buildings. This does not certify
            # grounding, doorway visibility, or UI access; those need live views.
            if not painted or hidden/painted > .55:
                errors.append(f'Mostly hidden scenic building: {town["id"]}/{bid}')
            front = ImageChops.lighter(front,mask)
    return errors


class CompositionTests(unittest.TestCase):
    def test_current_composition(self):
        self.assertEqual([], validate_composition())

    def test_original_floating_ossuary_is_rejected(self):
        payload = json.loads(MANIFEST.read_text())
        payload['factions']['faction_mireclaw']['building_mireclaw_hollowreed_moonwax_ossuary']['ground_anchor'] = [.215625, .35333333333333333]
        self.assertTrue(any('Unsupported scenic ground' in e for e in validate_composition(payload)))

    def test_original_buried_foreman_is_rejected(self):
        payload = json.loads(MANIFEST.read_text())
        rows = payload['factions']['faction_brasshollow']
        # Exact audited predecessor locations, preserving real raster alpha.
        rows['building_brasshollow_foreman_clausehouse']['normalized_rect'] = [.459375,.3,.11015625,.13333333333333333]
        rows['building_brasshollow_foreman_clausehouse']['ground_anchor'] = [.515625,.42533333333333334]
        rows['building_brasshollow_boiler_cathedral']['normalized_rect'] = [.4125,.3,.16875,.2]
        rows['building_brasshollow_boiler_cathedral']['ground_anchor'] = [.496875,.488]
        self.assertTrue(any('Mostly hidden' in e and 'foreman_clausehouse' in e for e in validate_composition(payload)))


if __name__ == '__main__':
    unittest.main()
