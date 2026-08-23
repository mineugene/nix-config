{
    lib,
    stdenvNoCC,
    iosevka,
    nerd-font-patcher,
    set,
    family,
    spacing,
    serifs ? "sans",
    pname,
    description,
}:

let
    plan = "Iosevka${set}";
    patchedName = if set == "Mono" then "IosevkaNF" else "${plan}NF";
    iosevka-custom =
        (iosevka.override {
            inherit set;
            privateBuildPlan = {
                inherit family spacing serifs;
                noCvSs = true;
                exportGlyphNames = true;
                variants.inherits = "ss04";
                weights = {
                    Regular = {
                        shape = 400;
                        menu = 400;
                        css = 400;
                    };
                    Bold = {
                        shape = 700;
                        menu = 700;
                        css = 700;
                    };
                };
                slopes = {
                    Upright = {
                        angle = 0;
                        shape = "upright";
                        menu = "upright";
                        css = "normal";
                    };
                    Italic = {
                        angle = 9.4;
                        shape = "italic";
                        menu = "italic";
                        css = "italic";
                    };
                };
                widths.Normal = {
                    shape = 500;
                    menu = 5;
                    css = "normal";
                };
            };
        }).overrideAttrs
            (old: {
                npm_config_loglevel = "warn";
                # Verda level 4 retains warnings and failures without task chatter.
                buildPhase = lib.replaceStrings [ "--verbosity=9" ] [ "--verbosity=4" ] old.buildPhase;
            });
    quiet-patcher = nerd-font-patcher.overrideAttrs (old: {
        # --quiet disables progress output, but not INFO logs or banners.
        postPatch = (old.postPatch or "") + "\n" + builtins.readFile ./quiet-patcher.sh;
    });

in
stdenvNoCC.mkDerivation {
    inherit pname;
    version = "${iosevka-custom.version}-nf-${nerd-font-patcher.version}";

    src = iosevka-custom;

    nativeBuildInputs = [ quiet-patcher ];

    dontUnpack = true;
    dontConfigure = true;

    inherit plan patchedName;
    buildPhase = builtins.readFile ./build.sh;
    installPhase = builtins.readFile ./install.sh;

    meta = {
        inherit description;
        homepage = "https://typeof.net/Iosevka/";
        license = lib.licenses.ofl;
        platforms = lib.platforms.all;
    };
}
