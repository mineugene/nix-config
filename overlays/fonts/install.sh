#!/bin/sh
: "${out:?}"
runHook preInstall

mkdir -p "$out/share/fonts/truetype"
install -Dm 444 patched/* "$out/share/fonts/truetype/"

runHook postInstall
