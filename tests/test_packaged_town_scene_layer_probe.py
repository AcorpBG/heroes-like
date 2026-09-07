import unittest

import packaged_town_scene_layer_regression as packaged
import town_scene_layer_regression as layers


class PackagedTownProbeTests(unittest.TestCase):
    def test_headless_keeps_every_non_capture_operation(self):
        original = layers.SCRIPT + layers.HARBOR_GROWTH
        result, removed = packaged.headless_script(original)
        before = original.splitlines()
        after = result.splitlines()
        self.assertEqual(len(before), len(after))
        self.assertGreater(len(removed), 10)
        for first, second in zip(before, after):
            if first.strip() in removed:
                self.assertEqual(len(first)-len(first.lstrip()), len(second)-len(second.lstrip()))
                self.assertTrue(second.strip().startswith('pass # Headless package:'))
            else:
                self.assertEqual(first, second)
        for token in ('check(', 'SaveService.', 'validation_confirm_build_plan()',
                      'Input.parse_input_event', 'layer_click(', 'session.day'):
            self.assertEqual(original.count(token), result.count(token))

    def test_headless_rejects_unpaired_capture_rewrite(self):
        for script in ('check(true,"retained")', 'await RenderingServer.frame_post_draw',
                       'await RenderingServer.frame_post_draw\nawait RenderingServer.frame_post_draw'):
            with self.subTest(script=script), self.assertRaises(ValueError):
                packaged.headless_script(script)

    def test_explicit_windows_paths_preserve_spaces(self):
        self.assertEqual(packaged.windows_path('/tmp/earned Town/slot2.json'),
                         'Z:\\tmp\\earned Town\\slot2.json')


if __name__ == '__main__':
    unittest.main()
