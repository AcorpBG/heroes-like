import copy
import json
import unittest

import overworld_ground_materials_contract as contract


class GroundMaterialsTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.config = json.loads((contract.ROOT / 'art/overworld/ground_materials.json').read_text())
        cls.source = json.loads((contract.ROOT / cls.config['source_manifest'].removeprefix('res://')).read_text())

    def errors(self, config=None, source=None):
        return contract.validate(config=config or self.config, source=source or self.source)

    def test_current_originals_and_all_identities(self):
        self.assertEqual(self.errors(), [])

    def test_missing_alias_fails(self):
        config = copy.deepcopy(self.config)
        del config['terrain_slots']['lava']
        self.assertTrue(any('missing terrain' in error for error in self.errors(config)))

    def test_invalid_slot_fails(self):
        config = copy.deepcopy(self.config)
        config['terrain_slots']['water'] = 200
        self.assertTrue(any('out-of-range' in error for error in self.errors(config)))

    def test_generic_shared_fallback_fails(self):
        config = copy.deepcopy(self.config)
        config['terrain_slots'] = dict.fromkeys(config['terrain_slots'], 0)
        self.assertTrue(any('sixteen' in error for error in self.errors(config)))

    def test_missing_raster_fails(self):
        source = copy.deepcopy(self.source)
        source['runtime']['path'] = 'res://art/not-an-existing-ground.png'
        self.assertTrue(any('missing original/runtime' in error for error in self.errors(source=source)))

    def test_stale_provenance_fails(self):
        source = copy.deepcopy(self.source)
        source['sources'][0]['sha256'] = '0' * 64
        self.assertTrue(any('hash mismatch' in error for error in self.errors(source=source)))

    def test_reproducible_packaging(self):
        import sys
        sys.path.insert(0, str(contract.ROOT / 'tools'))
        import prepare_overworld_ground_materials as prepare
        self.assertEqual(prepare.packed_bytes(self.source), prepare.RUNTIME.read_bytes())


if __name__ == '__main__':
    unittest.main()
