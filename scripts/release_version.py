#!/usr/bin/env python3

from __future__ import annotations

import os
import re
import sys


TAG_RE = re.compile(
    r"^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)"
    r"(?:-([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?"
    r"(?:\+([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?$"
)


def parse_tag(tag: str) -> tuple[str, bool]:
    match = TAG_RE.fullmatch(tag)
    if not match:
        raise ValueError(
            "Release tags must use v<major>.<minor>.<patch>, optionally with a prerelease or build suffix"
        )
    return tag[1:], match.group(4) is not None


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print(f"Usage: {argv[0]} <tag>", file=sys.stderr)
        return 1

    try:
        version, prerelease = parse_tag(argv[1])
    except ValueError as error:
        print(error, file=sys.stderr)
        return 1

    output = os.environ.get("GITHUB_OUTPUT")
    if output:
        with open(output, "a", encoding="utf-8") as file:
            file.write(f"version={version}\n")
            file.write(f"prerelease={str(prerelease).lower()}\n")

    print(f"FlowDock {version} ({'prerelease' if prerelease else 'stable'})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
