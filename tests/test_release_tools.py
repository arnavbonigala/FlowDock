import importlib.util
import os
import tempfile
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[1]


def load(name):
    spec = importlib.util.spec_from_file_location(name, ROOT / "scripts" / f"{name}.py")
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


release_version = load("release_version")
appcast = load("appcast")


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


class AppcastTests(unittest.TestCase):
    def write(self, directory, version, build="1", channel=None):
        path = Path(directory) / "appcast.xml"
        if not path.exists():
            path.write_text((ROOT / "updater" / "appcast.xml").read_text(), encoding="utf-8")
        appcast.main(
            [
                "appcast.py",
                str(path),
                "--version",
                version,
                "--build",
                build,
                "--url",
                f"https://example.invalid/FlowDock-{version}.dmg",
                "--length",
                "1234",
                "--signature",
                "sig-" + version,
                "--pub-date",
                "Mon, 10 Aug 2026 00:00:00 +0000",
            ]
            + (["--channel", channel] if channel else [])
        )
        return path

    def test_item_is_added_with_signature(self):
        with tempfile.TemporaryDirectory() as directory:
            path = self.write(directory, "1.0.0")
            channel = ET.parse(path).getroot().find("channel")
            items = channel.findall("item")
            self.assertEqual(len(items), 1)
            self.assertEqual(items[0].findtext("title"), "1.0.0")
            enclosure = items[0].find("enclosure")
            self.assertEqual(enclosure.get("length"), "1234")
            self.assertEqual(enclosure.get(appcast.sparkle("edSignature")), "sig-1.0.0")

    def test_newest_first_and_rerun_replaces(self):
        with tempfile.TemporaryDirectory() as directory:
            path = self.write(directory, "1.0.0")
            self.write(directory, "1.1.0", build="2")
            self.write(directory, "1.1.0", build="3")
            channel = ET.parse(path).getroot().find("channel")
            items = channel.findall("item")
            self.assertEqual([item.findtext("title") for item in items], ["1.1.0", "1.0.0"])
            self.assertEqual(items[0].findtext(appcast.sparkle("version")), "3")
            self.assertEqual(channel.findtext("title"), "FlowDock Updates")

    def test_stable_items_carry_no_channel(self):
        with tempfile.TemporaryDirectory() as directory:
            path = self.write(directory, "1.0.0")
            item = ET.parse(path).getroot().find("channel").find("item")
            self.assertIsNone(item.find(appcast.sparkle("channel")))

    def test_a_prerelease_is_confined_to_its_channel(self):
        with tempfile.TemporaryDirectory() as directory:
            path = self.write(directory, "1.1.0-beta.1", channel="beta")
            self.write(directory, "1.0.0")
            items = ET.parse(path).getroot().find("channel").findall("item")
            channels = {
                item.findtext("title"): item.findtext(appcast.sparkle("channel"))
                for item in items
            }
            self.assertEqual(channels["1.1.0-beta.1"], "beta")
            self.assertIsNone(channels["1.0.0"])


if __name__ == "__main__":
    unittest.main()
