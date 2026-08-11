#!/usr/bin/env python3

"""Insert or replace one release in a Sparkle appcast.

Sparkle's own generate_appcast wants every published archive sitting in one
directory so it can hash them. FlowDock keeps its DMGs on GitHub releases and
only the feed on gh-pages, so the signature comes from Sparkle's sign_update
and this script writes the item.
"""

from __future__ import annotations

import argparse
import sys
import xml.etree.ElementTree as ET
from email.utils import format_datetime
from datetime import datetime, timezone


SPARKLE_NS = "http://www.andymatuschak.org/xml-namespaces/sparkle"


def sparkle(tag: str) -> str:
    return f"{{{SPARKLE_NS}}}{tag}"


def build_item(
    version: str,
    build: str,
    url: str,
    length: str,
    signature: str,
    minimum_system_version: str,
    pub_date: str,
) -> ET.Element:
    item = ET.Element("item")
    ET.SubElement(item, "title").text = version
    ET.SubElement(item, "pubDate").text = pub_date
    ET.SubElement(item, sparkle("version")).text = build
    ET.SubElement(item, sparkle("shortVersionString")).text = version
    ET.SubElement(item, sparkle("minimumSystemVersion")).text = minimum_system_version
    ET.SubElement(
        item,
        "enclosure",
        {
            "url": url,
            "length": length,
            "type": "application/octet-stream",
            sparkle("edSignature"): signature,
        },
    )
    return item


def update_appcast(tree: ET.ElementTree, item: ET.Element, version: str) -> ET.ElementTree:
    channel = tree.getroot().find("channel")
    if channel is None:
        raise ValueError("The appcast has no <channel> element")

    for existing in channel.findall("item"):
        title = existing.findtext("title")
        short = existing.findtext(sparkle("shortVersionString"))
        if version in (title, short):
            channel.remove(existing)

    insert_at = len(list(channel))
    for index, child in enumerate(list(channel)):
        if child.tag == "item":
            insert_at = index
            break
    channel.insert(insert_at, item)
    return tree


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("appcast", help="Path to the appcast to rewrite in place")
    parser.add_argument("--version", required=True, help="Marketing version, e.g. 1.2.0")
    parser.add_argument("--build", required=True, help="Build number (CFBundleVersion)")
    parser.add_argument("--url", required=True, help="Download URL of the DMG")
    parser.add_argument("--length", required=True, help="DMG size in bytes, from sign_update")
    parser.add_argument("--signature", required=True, help="sparkle:edSignature, from sign_update")
    parser.add_argument("--minimum-system-version", default="14.0")
    parser.add_argument("--pub-date", default=None, help="RFC 2822 date; defaults to now")
    args = parser.parse_args(argv[1:])

    ET.register_namespace("sparkle", SPARKLE_NS)
    tree = ET.parse(args.appcast)
    pub_date = args.pub_date or format_datetime(datetime.now(timezone.utc))
    item = build_item(
        args.version,
        args.build,
        args.url,
        args.length,
        args.signature,
        args.minimum_system_version,
        pub_date,
    )
    update_appcast(tree, item, args.version)
    if hasattr(ET, "indent"):
        ET.indent(tree, space="  ")
    tree.write(args.appcast, encoding="utf-8", xml_declaration=True)
    print(f"Wrote {args.version} ({args.build}) to {args.appcast}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
