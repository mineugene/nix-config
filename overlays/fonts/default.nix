final: _prev:
let
    mkIosevka = final.callPackage ./iosevka-nf.nix;
in
{
    iosevka-nf = mkIosevka {
        set = "Mono";
        family = "Iosevka";
        spacing = "fontconfig-mono";
        pname = "iosevka-nf";
        description = "Iosevka NF — Menlo style (SS04), fontconfig-mono spacing, with Nerd Fonts";
    };
    iosevka-term-nf = mkIosevka {
        set = "Term";
        family = "IosevkaTerm";
        spacing = "term";
        pname = "iosevka-term-nf";
        description = "IosevkaTerm NF — Menlo style (SS04), terminal spacing, with Nerd Fonts";
    };
    iosevka-aile-nf = mkIosevka {
        set = "Aile";
        family = "IosevkaAile";
        spacing = "proportional";
        pname = "iosevka-aile-nf";
        description = "IosevkaAile NF — Menlo style (SS04), proportional sans, with Nerd Fonts";
    };
    iosevka-etoile-nf = mkIosevka {
        set = "Etoile";
        family = "IosevkaEtoile";
        spacing = "proportional";
        serifs = "slab";
        pname = "iosevka-etoile-nf";
        description = "IosevkaEtoile NF — Menlo style (SS04), proportional serif, with Nerd Fonts";
    };
}
