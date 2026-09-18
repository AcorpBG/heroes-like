"""Diagnostic truth: missing source bodies cannot hide behind live-only counts."""
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from rmg_guard_space_audit import analyze, components, points, shortest_path


class GuardSpaceAuditTests(unittest.TestCase):
    def fixture(self):
        return {'native_objects': [{'placement_id': 'lake', 'h3m_type_id': 126,
                                   'package_block_tiles': [{'x': 1, 'y': 1}]}],
                'overworld': {'map_size': {'width': 3, 'height': 3},
                              'encounters': [], 'map_objects': []},
                'grid': {'blocked': []}}

    def test_missing_nonvisitable_body_counts(self):
        result = analyze(self.fixture())
        self.assertEqual(result['missing_objects'], 1)
        self.assertEqual(result['source_block_cells_now_walkable'], 1)

    def test_overlap_does_not_inflate_opened_space(self):
        data = self.fixture()
        data['grid']['blocked'] = [[1, 1]]
        result = analyze(data)
        self.assertEqual(result['missing_objects'], 1)
        self.assertEqual(result['source_block_cells_now_walkable'], 0)

    def test_adopted_identity_is_not_missing(self):
        data = self.fixture()
        data['overworld']['map_objects'] = data['native_objects']
        self.assertEqual(analyze(data)['missing_objects'], 0)

    def test_surface_only_points(self):
        self.assertEqual(points([{'body': [{'x': 1, 'y': 2, 'level': 1},
                                           {'x': 2, 'y': 3}]}], 'body'), {(2, 3)})

    def test_native_diagonal_adjacency(self):
        self.assertEqual(len(set(components({(0, 0), (1, 1)}).values())), 1)
        self.assertEqual(len(set(components({(0, 0), (2, 2)}).values())), 2)

    def test_path_requires_every_cell(self):
        cells = {(0, 0), (1, 0), (2, 0)}
        self.assertEqual(shortest_path(cells, (0, 0), (2, 0)), [(0, 0), (1, 0), (2, 0)])
        self.assertEqual(shortest_path(cells - {(1, 0)}, (0, 0), (2, 0)), [])


if __name__ == '__main__':
    unittest.main()
