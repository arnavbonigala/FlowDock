import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "FlowDock"
EXAMPLES = ROOT / "examples"


def swift_files(*roots):
    for root in roots:
        yield from sorted(root.rglob("*.swift"))


def lines(path):
    return path.read_text().split("\n")


def relative(path):
    return path.relative_to(ROOT).as_posix()


class LoggingTests(unittest.TestCase):
    def test_no_print_in_app_sources(self):
        offenders = [
            f"{relative(path)}:{number}"
            for path in swift_files(APP)
            for number, line in enumerate(lines(path), 1)
            if re.match(r"^\s*print\(", line)
        ]
        self.assertEqual(
            offenders,
            [],
            "print writes to a standard output nothing is attached to once the app is "
            "launched from Finder. Report failures with NSLog.",
        )


class TypographyTests(unittest.TestCase):
    SANCTIONED = {
        # DESIGN.md section 6 lists these and only these. See the table there before adding one.
        ("FlowDock/components/PowerActivity.swift", "7"),
        ("FlowDock/components/Music/MusicActivity.swift", "26"),
        ("FlowDock/components/SystemFeedback.swift", "11"),
        ("FlowDock/components/SystemFeedback.swift", "15"),
    }

    def test_fixed_sizes_are_sanctioned(self):
        found = set()
        for path in swift_files(APP):
            if path.name == "Typography.swift":
                continue
            for line in lines(path):
                for size in re.findall(r"Font\.system\(size: (\d+)", line):
                    found.add((relative(path), size))
                for size in re.findall(r"\.system\(size: (\d+)", line):
                    found.add((relative(path), size))

        self.assertEqual(
            sorted(found - self.SANCTIONED),
            [],
            "A fixed point size outside the named tokens in Typography.swift needs a row "
            "in the sanctioned-exceptions table in DESIGN.md.",
        )

    def test_no_rounded_or_serif(self):
        offenders = [
            f"{relative(path)}:{number}"
            for path in swift_files(APP, EXAMPLES)
            for number, line in enumerate(lines(path), 1)
            if "design: .rounded" in line or "design: .serif" in line
        ]
        self.assertEqual(
            offenders,
            [],
            "DESIGN.md section 2: rounded is the system's playful voice and FlowDock is a calm one.",
        )


class DeadCodeTests(unittest.TestCase):
    def test_no_empty_blocks(self):
        offenders = []
        for path in swift_files(APP, EXAMPLES):
            source = lines(path)
            for number, line in enumerate(source, 1):
                if not line.strip().endswith("{"):
                    continue
                if number < len(source) and source[number].strip() == "}":
                    offenders.append(f"{relative(path)}:{number}")
        self.assertEqual(
            offenders,
            [],
            "A block that runs nothing reads as live code to whoever traces the behaviour "
            "it appears to produce.",
        )


class SelfCheckTests(unittest.TestCase):
    def test_every_self_check_is_invoked(self):
        called = set()
        declared = {}
        for path in swift_files(APP):
            source = path.read_text()
            called.update(re.findall(r"(\w+)\.selfCheck\(\)", source))
            if "static func selfCheck()" in source:
                owners = set(re.findall(r"(?:extension|struct|class|enum)\s+(\w+)", source))
                if "Self.selfCheck()" in source:
                    owners.add("Self")
                declared[relative(path)] = owners

        self.assertTrue(declared, "expected the app to declare self-checks")
        uninvoked = sorted(
            file for file, owners in declared.items() if not owners & called
        )
        self.assertEqual(
            uninvoked,
            [],
            "A selfCheck nobody calls asserts nothing. Invoke it from ActivityStore's "
            "DEBUG block, or from the type's own initialiser.",
        )


class SettingsTests(unittest.TestCase):
    def test_every_stored_key_is_read(self):
        constants = APP / "models" / "Constants.swift"
        keys = re.findall(r"static let (\w+) = Key<", constants.read_text())
        self.assertTrue(keys, "expected Constants.swift to declare stored keys")

        elsewhere = "\n".join(
            path.read_text() for path in swift_files(APP) if path != constants
        )
        unread = [key for key in keys if not re.search(rf"\.{key}\b", elsewhere)]
        self.assertEqual(
            unread,
            [],
            "A stored key nothing reads is a switch in settings that does nothing.",
        )


if __name__ == "__main__":
    unittest.main()
