import json
import sys
from pathlib import Path

from fontTools.ttLib import TTCollection, TTFont


def require(condition, message):
    if not condition:
        raise ValueError(message)


def load(path):
    if path.suffix == ".ttc":
        return TTCollection(str(path)).fonts
    return [TTFont(str(path), lazy=False)]


def inspect(path):
    families = set()
    has_text_glyphs = False
    for font in load(path):
        cmap = font.getBestCmap()
        has_text_glyphs = has_text_glyphs or (cmap is not None and 0x41 in cmap and 0x6C in cmap)
        for record in font["name"].names:
            if record.nameID in (1, 16):
                families.add(record.toUnicode())
    return families, has_text_glyphs


def check_variant(variant):
    root = Path(variant["path"])
    paths = sorted(path for path in root.rglob("*") if path.suffix.lower() in {".ttc", ".ttf", ".otf"})
    require(bool(paths), f"{variant['package']}: no font files in {root}")
    found = set()
    for path in paths:
        families, has_text_glyphs = inspect(path)
        require(has_text_glyphs, f"{variant['package']}: {path.name} has no Latin cmap")
        found |= families
    missing = set(variant["families"]) - found
    require(not missing, f"{variant['package']}: missing families {sorted(missing)} (found {sorted(found)})")
    print(f"{variant['package']}: families {sorted(found)}")


def check_fallback(fallback):
    with TTFont(fallback["path"], lazy=False) as font:
        cmap = font.getBestCmap()
    require(cmap is not None, f"{fallback['package']}: missing Unicode cmap")
    missing = [codepoint for codepoint in fallback["codepoints"] if codepoint not in cmap]
    require(not missing, f"{fallback['package']}: missing codepoints {[hex(cp) for cp in missing]}")
    print(f"{fallback['package']}: covers {len(fallback['codepoints'])} icon codepoints")


def main():
    if len(sys.argv) != 2:
        raise SystemExit(f"usage: {sys.argv[0]} MANIFEST.json")
    with open(sys.argv[1], encoding="utf-8") as stream:
        manifest = json.load(stream)
    require(bool(manifest["variants"]), "empty font manifest")
    for variant in manifest["variants"]:
        check_variant(variant)
    check_fallback(manifest["fallback"])


if __name__ == "__main__":
    main()