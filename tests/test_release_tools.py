import importlib.util
import os
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts" / "release_version.py"
SPEC = importlib.util.spec_from_file_location("release_version", SCRIPT)
release_version = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(release_version)


class ReleaseVersionTests(unittest.TestCase):
    def test_stable_release(self):
        self.assertEqual(release_version.parse_tag("v1.2.3"), ("1.2.3", False))

    def test_beta_release(self):
        self.assertEqual(
            release_version.parse_tag("v1.2.0-beta.3"),
            ("1.2.0-beta.3", True),
        )

    def test_invalid_tags(self):
        for tag in ("1.2.3", "v1.2", "v01.2.3", "main"):
            with self.subTest(tag=tag), self.assertRaises(ValueError):
                release_version.parse_tag(tag)

    def test_github_outputs(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "output"
            with patch.dict(os.environ, {"GITHUB_OUTPUT": str(output)}):
                self.assertEqual(release_version.main(["release_version.py", "v2.0.0"]), 0)
            self.assertEqual(output.read_text(), "version=2.0.0\nprerelease=false\n")


if __name__ == "__main__":
    unittest.main()
