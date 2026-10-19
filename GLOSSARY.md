# Fonts and desktop typography

This flake exports the Iosevka families the desktop modules install, and the icon fallback that supplies glyphs those families lack.

## Language

**Interface font**:
The proportional sans family used for application UI and fontconfig `sansSerif`. Defaults to Inter.
_Avoid_: UI font, sans font

**Serif font**:
The proportional serif family used for serif text. Defaults to Source Serif 4.
_Avoid_: —

**Terminal font**:
The fixed-width family used by the terminal and monospace UI. Defaults to Iosevka Term.
_Avoid_: console font, mono font

**Normal Iosevka**:
The non-terminal Iosevka family, kept for monospace uses outside the terminal.
_Avoid_: mono variant, base variant

**Nerd fallback**:
Symbols Nerd Font Mono, installed only to supply icon codepoints the primary families lack.
_Avoid_: nerd font patching, patched font
