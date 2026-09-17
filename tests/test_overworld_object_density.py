import copy
import json
import sys
import unittest

import overworld_object_density_contract as contract


class ObjectDensityTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.config = json.loads((contract.ROOT / 'art/overworld/object_raster_density.json').read_text())

    def test_current_source_and_runtime(self):
        self.assertEqual(contract.validate(), [])

    def test_missing_identity_fails(self):
        data = copy.deepcopy(self.config)
        del data['assets']['mapobj_ashcrown_cinderfold']
        self.assertTrue(contract.validate(data))

    def test_wrong_original_mapping_fails(self):
        data = copy.deepcopy(self.config)
        data['assets']['mapobj_ashcrown_cinderfold']['original_path'] = 'res://wrong.png'
        self.assertTrue(contract.validate(data))

    def test_low_density_and_swapped_pixels_fail(self):
        data = copy.deepcopy(self.config)
        data['assets']['mapobj_ashcrown_cinderfold']['atlas_region'][2:] = [48, 48]
        self.assertTrue(contract.validate(data))
        data = copy.deepcopy(self.config)
        data['assets']['mapobj_ashcrown_cinderfold']['atlas_region'][0] = 192
        self.assertTrue(any('wrong asset pixels' in error for error in contract.validate(data)))

    def test_reproducible_original_painting_pack(self):
        sys.path.insert(0, str(contract.ROOT / 'tools'))
        import prepare_overworld_object_density as packer
        for path, data in packer.build().items():
            self.assertEqual(path.read_bytes(), data, str(path))


if __name__ == '__main__':
    unittest.main()
