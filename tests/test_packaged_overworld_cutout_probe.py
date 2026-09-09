import json
import unittest

import overworld_map_object_cutout_regression as cutouts
import packaged_overworld_map_object_cutout_regression as packaged
from packaged_town_scene_layer_regression import headless_script


class PackagedOverworldCutoutProbeTests(unittest.TestCase):
    def test_headless_keeps_all_gameplay_and_pixel_assertions(self):
        script,omitted = headless_script(cutouts.SCRIPT)
        self.assertEqual(len(omitted),2)
        self.assertEqual([line.strip() for line in script.splitlines() if 'check(' in line],
                         [line.strip() for line in cutouts.SCRIPT.splitlines() if 'check(' in line])
        for authority in ('_resource_asset_id','package_block_tiles','_resource_node_matches_controller',
                          'is_tile_visible','save_session','load_session','raster.get_pixel'):
            self.assertIn(authority,script)

    def test_windows_translates_only_file_paths(self):
        environment=dict(ART_REPAIR_SAVE='/tmp/earned.json',ART_REPAIR_OUTPUT='/tmp/proof',
                         ART_REPAIR_RESOLUTION='1920x1080',ART_REPAIR_CASE=json.dumps(cutouts.CASES['large_cinder']))
        result = packaged.package_environment(environment,'windows')
        self.assertEqual(result['ART_REPAIR_SAVE'],'Z:\\tmp\\earned.json')
        self.assertEqual(result['ART_REPAIR_OUTPUT'],'Z:\\tmp\\proof')
        self.assertEqual(result['ART_REPAIR_CASE'],environment['ART_REPAIR_CASE'])
        self.assertEqual(result['TOWN_OVERLAY_RESOLUTION'],environment['ART_REPAIR_RESOLUTION'])
        self.assertEqual(environment['ART_REPAIR_SAVE'],'/tmp/earned.json')
        linux = packaged.package_environment(environment,'linux')
        self.assertTrue(all(linux[key]==value for key,value in environment.items()))


if __name__=='__main__':
    unittest.main()
