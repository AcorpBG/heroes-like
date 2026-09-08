"""Exact-faction preparation must preserve accepted art and fail bad inputs."""
import copy
import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('town_layer_preparation',ROOT/'tools/prepare_town_scene_layers.py')
prepare = importlib.util.module_from_spec(spec)
spec.loader.exec_module(prepare)


class ScenePreparationTests(unittest.TestCase):
    def test_selected_packet_preserves_other_factions_and_metadata(self):
        existing={'schema_id':'town_building_scene_art_v1','owner_approval':'retained',
                  'generation':{'tool':'built_in_image_gen'},'factions':{
                      'faction_veilmourn':{'building_wayfarers_hall':{'opaque':'old exact row'}},
                      'faction_embercourt':{'earlier':{'opaque':'preserve even unselected id'}}}}
        before=copy.deepcopy(existing)
        rows={'building_wayfarers_hall':{'asset_id':'faction_embercourt_building_wayfarers_hall'}}
        result=prepare.merge_layers(existing,{'faction_embercourt':rows})
        self.assertEqual(existing,before)
        self.assertEqual(result['factions']['faction_veilmourn'],before['factions']['faction_veilmourn'])
        self.assertEqual(result['factions']['faction_embercourt']['earlier'],before['factions']['faction_embercourt']['earlier'])
        self.assertEqual(result['generation'],before['generation'])
        self.assertEqual(result['owner_approval'],before['owner_approval'])
        self.assertEqual(prepare.merge_layers(result,{'faction_embercourt':rows}),result)
        rows['building_wayfarers_hall']['asset_id']='caller mutation'
        self.assertEqual(result['factions']['faction_embercourt']['building_wayfarers_hall']['asset_id'],'faction_embercourt_building_wayfarers_hall')

    def test_cross_faction_prepared_identity_is_rejected(self):
        with self.assertRaisesRegex(ValueError,'Cross-faction'):
            prepare.merge_layers({'schema_id':'town_building_scene_art_v1'},
                {'faction_embercourt':{'building_wayfarers_hall':{'asset_id':'faction_veilmourn_building_wayfarers_hall'}}})

    def test_unknown_schema_is_not_replaced(self):
        with self.assertRaisesRegex(ValueError,'unknown scene-art manifest'):
            prepare.merge_layers({'schema_id':'unknown'}, {})

    def test_missing_or_changed_master_fails_before_processing(self):
        with tempfile.TemporaryDirectory(prefix='town-layer-input-') as temporary, patch.object(prepare,'ROOT',Path(temporary)), patch.object(prepare.subprocess,'run') as run:
            brief={'source_sha256':'0'*64}
            with self.assertRaises(FileNotFoundError):
                prepare.prepare_layers('faction_embercourt',{'building_muster_yard':brief})
            source=Path(temporary)/'art/towns/source/generated/scene_layers/faction_embercourt/building_muster_yard.png'
            source.parent.mkdir(parents=True)
            source.write_bytes(b'not an approved master')
            with self.assertRaisesRegex(AssertionError,'Unapproved master'):
                prepare.prepare_layers('faction_embercourt',{'building_muster_yard':brief})
            run.assert_not_called()


if __name__=='__main__':
    unittest.main()
