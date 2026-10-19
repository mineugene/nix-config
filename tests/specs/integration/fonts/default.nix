{
    pkgs,
    iosevka-ss04,
}:
let
    manifest = pkgs.writeText "fonts-manifest.json" (
        builtins.toJSON {
            variants = [
                {
                    package = "iosevka-ss04";
                    path = "${iosevka-ss04}/share/fonts/truetype";
                    families = [
                        "Iosevka"
                        "Iosevka Term"
                        "Iosevka Fixed"
                    ];
                }
                {
                    package = "inter";
                    path = "${pkgs.inter}/share/fonts";
                    families = [ "Inter" ];
                }
                {
                    package = "source-serif";
                    path = "${pkgs.source-serif}/share/fonts";
                    families = [ "Source Serif 4" ];
                }
            ];
            fallback = {
                package = "nerd-fonts.symbols-only";
                path = "${pkgs.nerd-fonts.symbols-only}/share/fonts/truetype/NerdFonts/Symbols/SymbolsNerdFontMono-Regular.ttf";
                codepoints = [
                    57520 # U+E0B0
                    58874 # U+E5FA
                    58901 # U+E615
                    59136 # U+E700
                    60000 # U+EA60
                    61527 # U+F057
                    61528 # U+F058
                    61563 # U+F07B
                    61728 # U+F120
                    61820 # U+F17C
                    62514 # U+F432
                    983041 # U+F0001
                ];
            };
        }
    );
in
pkgs.runCommandLocal "fonts-check" {
    nativeBuildInputs = [ (pkgs.python3.withPackages (ps: [ ps.fonttools ])) ];
    fontManifest = manifest;
    fontTest = ./fonts.py;
} (builtins.readFile ./fonts-check.sh)
