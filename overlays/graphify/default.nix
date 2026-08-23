final: prev: {
    graphify = prev.graphify.overrideAttrs (old: {
        nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ final.makeWrapper ];

        postPatch = (old.postPatch or "") + ''
            substituteInPlace graphify/hooks.py \
                --replace-fail 'return sys.executable' 'return str(Path(__file__).parents[4] / "bin" / "graphify-python")'
        '';

        postFixup = (old.postFixup or "") + ''
            makeWrapper ${final.python3}/bin/python3 $out/bin/graphify-python \
                --set PYTHONNOUSERSITE true \
                --prefix PYTHONPATH : "$out/${final.python3.sitePackages}:${
                    final.python3Packages.makePythonPath (old.dependencies or [ ])
                }"
        '';
    });
}
