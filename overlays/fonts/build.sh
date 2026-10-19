#!/bin/sh
: "${src:?}" "${plan:?}" "${patchedName:?}"
runHook preBuild

HOME=$(mktemp -d)
TMPDIR=$(mktemp -d)
export HOME TMPDIR

mkdir -p srcfonts patched
find "$src/share/fonts" \( -name '*.ttf' -o -name '*.otf' \) -exec cp --no-preserve=mode,ownership {} srcfonts/ \;

for font in srcfonts/*; do
    basename=${font##*/}
    basename=${basename%.*}
    case $basename in
        "$plan"*) nf_name=$patchedName${basename#"$plan"} ;;
        *) nf_name=$basename ;;
    esac
    nerd-font-patcher "$font" \
        --quiet \
        --complete \
        --no-progressbars \
        --name "$nf_name" \
        --outputdir patched
done

runHook postBuild
