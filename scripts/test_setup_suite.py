#!/usr/bin/env python3
"""
test_setup_suite.py
Automated test suite verifying the end-to-end setup and extraction scripts.
"""

import json
import os
import re
import shutil
import tempfile
import unittest
import zipfile

from extract_theme_hospital import (
    clean_input_path,
    extract_archive,
    find_theme_hospital_root,
    is_theme_hospital_root,
)


class TestSetupSuite(unittest.TestCase):
    def setUp(self):
        self.test_dir = tempfile.mkdtemp(prefix="th_test_suite_")

    def tearDown(self):
        if os.path.exists(self.test_dir):
            shutil.rmtree(self.test_dir, ignore_errors=True)

    def test_clean_input_path_variants(self):
        home = os.path.expanduser("~")
        cases = [
            (
                "'/Users/test/Downloads/Theme Hospital.pkg'",
                "/Users/test/Downloads/Theme Hospital.pkg",
            ),
            (
                '"/Users/test/Downloads/Theme Hospital.pkg"',
                "/Users/test/Downloads/Theme Hospital.pkg",
            ),
            (
                r"/Users/test/Downloads/Theme\ Hospital\ \(GOG\).pkg ",
                "/Users/test/Downloads/Theme Hospital (GOG).pkg",
            ),
            (
                "~/Downloads/theme.pkg",
                os.path.join(home, "Downloads", "theme.pkg"),
            ),
            (
                "   '/tmp/space file.dmg'   ",
                "/tmp/space file.dmg",
            ),
        ]
        for raw, expected in cases:
            self.assertEqual(clean_input_path(raw), os.path.abspath(expected))

    def test_is_theme_hospital_root_validation(self):
        # Empty directory should fail
        empty_dir = os.path.join(self.test_dir, "empty")
        os.makedirs(empty_dir)
        self.assertFalse(is_theme_hospital_root(empty_dir))

        # Valid DOS format (lowercase / mixed)
        valid_dir = os.path.join(self.test_dir, "valid_game")
        os.makedirs(os.path.join(valid_dir, "data"))
        os.makedirs(os.path.join(valid_dir, "LEVELS"))
        os.makedirs(os.path.join(valid_dir, "qData"))
        self.assertTrue(is_theme_hospital_root(valid_dir))

        # Valid with hospital.exe + data
        exe_dir = os.path.join(self.test_dir, "exe_game")
        os.makedirs(os.path.join(exe_dir, "DATA"))
        with open(os.path.join(exe_dir, "HOSPITAL.EXE"), "w") as f:
            f.write("test")
        self.assertTrue(is_theme_hospital_root(exe_dir))

    def test_find_theme_hospital_root_nested(self):
        # Simulate Boxer / GOG nested structure:
        # package.pkg/Scripts/payload/Contents/Resources/game/
        nested_game = os.path.join(
            self.test_dir,
            "package.pkg",
            "Scripts",
            "payload",
            "Contents",
            "Resources",
            "game",
        )
        os.makedirs(os.path.join(nested_game, "DATA"))
        os.makedirs(os.path.join(nested_game, "LEVELS"))
        os.makedirs(os.path.join(nested_game, "QDATA"))
        with open(os.path.join(nested_game, "HOSPITAL.EXE"), "w") as f:
            f.write("dos_binary")

        found = find_theme_hospital_root(self.test_dir)
        self.assertEqual(found, nested_game)

    def test_extract_archive_zip(self):
        # Create a mock zip containing game data
        zip_path = os.path.join(self.test_dir, "test_game.zip")
        with zipfile.ZipFile(zip_path, "w") as zf:
            zf.writestr("ThemeHospital/DATA/mock.dat", "DATA")
            zf.writestr("ThemeHospital/LEVELS/mock.dat", "LEVELS")
            zf.writestr("ThemeHospital/QDATA/mock.dat", "QDATA")
            zf.writestr("ThemeHospital/HOSPITAL.EXE", "EXE")

        dest_extract = os.path.join(self.test_dir, "extracted")
        os.makedirs(dest_extract)
        extract_archive(zip_path, dest_extract)

        found = find_theme_hospital_root(dest_extract)
        self.assertIsNotNone(found)
        self.assertTrue(found.endswith("ThemeHospital"))

    def test_device_detection_json_parsing(self):
        mock_json = """
        {
          "result": {
            "devices": [
              {
                "deviceProperties": {"name": "iPad Pro Simulator"},
                "hardwareProperties": {"reality": "simulated", "udid": "SIM-1234"},
                "properties": {"connection": {"state": "disconnected"}}
              },
              {
                "deviceProperties": {"name": "Test iPad"},
                "hardwareProperties": {"reality": "physical", "udid": "00008103-000674EC1E63401E", "marketingName": "iPad Pro (11-inch)"},
                "properties": {"connection": {"state": "connected"}}
              }
            ]
          }
        }
        """
        data = json.loads(mock_json)
        phys = [
            d
            for d in data.get("result", {}).get("devices", [])
            if d.get("hardwareProperties", {}).get("reality") == "physical"
        ]
        self.assertEqual(len(phys), 1)
        self.assertEqual(phys[0]["deviceProperties"]["name"], "Test iPad")
        self.assertEqual(
            phys[0]["hardwareProperties"]["udid"], "00008103-000674EC1E63401E"
        )

    def test_codesigning_identity_regex(self):
        mock_security_output = """
  1) E15F06646BED8D92C70183AF283B2BE5E45C99FE "Apple Development: Tester Example (TEAM123456)"
  2) AD7093B96CB66568A65EE465734E0969E13E2C3B "Apple Development: Tester Example (TEAM123456)"
     2 valid identities found
        """
        m = re.search(
            r'"Apple Development: (.*?) \(([A-Z0-9]{10})\)"', mock_security_output
        )
        self.assertIsNotNone(m)
        self.assertEqual(m.group(1), "Tester Example")
        self.assertEqual(m.group(2), "TEAM123456")


if __name__ == "__main__":
    unittest.main()
