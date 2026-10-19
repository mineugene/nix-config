#!/bin/sh
: "${src:?}" "${renameFamilies:?}" "${out:?}"
runHook preInstall

mkdir -p "$out/share/fonts/truetype"
for font in "$src"/share/fonts/truetype/*.ttc; do
    base=${font##*/}
    case $base in
        IosevkaSS04-*) name=Iosevka-${base#IosevkaSS04-} ;;
        *) name=$base ;;
    esac
    python3 "$renameFamilies" "$font" "$out/share/fonts/truetype/$name"
done

runHook postInstall