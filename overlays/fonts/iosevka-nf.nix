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
    iosevka-custom = iosevka.override {
        inherit set;
        privateBuildPlan = ''
            [buildPlans.${plan}]
            family = "${family}"
            spacing = "${spacing}"
            serifs = "${serifs}"
            noCvSs = true
            exportGlyphNames = true

              [buildPlans.${plan}.variants]
                inherits = "ss04"

              [buildPlans.${plan}.weights.Regular]
                shape = 400
                menu = 400
                css = 400

              [buildPlans.${plan}.weights.Bold]
                shape = 700
                menu = 700
                css = 700

              [buildPlans.${plan}.slopes.Upright]
                angle = 0
                shape = "upright"
                menu = "upright"
                css = "normal"

              [buildPlans.${plan}.slopes.Italic]
                angle = 9.4
                shape = "italic"
                menu = "italic"
                css = "italic"

              [buildPlans.${plan}.widths.Normal]
                shape = 500
                menu = 5
                css = "normal"
        '';
    };

in
stdenvNoCC.mkDerivation {
    inherit pname;
    version = "${iosevka-custom.version}-nf-${nerd-font-patcher.version}";

    src = iosevka-custom;

    nativeBuildInputs = [ nerd-font-patcher ];

    dontUnpack = true;
    dontConfigure = true;

    buildPhase = ''
        runHook preBuild

        export HOME=$(mktemp -d)
        export TMPDIR=$(mktemp -d)

        mkdir -p srcfonts patched

        # Copy to writable directory — nerd-font-patcher needs write access
        find $src/share/fonts -name '*.ttf' -o -name '*.otf' | while read -r f; do
          cp --no-preserve=mode,ownership "$f" srcfonts/
        done

        for f in srcfonts/*; do
          basename="$(basename "$f" | sed 's/\.\(ttf\|otf\)$//')"
          nf_name="$(echo "$basename" | sed 's/^${plan}/${patchedName}/')"

          echo "Patching: $f -> $nf_name"
          nerd-font-patcher "$f" \
            --complete \
            --no-progressbars \
            --name "$nf_name" \
            --outputdir patched
        done

        runHook postBuild
    '';

    installPhase = ''
        runHook preInstall

        mkdir -p $out/share/fonts/truetype
        install -Dm 444 patched/* $out/share/fonts/truetype/

        runHook postInstall
    '';

    meta = {
        inherit description;
        homepage = "https://typeof.net/Iosevka/";
        license = lib.licenses.ofl;
        platforms = lib.platforms.all;
    };
}
