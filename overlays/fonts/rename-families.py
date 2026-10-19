#!/usr/bin/env python3
"""Remove the baked stylistic-set token from Iosevka release family names.

The prebuilt Iosevka SS04 release names every family "… SS04". Dropping the
token lets the fonts install under their plain names.
"""

import re
import sys

from fontTools.ttLib import TTCollection

TOKEN = "SS04"


def cleaned(text):
    text = re.sub(r"-+", "-", text.replace(TOKEN, ""))
    text = re.sub(r"\s+", " ", text).strip()
    return text.strip("-")


def main():
    if len(sys.argv) != 3:
        raise SystemExit(f"usage: {sys.argv[0]} SOURCE.ttc DESTINATION.ttc")
    source, destination = sys.argv[1], sys.argv[2]
    collection = TTCollection(source)
    for font in collection.fonts:
        for record in font["name"].names:
            try:
                text = record.toUnicode()
            except Exception:
                continue
            text = cleaned(text)
            try:
                record.string = text.encode(record.getEncoding())
            except Exception:
                continue
    collection.save(destination)


if __name__ == "__main__":
    main()
