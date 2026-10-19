{
    stdenvNoCC,
    iosevka-bin,
    python3,
}:
let
    src = iosevka-bin.override { variant = "SS04"; };
in
stdenvNoCC.mkDerivation {
    pname = "iosevka-ss04";
    inherit (src) version;

    inherit src;

    nativeBuildInputs = [ (python3.withPackages (ps: [ ps.fonttools ])) ];

    dontUnpack = true;
    dontConfigure = true;

    renameFamilies = ./rename-families.py;
    installPhase = builtins.readFile ./install.sh;

    meta = src.meta;
}
