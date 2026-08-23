{
    pkgs,
    fonts ? pkgs,
}:
let
    variants = [
        {
            package = "iosevka-nf";
            family = "Iosevka NF";
            monospaced = true;
        }
        {
            package = "iosevka-term-nf";
            family = "Iosevka Term NF";
            monospaced = true;
        }
        {
            package = "iosevka-aile-nf";
            family = "Iosevka Aile NF";
            monospaced = false;
        }
        {
            package = "iosevka-etoile-nf";
            family = "Iosevka Etoile NF";
            monospaced = false;
        }
    ];
    manifest = pkgs.writeText "font-check-manifest.json" (
        builtins.toJSON (
            map (variant: variant // { path = "${fonts.${variant.package}}/share/fonts"; }) variants
        )
    );
in
pkgs.runCommandLocal "fonts-check" {
    nativeBuildInputs = [ (pkgs.python3.withPackages (ps: [ ps.fonttools ])) ];
    fontManifest = manifest;
    fontTest = ./fonts.py;
} (builtins.readFile ./fonts-check.sh)
