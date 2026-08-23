import json
import sys
from pathlib import Path

from fontTools.pens.boundsPen import BoundsPen
from fontTools.ttLib import TTFont


STYLES = {
    "Regular": (400, False, False),
    "Bold": (700, True, False),
    "Italic": (400, False, True),
    "Bold Italic": (700, True, True),
}
NERD_GLYPHS = {
    0xE0B0: "Powerline separator",
    0xE5FA: "Custom npm folder",
    0xE615: "Seti config",
    0xE700: "Devicons git",
    0xEA60: "Codicons add",
    0xF057: "Font Awesome error",
    0xF058: "Font Awesome success",
    0xF07B: "Font Awesome folder",
    0xF120: "Font Awesome terminal",
    0xF17C: "Font Awesome Linux",
    0xF432: "Octicons arrow right",
    0xF0001: "Material Design vector square",
}
REQUIRED_TABLES = {"head", "hhea", "maxp", "OS/2", "hmtx", "cmap", "name", "post"}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def names(font, name_id):
    return {record.toUnicode() for record in font["name"].names if record.nameID == name_id}


def check_font(path, family, monospaced):
    with TTFont(path, lazy=False, checkChecksums=2) as font:
        require(REQUIRED_TABLES <= set(font.keys()), "missing required OpenType tables")
        require(
            {"glyf", "loca"} <= set(font.keys()) or "CFF " in font or "CFF2" in font,
            "missing glyph outlines",
        )
        font.ensureDecompiled()
        require(16 <= font["head"].unitsPerEm <= 16384, "invalid unitsPerEm")
        glyph_order = font.getGlyphOrder()
        require(len(glyph_order) == font["maxp"].numGlyphs > 0, "invalid glyph count")
        metrics = font["hmtx"].metrics
        require(set(glyph_order) == set(metrics), "incomplete horizontal metrics")
        require(all(advance >= 0 for advance, _ in metrics.values()), "negative advance")

        require(names(font, 1) == {family}, f"unexpected family: {names(font, 1)}")
        style_names = names(font, 2)
        require(len(style_names) == 1, f"ambiguous style: {style_names}")
        style = next(iter(style_names))
        require(style in STYLES, f"unexpected style: {style}")
        for name_id, expected in ((16, family), (17, style)):
            require(
                not names(font, name_id) or names(font, name_id) == {expected},
                f"inconsistent typographic name {name_id}: {names(font, name_id)}",
            )
        full_names = {f"{family} {style}"}
        postscript_names = {f"{family.replace(' ', '')}-{style.replace(' ', '')}"}
        if style == "Regular":
            full_names.add(family)
            postscript_names.add(family.replace(" ", ""))
        require(
            len(names(font, 4)) == 1 and names(font, 4) <= full_names,
            f"unexpected full name: {names(font, 4)}",
        )
        require(
            len(names(font, 6)) == 1 and names(font, 6) <= postscript_names,
            f"unexpected PostScript name: {names(font, 6)}",
        )

        weight, bold, italic = STYLES[style]
        require(font["OS/2"].usWeightClass == weight, f"incorrect weight for {style}")
        require(bool(font["OS/2"].fsSelection & 0x20) == bold, "incorrect OS/2 bold flag")
        require(bool(font["OS/2"].fsSelection & 0x01) == italic, "incorrect OS/2 italic flag")
        require(bool(font["head"].macStyle & 0x01) == bold, "incorrect head bold flag")
        require(bool(font["head"].macStyle & 0x02) == italic, "incorrect head italic flag")
        require(
            font["post"].italicAngle < 0 if italic else font["post"].italicAngle == 0,
            "incorrect italic angle",
        )

        cmap = font.getBestCmap()
        require(cmap is not None, "missing Unicode cmap")
        for table in font["cmap"].tables:
            if table.isUnicode() and hasattr(table, "cmap"):
                require(
                    set(table.cmap.values()) <= set(glyph_order),
                    "cmap references absent glyphs",
                )
        glyphs = font.getGlyphSet()
        text = dict.fromkeys(range(0x20, 0x7F), "ASCII")
        text.update(dict.fromkeys(map(ord, "─│┌┐└┘┼"), "box drawing"))
        for codepoint, label in (text | NERD_GLYPHS).items():
            glyph_name = cmap.get(codepoint)
            require(
                glyph_name is not None and glyph_name != glyph_order[0],
                f"missing U+{codepoint:04X} ({label})",
            )
            require(metrics[glyph_name][0] > 0, f"zero advance for U+{codepoint:04X}")
            if codepoint != 0x20:
                pen = BoundsPen(glyphs)
                glyphs[glyph_name].draw(pen)
                require(
                    pen.bounds is not None,
                    f"empty outline for U+{codepoint:04X} ({label})",
                )

        if monospaced:
            # NF, unlike NFM, may give icons wider advances; fixed pitch applies to text.
            advances = {metrics[cmap[codepoint]][0] for codepoint in text}
            require(len(advances) == 1, f"non-monospaced text advances: {sorted(advances)}")
            for codepoint in (0x0301, 0x0308):
                require(
                    codepoint in cmap and metrics[cmap[codepoint]][0] == 0,
                    f"combining mark U+{codepoint:04X} must have zero advance",
                )
        return style


def check_variant(variant):
    root = Path(variant["path"])
    paths = sorted(path for path in root.rglob("*") if path.suffix.lower() in {".ttf", ".otf"})
    require(
        len(paths) == len(STYLES),
        f"{variant['package']}: expected four faces, found {len(paths)} in {root}",
    )
    found = set()
    for path in paths:
        try:
            style = check_font(path, variant["family"], variant["monospaced"])
            require(style not in found, f"duplicate style: {style}")
            found.add(style)
        except Exception as error:
            raise ValueError(f"{variant['package']}: {path.name}: {error}") from error
    require(
        found == set(STYLES),
        f"{variant['package']}: missing styles: {set(STYLES) - found}",
    )
    print(f"{variant['package']}: four readable, named, Nerd Font-patched faces")


def main():
    if len(sys.argv) != 2:
        raise SystemExit(f"usage: {sys.argv[0]} MANIFEST.json")
    with open(sys.argv[1], encoding="utf-8") as stream:
        variants = json.load(stream)
    require(bool(variants), "empty font manifest")
    for variant in variants:
        check_variant(variant)


if __name__ == "__main__":
    main()
