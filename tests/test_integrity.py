"""Standard-library regression tests for release validation, not a Godot substitute.
Run: python3 -m unittest discover -s tests -p 'test_*.py' -v
"""
import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import zipfile

SPEC = importlib.util.spec_from_file_location("check_project", Path(__file__).resolve().parents[1] / "tools/check_project.py")
checker = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(checker)


class IntegrityTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / "scenes").mkdir()
        (self.root / "scripts").mkdir()
        (self.root / "project.godot").write_text('config_version=5\n[application]\nrun/main_scene="res://scenes/main.tscn"\n')
        (self.root / "scenes/main.tscn").write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://scripts/game.gd" id="1"]\n[node name="Main" type="Node3D"]\nscript = ExtResource("1")\n')
        (self.root / "scripts/game.gd").write_text('extends Node3D\n')
        self.seal()

    def seal(self):
        entries = {p.relative_to(self.root).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
                   for p in self.root.rglob("*") if p.is_file() and p.name != "integrity.json"}
        (self.root / "integrity.json").write_text(json.dumps({"format": 1, "algorithm": "SHA-256", "files": entries}))

    def test_clean_files_and_reference_graph(self):
        self.assertEqual(checker.check_files(self.root), [])
        self.assertEqual(checker.check_resources(self.root), [])

    def test_missing_main_scene_is_reported(self):
        (self.root / "scenes/main.tscn").unlink()
        self.assertIn('MISSING: scenes/main.tscn', checker.check_files(self.root))
        self.assertTrue(any('MAIN SCENE MISSING' in x for x in checker.check_resources(self.root)))

    def test_modified_file_is_reported_without_repairing_it(self):
        script = self.root / "scripts/game.gd"
        script.write_text('extends Node3D\n# intentional edit\n')
        self.assertEqual(checker.check_files(self.root), ['CHANGED: scripts/game.gd'])
        self.assertIn('intentional edit', script.read_text())

    def test_truncated_scene_header(self):
        (self.root / "scenes/main.tscn").write_bytes(b'')
        self.assertTrue(any('INVALID SCENE HEADER' in x for x in checker.check_resources(self.root)))

    def test_missing_script_dependency(self):
        (self.root / "scripts/game.gd").unlink()
        self.assertTrue(any('BROKEN REFERENCE' in x for x in checker.check_resources(self.root)))

    def test_custom_music_is_optional(self):
        (self.root / "scripts/game.gd").write_text('extends Node3D\nvar music = "res://assets/music/breakcore.ogg"\n')
        self.assertEqual(checker.check_resources(self.root), [])

    def test_invalid_project_entry_point(self):
        (self.root / "project.godot").write_text('config_version=5\n')
        self.assertEqual(checker.check_resources(self.root), ['MAIN SCENE: missing run/main_scene setting'])

    def test_missing_manifest(self):
        (self.root / "integrity.json").unlink()
        self.assertTrue(checker.check_files(self.root)[0].startswith('MANIFEST:'))

    def test_invalid_manifest(self):
        (self.root / "integrity.json").write_text('{broken')
        self.assertTrue(checker.check_files(self.root)[0].startswith('MANIFEST:'))

    def test_paths_cannot_escape_the_project(self):
        data = {"format": 1, "algorithm": "SHA-256", "files": {"../outside": "000"}}
        (self.root / "integrity.json").write_text(json.dumps(data))
        self.assertTrue(any('Unsafe manifest path' in x for x in checker.check_files(self.root)))

    def test_write_probe_is_clean_and_non_destructive(self):
        before = sorted(str(p) for p in self.root.rglob('*'))
        self.assertIsNone(checker.probe_directory(self.root))
        self.assertEqual(sorted(str(p) for p in self.root.rglob('*')), before)
        self.assertEqual(checker.check_files(self.root), [])

    def test_failed_replace_reports_and_cleans_temporary_files(self):
        with patch.object(checker.os, 'replace', side_effect=PermissionError('blocked')):
            self.assertIn('WRITE/REPLACE FAILED', checker.probe_directory(self.root))
        self.assertFalse(list(self.root.glob('.rift-write-test-*')))
        self.assertEqual(checker.check_files(self.root), [])

    def test_archive_roundtrip_including_spaces_and_unicode(self):
        archive = self.root / 'test.zip'
        files = [p for p in self.root.rglob('*') if p.is_file()]
        with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED) as output:
            for path in files:
                output.write(path, path.relative_to(self.root).as_posix())
        with tempfile.TemporaryDirectory(prefix='Rift тест ') as extracted:
            with zipfile.ZipFile(archive) as source:
                self.assertIsNone(source.testzip())
                source.extractall(extracted)
            self.assertEqual(checker.check_files(Path(extracted)), [])
            self.assertEqual(checker.check_resources(Path(extracted)), [])
            self.assertIsNone(checker.probe_directory(Path(extracted)))


if __name__ == '__main__':
    unittest.main()
